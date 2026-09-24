/// Selectable channel / transaction row for LFW limits review.
class LfwNamedOption {
  const LfwNamedOption({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

/// Parsed Channel + Transactions lists from the LFW limits snapshot.
class LfwLimitsOptions {
  const LfwLimitsOptions({
    required this.channels,
    required this.transactions,
  });

  final List<LfwNamedOption> channels;
  final List<LfwNamedOption> transactions;

  factory LfwLimitsOptions.fromSnapshot(Map<String, dynamic> snapshot) {
    return LfwLimitsOptions(
      channels: _parseOptions(
        snapshot['accessPoints'],
        preferredKeys: const [
          'accessPoints',
          'accessPointList',
          'items',
          'list',
          'data',
        ],
      ),
      transactions: _firstNonEmpty([
        _parseOptions(
          snapshot['taskGroups'],
          preferredKeys: const [
            'taskGroups',
            'groups',
            'items',
            'list',
            'data',
          ],
        ),
        _parseOptions(
          snapshot['resourceTasks'],
          preferredKeys: const [
            'tasks',
            'resourceTasks',
            'items',
            'list',
            'data',
          ],
        ),
        _parseOptions(
          snapshot['limitPackage'],
          preferredKeys: const [
            'transactions',
            'tasks',
            'items',
            'list',
            'data',
          ],
        ),
        _parseOptions(
          snapshot['partyLimits'],
          preferredKeys: const [
            'transactions',
            'tasks',
            'limits',
            'items',
            'list',
            'data',
          ],
        ),
      ]),
    );
  }

  static List<LfwNamedOption> _firstNonEmpty(
    List<List<LfwNamedOption>> candidates,
  ) {
    for (final list in candidates) {
      if (list.isNotEmpty) return list;
    }
    return const [];
  }

  static List<LfwNamedOption> _parseOptions(
    dynamic root, {
    required List<String> preferredKeys,
  }) {
    final seen = <String>{};
    final out = <LfwNamedOption>[];

    void add(LfwNamedOption option) {
      if (option.id.isEmpty || option.label.isEmpty) return;
      if (!seen.add(option.id)) return;
      out.add(option);
    }

    void walk(dynamic node, {int depth = 0}) {
      if (node == null || depth > 4) return;
      if (node is List) {
        for (final item in node) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final option = _optionFromMap(map);
            if (option != null) {
              add(option);
            } else {
              walk(map, depth: depth + 1);
            }
          }
        }
        return;
      }
      if (node is! Map) return;
      final map = Map<String, dynamic>.from(node);
      for (final key in preferredKeys) {
        if (map.containsKey(key)) {
          walk(map[key], depth: depth + 1);
        }
      }
      // Fall back: any nested list that looks like option rows.
      if (out.isEmpty) {
        for (final value in map.values) {
          if (value is List) walk(value, depth: depth + 1);
        }
      }
    }

    walk(root);
    return out;
  }

  static LfwNamedOption? _optionFromMap(Map<String, dynamic> map) {
    final id = _firstString(map, const [
          'id',
          'code',
          'accessPointId',
          'taskId',
          'taskGroupId',
          'transactionId',
          'name',
        ]) ??
        '';
    final label = _firstString(map, const [
          'description',
          'displayName',
          'label',
          'name',
          'taskName',
          'transactionName',
          'accessPointName',
          'title',
        ]) ??
        '';
    if (id.isEmpty && label.isEmpty) return null;
    final resolvedId = id.isNotEmpty ? id : label;
    final resolvedLabel = label.isNotEmpty ? label : id;
    // Skip shell objects that only wrap nested collections.
    if (map.values.any((v) => v is List) &&
        !_looksLikeLeafOption(map, resolvedLabel)) {
      return null;
    }
    return LfwNamedOption(id: resolvedId, label: resolvedLabel);
  }

  static bool _looksLikeLeafOption(Map<String, dynamic> map, String label) {
    return map.containsKey('description') ||
        map.containsKey('displayName') ||
        map.containsKey('taskName') ||
        map.containsKey('accessPointName') ||
        (label.isNotEmpty &&
            (map.containsKey('id') ||
                map.containsKey('code') ||
                map.containsKey('name')));
  }

  static String? _firstString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null || value is Map || value is List) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}
