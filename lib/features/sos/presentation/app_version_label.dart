import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Uses installed package metadata, including build-number overrides.
class AppVersionLabel extends StatefulWidget {
  const AppVersionLabel({super.key});

  @override
  State<AppVersionLabel> createState() => _AppVersionLabelState();
}

class _AppVersionLabelState extends State<AppVersionLabel> {
  late final Future<PackageInfo> _package = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
    future: _package,
    builder: (context, snapshot) {
      final package = snapshot.data;
      final prefix = Localizations.localeOf(context).languageCode == 'th'
          ? 'เวอร์ชัน'
          : 'Version';
      final version = package == null || package.version.isEmpty
          ? '—'
          : package.buildNumber.isEmpty
          ? package.version
          : '${package.version} (${package.buildNumber})';
      return Text(
        '$prefix $version',
        key: const ValueKey('settings-app-version'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    },
  );
}
