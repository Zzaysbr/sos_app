import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/sos/data/offline_map_repository.dart';
import 'package:sos_app/features/sos/presentation/offline_first_tile_provider.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('offline-map-test-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  const bounds = OfflineMapBounds(
    north: 13.701,
    south: 13.699,
    east: 100.501,
    west: 100.499,
  );

  OfflineMapDownloadRequest request({
    String name = 'Test area',
  }) => OfflineMapDownloadRequest(
    name: name,
    providerKey: 'provider-test',
    urlTemplate:
        'https://maps.geoapify.com/v1/tile/test/{z}/{x}/{y}.png?apiKey=test',
    userAgent: 'com.n1cxltine.sosapp',
    bounds: bounds,
    minZoom: 14,
    maxZoom: 14,
  );

  test('completed region and tiles survive repository restart', () async {
    final repository = OfflineMapRepository(
      rootDirectory: root,
      requestDelay: Duration.zero,
      fetcher: (uri, headers, timeout) async => Uint8List.fromList([1, 2, 3]),
    );
    await repository.initialize();
    final region = await repository.downloadRegion(
      request(),
      cancellation: OfflineMapCancellation(),
    );

    expect(region.tileCount, greaterThan(0));
    expect(repository.regions, hasLength(1));
    expect(repository.storageBytes, region.tileCount * 3);

    final restarted = OfflineMapRepository(rootDirectory: root);
    await restarted.initialize();
    expect(restarted.regions.single.toJson(), region.toJson());

    final tileFiles = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.tile'))
        .toList();
    expect(tileFiles, hasLength(region.tileCount));
    final segments = tileFiles.first.path.split(Platform.pathSeparator);
    final y = int.parse(segments.last.split('.').first);
    final x = int.parse(segments[segments.length - 2]);
    final z = int.parse(segments[segments.length - 3]);
    expect(restarted.tileFile('provider-test', z, x, y), isNotNull);
    expect(restarted.tileFile('different-provider', z, x, y), isNull);
  });

  test('offline-first provider selects a completed local tile', () async {
    final repository = OfflineMapRepository(
      rootDirectory: root,
      requestDelay: Duration.zero,
      fetcher: (uri, headers, timeout) async => Uint8List.fromList([1, 2, 3]),
    );
    await repository.initialize();
    final region = await repository.downloadRegion(
      request(),
      cancellation: OfflineMapCancellation(),
    );
    final tileFile = root
        .listSync(recursive: true)
        .whereType<File>()
        .firstWhere((file) => file.path.endsWith('.tile'));
    final segments = tileFile.path.split(Platform.pathSeparator);
    final coordinates = TileCoordinates(
      int.parse(segments[segments.length - 2]),
      int.parse(segments.last.split('.').first),
      int.parse(segments[segments.length - 3]),
    );
    final provider = OfflineFirstTileProvider(
      repositoryProvider: () => repository,
      providerKey: region.providerKey,
    );

    final image = provider.getImageWithCancelLoadingSupport(
      coordinates,
      TileLayer(
        urlTemplate: 'https://maps.geoapify.com/v1/tile/test/{z}/{x}/{y}.png?apiKey=test',
      ),
      Completer<void>().future,
    );

    expect(image, isA<FileImage>());
    await provider.dispose();
  });

  test('rejects a provider without explicit offline permission', () async {
    var fetches = 0;
    final repository = OfflineMapRepository(
      rootDirectory: root,
      requestDelay: Duration.zero,
      fetcher: (uri, headers, timeout) async {
        fetches++;
        return Uint8List.fromList([1]);
      },
    );
    await repository.initialize();

    await expectLater(
      repository.downloadRegion(
        OfflineMapDownloadRequest(
          name: 'Unsafe',
          providerKey: 'public-osm',
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgent: 'com.n1cxltine.sosapp',
          bounds: bounds,
          minZoom: 14,
          maxZoom: 14,
        ),
        cancellation: OfflineMapCancellation(),
      ),
      throwsA(isA<OfflineMapException>()),
    );
    expect(fetches, 0);
  });

  test('cancellation removes staging data and publishes no region', () async {
    final cancellation = OfflineMapCancellation();
    var fetches = 0;
    final repository = OfflineMapRepository(
      rootDirectory: root,
      requestDelay: Duration.zero,
      fetcher: (uri, headers, timeout) async {
        fetches++;
        cancellation.cancel();
        return Uint8List.fromList([1]);
      },
    );
    await repository.initialize();

    await expectLater(
      repository.downloadRegion(request(), cancellation: cancellation),
      throwsA(isA<OfflineMapCancelled>()),
    );
    expect(fetches, 1);
    expect(repository.regions, isEmpty);
    expect(
      root.listSync().whereType<Directory>().where(
        (directory) => directory.path.contains('.partial-'),
      ),
      isEmpty,
    );
  });

  test(
    'provider failure cannot corrupt an existing completed region',
    () async {
      final working = OfflineMapRepository(
        rootDirectory: root,
        requestDelay: Duration.zero,
        fetcher: (uri, headers, timeout) async => Uint8List.fromList([7]),
      );
      await working.initialize();
      final first = await working.downloadRegion(
        request(name: 'Existing'),
        cancellation: OfflineMapCancellation(),
      );

      final failing = OfflineMapRepository(
        rootDirectory: root,
        requestDelay: Duration.zero,
        fetcher: (uri, headers, timeout) =>
            throw const OfflineMapException('synthetic network failure'),
      );
      await failing.initialize();
      await expectLater(
        failing.downloadRegion(
          request(name: 'Interrupted'),
          cancellation: OfflineMapCancellation(),
        ),
        throwsA(isA<OfflineMapException>()),
      );

      final restarted = OfflineMapRepository(rootDirectory: root);
      await restarted.initialize();
      expect(restarted.regions.map((region) => region.id), [first.id]);
      expect(root.listSync().whereType<Directory>(), hasLength(1));
    },
  );

  test('initialization cleans abandoned partial downloads', () async {
    final partial = Directory('${root.path}/.partial-abandoned');
    await partial.create(recursive: true);
    await File('${partial.path}/tile.tmp').writeAsString('incomplete');

    final repository = OfflineMapRepository(rootDirectory: root);
    await repository.initialize();

    expect(await partial.exists(), isFalse);
    expect(repository.regions, isEmpty);
  });

  test('delete removes the persisted region and storage accounting', () async {
    final repository = OfflineMapRepository(
      rootDirectory: root,
      requestDelay: Duration.zero,
      fetcher: (uri, headers, timeout) async => Uint8List.fromList([1, 2]),
    );
    await repository.initialize();
    final region = await repository.downloadRegion(
      request(),
      cancellation: OfflineMapCancellation(),
    );
    expect(repository.storageBytes, greaterThan(0));

    await repository.deleteRegion(region.id);

    expect(repository.regions, isEmpty);
    expect(repository.storageBytes, 0);
    expect(await Directory('${root.path}/${region.id}').exists(), isFalse);
  });

  test('rejects excessive zoom area before making network requests', () async {
    var fetches = 0;
    final repository = OfflineMapRepository(
      rootDirectory: root,
      requestDelay: Duration.zero,
      fetcher: (uri, headers, timeout) async {
        fetches++;
        return Uint8List.fromList([1]);
      },
    );
    await repository.initialize();
    const largeBounds = OfflineMapBounds(
      north: 20,
      south: 5,
      east: 110,
      west: 95,
    );

    expect(
      repository.estimateTileCount(largeBounds, 14, 16),
      greaterThan(OfflineMapRepository.maxTilesPerRegion),
    );
    await expectLater(
      repository.downloadRegion(
        const OfflineMapDownloadRequest(
          name: 'Too large',
          providerKey: 'provider-test',
          urlTemplate: 'https://maps.geoapify.com/v1/tile/test/{z}/{x}/{y}.png?apiKey=test',
          userAgent: 'com.n1cxltine.sosapp',
          bounds: largeBounds,
          minZoom: 14,
          maxZoom: 16,
        ),
        cancellation: OfflineMapCancellation(),
      ),
      throwsA(
        isA<OfflineMapException>().having(
          (error) => error.message,
          'message',
          contains('limit'),
        ),
      ),
    );
    expect(fetches, 0);
  });
}
