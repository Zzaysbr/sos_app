import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../data/route_device_names.dart';
import '../data/user_route_repository.dart';

String routeText(BuildContext context, String en, String th) =>
    Localizations.localeOf(context).languageCode == 'th' ? th : en;
String routeStageText(BuildContext context, UserRouteStage stage) =>
    switch (stage) {
      UserRouteStage.saved => routeText(
        context,
        'Saved on this device',
        'บันทึกไว้บนเครื่องนี้',
      ),
      UserRouteStage.queued => routeText(context, 'Waiting to send', 'รอส่ง'),
      UserRouteStage.sending => routeText(
        context,
        'Sending · waiting for confirmation',
        'กำลังส่ง · รอการยืนยัน',
      ),
      UserRouteStage.relayed => routeText(
        context,
        'Forwarded · destination not confirmed',
        'ส่งต่อแล้ว · ปลายทางยังไม่ยืนยัน',
      ),
      UserRouteStage.received => routeText(
        context,
        'Received on this device',
        'เครื่องนี้รับไว้แล้ว',
      ),
      UserRouteStage.confirmed => routeText(
        context,
        'Destination saved the message',
        'ปลายทางเก็บข้อความแล้ว',
      ),
      UserRouteStage.failed => routeText(
        context,
        'Send failed',
        'ส่งไม่สำเร็จ',
      ),
      UserRouteStage.expired => routeText(
        context,
        'Delivery window ended',
        'หมดเวลาส่งต่อ',
      ),
      UserRouteStage.cancelled => routeText(
        context,
        'SOS cancelled',
        'ยกเลิก SOS แล้ว',
      ),
      UserRouteStage.resolved => routeText(
        context,
        'Incident resolved',
        'เหตุสิ้นสุดแล้ว',
      ),
    };
IconData routeStageIcon(UserRouteStage stage) => switch (stage) {
  UserRouteStage.saved => Icons.save_outlined,
  UserRouteStage.queued => Icons.schedule_rounded,
  UserRouteStage.sending => Icons.bluetooth_searching_rounded,
  UserRouteStage.relayed => Icons.forward_to_inbox_outlined,
  UserRouteStage.received => Icons.move_to_inbox_outlined,
  UserRouteStage.confirmed => Icons.check_circle_outline_rounded,
  UserRouteStage.failed => Icons.error_outline_rounded,
  UserRouteStage.expired => Icons.timer_off_outlined,
  UserRouteStage.cancelled || UserRouteStage.resolved => Icons.task_alt_rounded,
};

/// Compact route entry opens a scrollable, icon-led timeline. Works inside a
/// Chat bubble or SOS details; no horizontal route overflows a narrow phone.
class UserRouteView extends StatefulWidget {
  const UserRouteView({
    super.key,
    required this.routes,
    required this.names,
    this.compact = false,
    this.message = false,
    this.title,
  });
  final List<UserRoute> routes;
  final RouteDeviceNames names;
  final bool compact;
  final bool message;
  final String? title;
  @override
  State<UserRouteView> createState() => _UserRouteViewState();
}

class _UserRouteViewState extends State<UserRouteView> {
  late final _liveRoutes = ValueNotifier<List<UserRoute>>(widget.routes);
  @override
  void didUpdateWidget(UserRouteView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.names, widget.names)) {
      unawaited(
        widget.names.load().catchError((Object _) => <String, String>{}),
      );
    }
    if (!listEquals(oldWidget.routes, widget.routes)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !listEquals(_liveRoutes.value, widget.routes)) {
          _liveRoutes.value = widget.routes;
        }
      });
    }
  }

  @override
  void dispose() {
    _liveRoutes.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(widget.names.load().catchError((Object _) => <String, String>{}));
  }

  String _label(UserRouteNode node) {
    final alias = widget.names.labels[node.keyId];
    return alias?.isNotEmpty == true
        ? alias!
        : node.local
        ? routeText(context, 'This device', 'เครื่องนี้')
        : routeText(context, 'Device', 'เครื่อง');
  }

  String _count(UserRoute route) => route.nodes.length < 2
      ? routeText(
          context,
          'Next device not recorded',
          'ยังไม่มีข้อมูลเครื่องถัดไป',
        )
      : route.intermediateCount == null
      ? routeText(
          context,
          'Intermediate route unknown',
          'ยังไม่ทราบเส้นทางระหว่างกลาง',
        )
      : route.intermediateCount == 0
      ? routeText(context, 'Direct · 1 hop', 'ส่งตรง · 1 ทอด')
      : routeText(
          context,
          '${route.intermediateCount} intermediary device(s) · ${route.hopCount} hops',
          'ผ่านตัวกลาง ${route.intermediateCount} เครื่อง · ${route.hopCount} ทอด',
        );

  Future<void> _rename(UserRouteNode node) async {
    final key = node.keyId;
    if (key == null) return;
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => _RouteNicknameDialog(
        code: shortRouteDeviceCode(key),
        initial: widget.names.labels[key] ?? '',
      ),
    );
    if (value == null || !mounted) return;
    try {
      await widget.names.save(key, value);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              routeText(
                context,
                'Could not save the nickname. Try again.',
                'บันทึกชื่อเรียกไม่ได้ กรุณาลองอีกครั้ง',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _open() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * .85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: ValueListenableBuilder<List<UserRoute>>(
            valueListenable: _liveRoutes,
            builder: (context, routes, _) => UserRouteView(
              routes: routes,
              names: widget.names,
              message: widget.message,
              title: widget.title,
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.names,
    builder: (context, _) {
      final title =
          widget.title ??
          routeText(
            context,
            widget.message ? 'Message route' : 'SOS route',
            widget.message ? 'เส้นทางข้อความ' : 'เส้นทาง SOS',
          );
      if (widget.compact) {
        final route = widget.routes.firstOrNull;
        return Semantics(
          button: true,
          label: title,
          child: InkWell(
            onTap: _open,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.route_rounded,
                    size: 28,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        if (route != null && route.nodes.isNotEmpty)
                          Text(
                            '${routeText(context, 'From', 'จาก')} ${_label(route.nodes.first)}${route.nodes.first.keyId == null ? '' : ' · ${shortRouteDeviceCode(route.nodes.first.keyId!)}'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        Text(
                          route == null
                              ? routeText(
                                  context,
                                  'Route not recorded',
                                  'ยังไม่มีเส้นทางที่บันทึก',
                                )
                              : _count(route),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (widget.routes.isEmpty)
            Text(
              routeText(
                context,
                'No route information is stored for this item.',
                'รายการนี้ยังไม่มีข้อมูลเส้นทางที่บันทึกไว้',
              ),
            ),
          for (var index = 0; index < widget.routes.length; index++) ...[
            if (index > 0) const Divider(height: 32),
            _route(widget.routes[index]),
          ],
          const SizedBox(height: 16),
          Text(
            routeText(
              context,
              'A device storing a message does not mean a person has read it. Nicknames are labels saved on this device.',
              'การเก็บข้อความบนเครื่องไม่ได้หมายความว่ามีคนอ่านแล้ว ชื่อเรียกเป็นป้ายที่ตั้งไว้บนเครื่องนี้',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    },
  );

  Widget _route(UserRoute route) {
    final colors = Theme.of(context).colorScheme;
    final good =
        route.stage == UserRouteStage.confirmed ||
        route.stage == UserRouteStage.received;
    final bad = route.stage == UserRouteStage.failed;
    final color = bad
        ? colors.error
        : good
        ? (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xff81d6aa)
              : const Color(0xff21734b))
        : colors.primary;
    final nodes = route.nodes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(routeStageIcon(route.stage), size: 32, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                routeStageText(context, route.stage),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(_count(route), style: Theme.of(context).textTheme.bodyMedium),
        Text(
          routeText(
            context,
            switch (route.extent) {
              UserRouteExtent.thisDevice => 'Route to this device',
              UserRouteExtent.nextDevice => 'Known route to the next device',
              UserRouteExtent.endpointsOnly =>
                nodes.length < 2
                    ? 'Source device recorded for this SOS'
                    : 'Only the source and destination are known',
            },
            switch (route.extent) {
              UserRouteExtent.thisDevice => 'เส้นทางถึงเครื่องนี้',
              UserRouteExtent.nextDevice => 'ช่วงเส้นทางถึงเครื่องถัดไปที่ทราบ',
              UserRouteExtent.endpointsOnly =>
                nodes.length < 2
                    ? 'เครื่องต้นทางที่บันทึกเหตุนี้'
                    : 'ทราบเฉพาะต้นทางและปลายทาง',
            },
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < nodes.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: route.extent == UserRouteExtent.endpointsOnly
                  ? const Icon(Icons.more_vert_rounded, size: 24)
                  : Container(
                      width: 2,
                      height: 20,
                      color: colors.outlineVariant,
                    ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                child: Icon(
                  i == 0
                      ? Icons.smartphone_rounded
                      : i == nodes.length - 1
                      ? Icons.smartphone_rounded
                      : Icons.hub_rounded,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _label(nodes[i]),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (nodes[i].keyId != null)
                      Text(
                        shortRouteDeviceCode(nodes[i].keyId!),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    Text(
                      routeText(
                        context,
                        i == 0
                            ? 'Source'
                            : i == nodes.length - 1
                            ? (nodes[i].local
                                  ? 'This device'
                                  : (route.extent == UserRouteExtent.nextDevice
                                        ? 'Next device'
                                        : 'Destination'))
                            : 'Intermediary',
                        i == 0
                            ? 'ต้นทาง'
                            : i == nodes.length - 1
                            ? (nodes[i].local
                                  ? 'เครื่องนี้'
                                  : (route.extent == UserRouteExtent.nextDevice
                                        ? 'เครื่องถัดไป'
                                        : 'ปลายทาง'))
                            : 'ตัวกลาง',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (nodes[i].keyId != null)
                IconButton(
                  tooltip: routeText(context, 'Set nickname', 'ตั้งชื่อเรียก'),
                  onPressed: () => _rename(nodes[i]),
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RouteNicknameDialog extends StatefulWidget {
  const _RouteNicknameDialog({required this.code, required this.initial});
  final String code, initial;
  @override
  State<_RouteNicknameDialog> createState() => _RouteNicknameDialogState();
}

class _RouteNicknameDialogState extends State<_RouteNicknameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      routeText(context, 'Name this device', 'ตั้งชื่อเรียกเครื่องนี้'),
    ),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              routeText(context, 'Code ${widget.code}', 'รหัส ${widget.code}'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _controller,
              autofocus: true,
              maxLength: 24,
              validator: (value) => RouteDeviceNames.validName(value ?? '')
                  ? null
                  : routeText(
                      context,
                      'Use a short, readable nickname.',
                      'ใช้ชื่อเรียกสั้น ๆ ที่อ่านได้',
                    ),
              decoration: InputDecoration(
                labelText: routeText(
                  context,
                  'Nickname, e.g. Mum’s phone',
                  'ชื่อเรียก เช่น มือถือแม่',
                ),
              ),
            ),
            Text(
              routeText(
                context,
                'Saved only on this device. Leave blank to use the device code.',
                'ชื่อเรียกใช้เฉพาะบนเครื่องนี้ เว้นว่างเพื่อใช้รหัสเครื่อง',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(routeText(context, 'Cancel', 'ยกเลิก')),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _controller.text);
          }
        },
        child: Text(routeText(context, 'Save', 'บันทึก')),
      ),
    ],
  );
}
