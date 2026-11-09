import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart'
    show QueryExecutor, QueryInterceptor, ApplyInterceptor;
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/ble_protocol.dart';
import 'package:sos_app/features/nearby_ble/data/ble_transport.dart';
import 'package:sos_app/features/nearby_ble/data/relay_key_store.dart';
import 'package:sos_app/features/nearby_ble/data/relay_repository.dart';
import 'package:sos_app/features/nearby_ble/data/rescue_inbox_repository.dart';
import 'package:sos_app/features/nearby_ble/data/rescue_response_repository.dart';
import 'package:sos_app/features/nearby_ble/data/sos_ble_coordinator.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';
import 'package:sos_app/features/nearby_ble/domain/relay_envelope.dart';
import 'package:sos_app/features/nearby_ble/domain/rescue_response_envelope.dart';
import 'package:sos_app/features/sos/data/chat_repository.dart';
import 'package:sos_app/features/sos/data/media_attachment_store.dart';

class SimulationClock {
  DateTime now = DateTime.utc(2026, 11, 6, 12);
  final timers = <SimulationTimer>[];
  Timer timer(Duration delay, void Function() callback) {
    final timer = SimulationTimer(now.add(delay), callback);
    timers.add(timer);
    return timer;
  }

  Timer periodic(Duration interval, void Function(Timer) callback) {
    if (interval <= Duration.zero) throw ArgumentError.value(interval);
    late SimulationTimer timer;
    timer = SimulationTimer(now.add(interval), () => callback(timer), interval);
    timers.add(timer);
    return timer;
  }

  void advance(Duration elapsed) {
    if (elapsed.isNegative) throw ArgumentError.value(elapsed);
    final target = now.add(elapsed);
    while (true) {
      final due =
          timers.where((t) => t.isActive && !t.due.isAfter(target)).toList()
            ..sort((a, b) => a.due.compareTo(b.due));
      if (due.isEmpty) break;
      now = due.first.due;
      due.first.fire();
      timers.removeWhere((t) => !t.isActive);
    }
    now = target;
  }
}

class SimulationTimer implements Timer {
  SimulationTimer(this.due, this.callback, [this.interval]);
  final Duration? interval;
  DateTime due;
  final void Function() callback;
  bool _active = true;
  @override
  bool get isActive => _active;
  @override
  int tick = 0;
  @override
  void cancel() => _active = false;
  void fire() {
    if (!_active) return;
    if (interval == null) {
      _active = false;
    } else {
      due = due.add(interval!);
    }
    tick++;
    callback();
  }
}

class SimulationKeys implements RelayPrivateKeyStore {
  SimulationKeys(this.seed);
  final int seed;
  @override
  Future<List<int>?> readSeed() async => List.filled(32, seed);
  @override
  Future<void> writeSeed(List<int> value) async {}
}

class SimPacket {
  SimPacket(
    this.from,
    this.to,
    this.role,
    this.frame,
    this.generation,
    this.due,
  );
  final String from, to;
  final BleSessionRole role;
  final List<int> frame;
  final int generation;
  final DateTime due;
}

/// Only the external BLE boundary is simulated. Frames and all coordinator,
/// cryptographic, authorization and persistence work remain production code.
class SimBleNetwork {
  SimBleNetwork(this.clock);
  final SimulationClock clock;
  final transports = <String, SimBleTransport>{};
  final allowedLinks = <String>{};
  final connections = <String, (String, int)>{}; // central, generation
  final packets = <SimPacket>[];
  final captures = <(String, String, BleMessage)>[];
  final assemblers = <String, BleMessageAssembler>{};
  final dropTypes = <String>{};
  bool Function(String from, String to, BleMessage message)? dropMessage;
  final held = <SimPacket>[];
  bool holdPackets = false, reversePackets = false, duplicatePackets = false;
  bool dropNextFrame = false, failNextWrite = false;
  String? failMessageTypeOnce;
  String? dropLastFrameTypeOnce;
  void Function(String from, String to)? afterFrameWrite;
  Duration latency = Duration.zero;
  int frameWrites = 0, deliveredFrames = 0, staleFramesDropped = 0;
  int nonceCounter = 0;
  String pair(String a, String b) => ([a, b]..sort()).join('|');
  void allow(String a, String b) => allowedLinks.add(pair(a, b));
  bool linked(String a, String b) => connections.containsKey(pair(a, b));

  void connect(String central, String peripheral) {
    final key = pair(central, peripheral);
    if (!allowedLinks.contains(key)) {
      throw const BleTransportException('No virtual radio link.');
    }
    if (connections.containsKey(key)) return;
    final generation = ++_generation;
    connections[key] = (central, generation);
    transports[central]!.emit(
      BleEvent(
        type: 'connected',
        device: BleDevice(id: peripheral),
        role: BleSessionRole.central,
        attempt: generation,
      ),
    );
    transports[peripheral]!.emit(
      BleEvent(
        type: 'connected',
        device: BleDevice(id: central),
        role: BleSessionRole.peripheral,
        attempt: generation,
      ),
    );
  }

  int _generation = 0;
  void disconnect(String a, String b) {
    final link = connections.remove(pair(a, b));
    if (link == null) return;
    final other = link.$1 == a ? b : a;
    transports[link.$1]!.emit(
      BleEvent(
        type: 'disconnected',
        device: BleDevice(id: other),
        role: BleSessionRole.central,
        attempt: link.$2,
      ),
    );
    transports[other]!.emit(
      BleEvent(
        type: 'disconnected',
        device: BleDevice(id: link.$1),
        role: BleSessionRole.peripheral,
        attempt: link.$2,
      ),
    );
  }

  void write(String from, String to, List<int> bytes, BleSessionRole role) {
    final link = connections[pair(from, to)];
    if (link == null || failNextWrite) {
      failNextWrite = false;
      throw const BleTransportException('Virtual connection interrupted.');
    }
    if ((link.$1 == from) != (role == BleSessionRole.central)) {
      throw const BleTransportException('Wrong virtual GATT role.');
    }
    frameWrites++;
    afterFrameWrite?.call(from, to);
    if (!linked(from, to)) {
      throw const BleTransportException('Disconnected during frame write.');
    }
    final copy = List<int>.from(bytes);
    final message = assemblers
        .putIfAbsent(
          '$from|$to|${link.$2}',
          () => BleMessageAssembler(dropDuplicateMessages: false),
        )
        .accept(copy, now: clock.now);
    if (message != null) {
      captures.add((from, to, message));
      if (message.type == failMessageTypeOnce) {
        failMessageTypeOnce = null;
        throw const BleTransportException(
          'Injected native completion failure.',
        );
      }
      if (message.type == dropLastFrameTypeOnce) {
        dropLastFrameTypeOnce = null;
        return;
      }
      // Capture full real frames before optional message-level loss. Do not
      // decode/re-encode on the normal delivery path.
      if (dropTypes.contains(message.type) ||
          (dropMessage?.call(from, to, message) ?? false)) {
        final token = copy.sublist(2, 10).join(',');
        packets.removeWhere(
          (p) =>
              p.from == from &&
              p.to == to &&
              p.frame.sublist(2, 10).join(',') == token,
        );
        return;
      }
    }
    if (dropNextFrame) {
      dropNextFrame = false;
      return;
    }
    final packet = SimPacket(
      from,
      to,
      role == BleSessionRole.central
          ? BleSessionRole.peripheral
          : BleSessionRole.central,
      copy,
      link.$2,
      clock.now.add(latency),
    );
    (holdPackets ? held : packets).add(packet);
    if (duplicatePackets) (holdPackets ? held : packets).add(packet);
  }

  void releaseHeld() {
    packets.addAll(held);
    held.clear();
  }

  void inject(String from, String to, BleMessage message) {
    final link = connections[pair(from, to)];
    if (link == null) throw StateError('No live link for injection.');
    final role = link.$1 == from
        ? BleSessionRole.peripheral
        : BleSessionRole.central;
    for (final frame in BleMessageCodec.encode(message)) {
      packets.add(SimPacket(from, to, role, frame, link.$2, clock.now));
    }
  }

  Future<int> deliver() async {
    final ready = packets.where((p) => !p.due.isAfter(clock.now)).toList();
    packets.removeWhere(ready.contains);
    if (reversePackets) {
      ready.setAll(0, ready.reversed.toList());
    }
    for (final p in ready) {
      if (connections[pair(p.from, p.to)]?.$2 != p.generation) {
        staleFramesDropped++;
        continue;
      }
      deliveredFrames++;
      transports[p.to]!.emit(
        BleEvent(
          type: 'data',
          device: BleDevice(id: p.from),
          role: p.role,
          payload: p.frame,
        ),
      );
    }
    // Explicit event-loop barrier, not a real-time delay. Allows production
    // async database/crypto completions to enqueue their next frames.
    await Future<void>(() {});
    return ready.length;
  }

  Future<void> pump({int rounds = 300}) async {
    for (var i = 0; i < rounds; i++) {
      await deliver();
    }
  }

  Future<void> until(
    Future<bool> Function() condition, {
    int rounds = 5000,
  }) async {
    for (var i = 0; i < rounds; i++) {
      await deliver();
      if (await condition()) return;
    }
    throw StateError('Virtual network did not converge within $rounds steps.');
  }

  Future<String> binding(String sender, String receiver) async {
    final message = captures
        .lastWhere(
          (p) =>
              p.$1 == receiver &&
              p.$2 == sender &&
              p.$3.type == RelaySessionResponse.wireKind,
        )
        .$3;
    final response = RelaySessionResponse.fromJson(message.payload);
    return RelayCryptography().relaySessionBinding(
      response.challenge,
      response,
    );
  }
}

class SimBleTransport implements BleTransportClient {
  SimBleTransport(this.id, this.network) {
    network.transports[id] = this;
  }
  final String id;
  final SimBleNetwork network;
  final controller = StreamController<BleEvent>.broadcast();
  bool advertising = false, discovering = false;
  int connectionCalls = 0, discoveryStarts = 0, discoveryStops = 0;
  void emit(BleEvent e) {
    if (!controller.isClosed) controller.add(e);
  }

  @override
  Stream<BleEvent> get events => controller.stream;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> requestPermissions() async {}
  @override
  Future<void> startAdvertising({String? name}) async {
    advertising = true;
  }

  @override
  Future<void> stopAdvertising() async {
    advertising = false;
  }

  @override
  Future<void> startDiscovery() async {
    discoveryStarts++;
    discovering = true;
  }

  @override
  Future<void> stopDiscovery() async {
    discoveryStops++;
    discovering = false;
  }

  void discover(String peer) => emit(
    BleEvent(
      type: 'deviceFound',
      device: BleDevice(id: peer),
    ),
  );
  @override
  Future<void> connect(String deviceId) async {
    connectionCalls++;
    network.connect(id, deviceId);
  }

  @override
  Future<void> disconnect(String deviceId) async =>
      network.disconnect(id, deviceId);
  @override
  Future<void> send(
    String deviceId,
    List<int> frame, {
    BleSessionRole? role,
  }) async =>
      network.write(id, deviceId, frame, role ?? BleSessionRole.central);
  @override
  Future<void> dispose() async {
    await controller.close();
  }
}

/// Observes actual SQL calls; it never substitutes results or logs payloads.
class SimulationSqlCounters extends QueryInterceptor {
  int selects = 0, inserts = 0, updates = 0, deletes = 0;
  Map<String, int> get snapshot => {
    'selects': selects,
    'inserts': inserts,
    'updates': updates,
    'deletes': deletes,
  };
  void reset() {
    selects = inserts = updates = deletes = 0;
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    selects++;
    return executor.runSelect(statement, args);
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    inserts++;
    return executor.runInsert(statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    updates++;
    return executor.runUpdate(statement, args);
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    deletes++;
    return executor.runDelete(statement, args);
  }
}

class SimNode {
  SimNode(
    this.id,
    this.seed,
    this.network, {
    File? file,
    Directory? mediaRoot,
  }) {
    db = AppDatabase.forTesting(
      (file == null ? NativeDatabase.memory() : NativeDatabase(file))
          .interceptWith(sql),
    );
    identityService = RelayIdentityService(keyStore: SimulationKeys(seed));
    transport = SimBleTransport(id, network);
    final attachments = MediaAttachmentStore(ownerId: id, root: mediaRoot);
    chat = PersistentChatRepository(
      database: db,
      ownerId: id,
      attachmentStore: attachments,
      now: () => network.clock.now,
    );
    coordinator = SosBleCoordinator(
      database: db,
      ownerId: id,
      localDeviceId: id,
      transport: transport,
      relayIdentityService: identityService,
      relayProofTimer: network.clock.timer,
      periodicTimer: network.clock.periodic,
      relayNonceSource: () {
        final counter = ++network.nonceCounter;
        return List.generate(32, (i) => (counter >> ((i % 4) * 8)) & 255);
      },
      random: () => 0.5,
      chatRepository: chat,
      attachmentStore: mediaRoot == null ? null : attachments,
      now: () => network.clock.now,
      pollInterval: const Duration(days: 1),
      onLog: logs.add,
    );
  }
  final String id;
  final int seed;
  final sql = SimulationSqlCounters();
  final SimBleNetwork network;
  late final AppDatabase db;
  late final RelayIdentityService identityService;
  late final SimBleTransport transport;
  late final PersistentChatRepository chat;
  late final SosBleCoordinator coordinator;
  final logs = <String>[];
  Future<RelaySigningIdentity> identity() =>
      identityService.loadOrCreate(allowCreate: true);
  Future<void> start() async {
    coordinator.setRescueModeEnabled(id == 'C');
    await coordinator.start();
    await coordinator.setRelayParticipationEnabled(true);
  }

  Future<bool> authenticated() async =>
      (await coordinator.relayRuntimeDiagnosticsDataSource
              .watchRuntimeDiagnostics()
              .first)
          .peers
          .any((p) => p.authenticated);
  Future<void> materialize(String incident) async {
    final rows = await (db.select(
      db.sosMessages,
    )..where((r) => r.id.equals(incident))).get();
    if (rows.isEmpty) {
      await db
          .into(db.sosMessages)
          .insert(
            SosMessagesCompanion.insert(
              id: incident,
              ownerId: id,
              type: 'emergency',
              status: 'active',
              syncState: 'deviceOnly',
              createdAt: network.clock.now,
              updatedAt: network.clock.now,
            ),
          );
    }
  }

  Future<void> send(String messageId, String text, SimNode recipient) async {
    await materialize('incident-1');
    final message = await chat.insertMessage(
      sosId: 'incident-1',
      text: text,
      messageId: messageId,
    );
    final key = await recipient.identity();
    await coordinator.enqueueChatThroughRelay(
      chat: EmergencyChatMessage(
        id: message.id,
        sosId: message.sosId,
        senderId: message.senderId,
        text: message.text,
        createdAt: network.clock.now,
        status: message.status,
      ),
      recipientKeyId: key.keyId,
      recipientPublicKey: base64UrlEncode(key.publicKey),
    );
  }

  Future<void> close() async {
    await coordinator.dispose();
    await transport.dispose();
    await db.close();
  }
}

class ThreeNodeSimulation {
  ThreeNodeSimulation({File? relayFile, Directory? mediaRoot}) {
    network = SimBleNetwork(clock)
      ..allow('A', 'B')
      ..allow('B', 'C');
    a = SimNode('A', 1, network, mediaRoot: mediaRoot);
    b = SimNode('B', 2, network, file: relayFile, mediaRoot: mediaRoot);
    c = SimNode('C', 3, network, mediaRoot: mediaRoot);
  }
  final clock = SimulationClock();
  late final SimBleNetwork network;
  late final SimNode a, c;
  late SimNode b;
  late RelayOfferEnvelope sos;
  late RescueResponseEnvelope offer;
  Future<void> start() async {
    for (final n in [a, b, c]) {
      await n.start();
    }
    network.connect('A', 'B');
    network.connect('C', 'B');
    await network.until(
      () async =>
          await a.authenticated() &&
          await c.authenticated() &&
          (await b.coordinator.relayRuntimeDiagnosticsDataSource
                      .watchRuntimeDiagnostics()
                      .first)
                  .peers
                  .where((p) => p.authenticated)
                  .length ==
              2,
    );
  }

  Future<void> prepareIncident() async {
    final key = await a.identity();
    final t = clock.now;
    final body = RelayOriginBody(
      originMessageId: 'relay:incident-1',
      incidentId: 'incident-1',
      originKeyId: key.keyId,
      originPublicKey: base64UrlEncode(key.publicKey),
      emergencyType: 'emergency',
      emergencyMessage: 'test',
      includeLocation: true,
      latitude: 13.7,
      longitude: 100.5,
      createdAt: t,
      expiresAt: t.add(const Duration(minutes: 30)),
      scope: RelayAuthorizationScope.voluntaryRescue,
    );
    sos = RelayOfferEnvelope(
      body: body,
      originSignature: await RelayCryptography().signOriginBody(
        body,
        key.keyPair,
      ),
      hopCount: 0,
      pathKeyIds: [key.keyId],
      immediateSenderKeyId: key.keyId,
    );
    // Seed only the known verified SOS boundary. Production SOS relay itself
    // is exercised separately; Stage 2 tests focus on Chat after SOS reception.
    for (final n in [a, b, c]) {
      if (n == a) {
        await RelayRepository(database: n.db).persistOriginOffer(sos, now: t);
      } else {
        await RelayRepository(database: n.db).acceptIncomingOffer(
          sos,
          sourceDeviceId: 'verified-origin-fixture',
          relayEnabled: true,
          now: t,
        );
      }
      if (n == c) {
        await RescueInboxRepository(n.db, ownerId: n.id).insertCandidate(
          sos,
          immutableDigest: await RelayCryptography().immutableDigest(body),
          now: t,
        );
      }
      await n.materialize('incident-1');
    }
    final responder = await c.identity();
    final responseBody = RescueResponseBody(
      messageId: 'verified-help',
      incidentId: body.incidentId,
      originMessageId: body.originMessageId,
      originKeyId: body.originKeyId,
      originDigest: await RelayCryptography().immutableDigest(body),
      responderKeyId: responder.keyId,
      responderPublicKey: base64UrlEncode(responder.publicKey),
      sessionBinding: 'fixture-explicit-offer',
      createdAt: t,
      expiresAt: t.add(const Duration(minutes: 15)),
    );
    offer = RescueResponseEnvelope(
      body: responseBody,
      signature: await RelayCryptography().signRescueResponse(
        responseBody,
        responder.keyPair,
      ),
    );
    // Explicitly provision the already-verified help-offer boundary. Real
    // signature/origin checks execute; no authenticated state is fabricated.
    for (final n in [a, b, c]) {
      await RescueResponseRepository(
        n.db,
        ownerId: n.id,
      ).recordIncoming(envelope: offer, origin: body, now: t);
    }
  }

  Future<void> close() async {
    for (final n in [a, b, c]) {
      await n.close();
    }
  }
}
