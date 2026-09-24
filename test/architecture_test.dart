import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Layering rules for `lib/src`, checked by reading imports.
///
/// `common/` is shared by both user types, so it must not reach into a
/// user-type folder: a Retail build would otherwise pull in Corporate
/// infrastructure (and vice versa) just by using a shared screen.
void main() {
  final root = Directory('lib/src');

  Iterable<File> dartFilesUnder(String segment) => root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => _segments(f.path).contains(segment));

  test('nothing under common/ imports from corp/', () {
    final corpImport = RegExp(
      r'''^\s*(import|export)\s+['"]package:ubci_bank/src/(.+/)?corp/''',
      multiLine: true,
    );

    final offenders = <String>[
      for (final file in dartFilesUnder('common'))
        for (final match in corpImport.allMatches(file.readAsStringSync()))
          '${file.path}: ${match.group(0)!.trim()}',
    ];

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('the shared dashboard files exist where the layout expects them', () {
    // A guard against the personalization code drifting back into a
    // user-type folder.
    const expected = [
      'lib/src/core/models/common/dashboard/dashboard_config.dart',
      'lib/src/core/models/common/dashboard/dashboard_descriptor.dart',
      'lib/src/core/models/common/dashboard/dashboard_widget_catalog.dart',
      'lib/src/core/utils/common/dashboard_grid_span.dart',
      'lib/src/core/utils/common/dashboard_widget_labels.dart',
      'lib/src/infra/network/apis/common/obdx_dashboard_api.dart',
      'lib/src/infra/network/dashboard_api_constants.dart',
      'lib/src/infra/repositories/common/dashboard_repository.dart',
      'lib/src/view/providers/common/personalization_providers.dart',
      'lib/src/view/screens/common/personalize/personalize_panel.dart',
      'lib/src/view/screens/common/personalize/dashboard_tile_grid.dart',
      'lib/src/view/screens/common/personalize/dashboard_widget_registry.dart',
      'lib/src/view/screens/corp/dashboard_widgets/corp_widget_registry.dart',
      'lib/src/view/screens/retail/dashboard_widgets/retail_widget_registry.dart',
    ];
    final missing = [
      for (final path in expected)
        if (!File(path).existsSync()) path,
    ];
    expect(missing, isEmpty);
  });
}

List<String> _segments(String path) => path.split(RegExp(r'[\\/]'));
