import 'package:flutter/material.dart';

import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// Small helper that slices a full list into pages of [pageSize] and keeps
/// the current page clamped in range whenever the underlying list length
/// (or the page size) changes — shared by every "View All" transaction
/// list that paginates client-side rather than hitting the host again.
class ListPager<T> {
  ListPager({required this.pageSize}) : assert(pageSize > 0);

  final int pageSize;
  int _page = 0;

  int get page => _page;

  int pageCount(int itemCount) =>
      itemCount == 0 ? 1 : (itemCount / pageSize).ceil();

  /// Clamps [_page] into range for [itemCount] items and returns the
  /// (possibly adjusted) current page — call this on every build so a
  /// filter/account change that shrinks the list never strands the user
  /// on a now-empty page.
  int clamp(int itemCount) {
    final lastPage = pageCount(itemCount) - 1;
    if (_page > lastPage) _page = lastPage < 0 ? 0 : lastPage;
    if (_page < 0) _page = 0;
    return _page;
  }

  List<T> slice(List<T> items) {
    final start = _page * pageSize;
    if (start >= items.length) return const [];
    final end = start + pageSize > items.length
        ? items.length
        : start + pageSize;
    return items.sublist(start, end);
  }

  void reset() => _page = 0;

  void goTo(int page) => _page = page;
}

/// "Showing X–Y of Z" label + Prev/Next pager, rendered under a paginated
/// list. Stays hidden when everything already fits on one page.
class PaginatedListControls extends StatelessWidget {
  const PaginatedListControls({
    super.key,
    required this.currentPage,
    required this.pageCount,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
  });

  /// 0-indexed current page.
  final int currentPage;
  final int pageCount;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) return const SizedBox.shrink();

    final start = currentPage * pageSize + 1;
    final end = (currentPage + 1) * pageSize > totalItems
        ? totalItems
        : (currentPage + 1) * pageSize;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing $start–$end of $totalItems',
              style: TextStyle(
                fontSize: 12,
                color: HomeColors.textSecondary(context),
              ),
            ),
          ),
          _PagerButton(
            icon: Icons.chevron_left_rounded,
            enabled: currentPage > 0,
            onTap: () => onPageChanged(currentPage - 1),
          ),
          const SizedBox(width: 4),
          Text(
            '${currentPage + 1} / $pageCount',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: HomeColors.textPrimary(context),
            ),
          ),
          const SizedBox(width: 4),
          _PagerButton(
            icon: Icons.chevron_right_rounded,
            enabled: currentPage < pageCount - 1,
            onTap: () => onPageChanged(currentPage + 1),
          ),
        ],
      ),
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? HomeColors.textPrimary(context)
        : HomeColors.textSecondary(context).withValues(alpha: 0.35);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled
                ? HomeColors.divider(context)
                : HomeColors.divider(context).withValues(alpha: 0.5),
          ),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
