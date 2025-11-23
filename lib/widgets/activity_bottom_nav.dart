import 'package:flutter/material.dart';
import '../theme/sikawan_theme.dart';

class ActivityBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ActivityBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItem(Icons.how_to_reg_rounded, 'Absensi'),
      _NavItem(Icons.description_outlined, 'Notula'),
      _NavItem(Icons.photo_library_outlined, 'Dokumentasi'),
      _NavItem(Icons.folder_open_outlined, 'Materi'),
      _NavItem(Icons.auto_stories_outlined, 'Pengembangan'),
    ];

    Widget btn(int i) {
      final selected = i == currentIndex;
      final data = items[i];

      return InkWell(
        onTap: () => onTap(i),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: selected ? 46 : 40,
          width: selected ? 46 : 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: selected
                ? const LinearGradient(
                    colors: [SiKawanTheme.primary, SiKawanTheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: SiKawanTheme.primary.withValues(alpha: 0.40),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ]
                : null,
          ),
          child: Icon(
            data.icon,
            size: selected ? 22 : 20,
            color: Colors.white,
          ),
        ),
      );
    }

    final bottomPad = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPad > 0 ? 6 : 12),
        child: Center(
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: SiKawanTheme.textPrimary,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                btn(0),
                const SizedBox(width: 8),
                btn(1),
                const SizedBox(width: 8),
                btn(2),
                const SizedBox(width: 8),
                btn(3),
                const SizedBox(width: 8),
                btn(4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}
