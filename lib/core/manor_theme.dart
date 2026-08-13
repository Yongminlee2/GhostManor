import 'package:flutter/material.dart';

const manorInk = Color(0xFF170F21);
const manorPanel = Color(0xF2261937);
const manorPanelSoft = Color(0xE8332447);
const manorPurple = Color(0xFF8C6BD4);
const manorGold = Color(0xFFD9A85F);
const manorGoldBright = Color(0xFFFFD38A);
const manorCream = Color(0xFFF5E6C8);
const manorMuted = Color(0xFFB9A9C8);

ThemeData buildManorTheme() {
  final colors =
      ColorScheme.fromSeed(
        seedColor: manorPurple,
        brightness: Brightness.dark,
      ).copyWith(
        primary: manorGold,
        onPrimary: manorInk,
        secondary: manorPurple,
        surface: const Color(0xFF2A1D38),
        onSurface: manorCream,
        error: const Color(0xFFE77D79),
      );

  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );
  return ThemeData(
    colorScheme: colors,
    scaffoldBackgroundColor: manorInk,
    dividerColor: const Color(0xFF5B466E),
    textTheme: ThemeData.dark().textTheme.apply(
      bodyColor: manorCream,
      displayColor: manorCream,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: manorInk,
        backgroundColor: manorGold,
        disabledBackgroundColor: const Color(0xFF57445E),
        disabledForegroundColor: const Color(0xFFB9A9C8),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: rounded,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: manorGoldBright,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: manorCream),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF2A1D38),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: manorGold, width: 1.2),
      ),
      titleTextStyle: const TextStyle(
        color: manorGoldBright,
        fontSize: 21,
        fontWeight: FontWeight.w900,
      ),
      contentTextStyle: const TextStyle(
        color: manorCream,
        fontSize: 15,
        height: 1.5,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? manorGoldBright
            : manorMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? manorGold.withValues(alpha: 0.48)
            : const Color(0xFF4B3A5A),
      ),
    ),
  );
}

class ManorPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color color;

  const ManorPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.color = manorPanel,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: borderRadius,
      border: Border.all(color: manorGold.withValues(alpha: 0.72), width: 1.2),
      boxShadow: const [
        BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8)),
      ],
    ),
    child: Padding(padding: padding, child: child),
  );
}

class ManorRule extends StatelessWidget {
  const ManorRule({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider(color: manorGold, thickness: 1)),
      Transform.rotate(
        angle: 0.785398,
        child: Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: manorGold,
            border: Border.all(color: manorGoldBright),
          ),
        ),
      ),
      const Expanded(child: Divider(color: manorGold, thickness: 1)),
    ],
  );
}
