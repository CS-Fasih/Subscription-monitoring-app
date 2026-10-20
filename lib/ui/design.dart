import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_store.dart';
import '../core/models.dart';

abstract final class Palette {
  static const background = Color(0xFFF7F8FA);
  static const ink = Color(0xFF182923);
  static const muted = Color(0xFF7A8380);
  static const green = Color(0xFF20634C);
  static const lightGreen = Color(0xFFEAF2ED);
  static const border = Color(0xFFE7EBE8);
  static const coral = Color(0xFFD38972);
  static const gold = Color(0xFFD6B76F);
  static const blue = Color(0xFF89A5BE);
}

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Inter',
  scaffoldBackgroundColor: Palette.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Palette.green,
    primary: Palette.green,
    surface: Colors.white,
    onSurface: Palette.ink,
    error: const Color(0xFFB23D3D),
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 13, height: 1.5, color: Palette.ink),
    bodySmall: TextStyle(fontSize: 12, height: 1.5, color: Palette.muted),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -.5,
    ),
    titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  ),
  dividerTheme: const DividerThemeData(
    color: Palette.border,
    space: 1,
    thickness: 1,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
    labelStyle: const TextStyle(fontSize: 13, color: Palette.muted),
    hintStyle: const TextStyle(fontSize: 13, color: Palette.muted),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: Palette.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: Palette.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: Palette.green, width: 1.5),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: Palette.green,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Palette.ink,
      side: const BorderSide(color: Palette.border),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: Palette.green,
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  chipTheme: ChipThemeData(
    side: const BorderSide(color: Palette.border),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: Palette.lightGreen,
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Palette.ink,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
);

String money(AppStore store, num cents, {int decimals = 2}) =>
    NumberFormat.simpleCurrency(
      name: store.settings.currency,
      decimalDigits: decimals,
    ).format(cents / 100);

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color = Colors.white,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Palette.border),
    ),
    child: child,
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w600,
              letterSpacing: -1.2,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            style: const TextStyle(
              color: Palette.muted,
              fontSize: 12,
              height: 1.7,
            ),
          ),
        ],
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 26),
        child: constraints.maxWidth < 620
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading,
                  if (action != null) ...[const SizedBox(height: 18), action!],
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: heading),
                  if (action != null) ...[const SizedBox(width: 20), action!],
                ],
              ),
      );
    },
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 5),
              Text(
                subtitle!,
                style: const TextStyle(color: Palette.muted, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
      if (trailing != null) trailing!,
    ],
  );
}

class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    this.color = Palette.green,
    this.background = Palette.lightGreen,
    this.dot = false,
  });
  final String label;
  final Color color, background;
  final bool dot;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot) ...[
          Icon(Icons.circle, size: 5, color: color),
          const SizedBox(width: 5),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    ),
  );
}

Color categoryColor(SubscriptionCategory category) => switch (category) {
  SubscriptionCategory.entertainment => Palette.green,
  SubscriptionCategory.productivity => Palette.gold,
  SubscriptionCategory.lifestyle => Palette.coral,
  SubscriptionCategory.utilities => Palette.blue,
  SubscriptionCategory.education => const Color(0xFF9F94B6),
  SubscriptionCategory.other => const Color(0xFFADB5B1),
};

IconData categoryIcon(SubscriptionCategory category) => switch (category) {
  SubscriptionCategory.entertainment => Icons.play_circle_outline_rounded,
  SubscriptionCategory.productivity => Icons.work_outline_rounded,
  SubscriptionCategory.lifestyle => Icons.favorite_border_rounded,
  SubscriptionCategory.utilities => Icons.cloud_outlined,
  SubscriptionCategory.education => Icons.school_outlined,
  SubscriptionCategory.other => Icons.widgets_outlined,
};

class ServiceIcon extends StatelessWidget {
  const ServiceIcon(this.subscription, {super.key, this.size = 38});
  final Subscription subscription;
  final double size;
  @override
  Widget build(BuildContext context) {
    final name = subscription.name.toLowerCase();
    Color bg = categoryColor(subscription.category).withValues(alpha: .12);
    Color fg = categoryColor(subscription.category);
    Widget symbol = Icon(
      categoryIcon(subscription.category),
      size: size * .5,
      color: fg,
    );
    if (name.contains('netflix')) {
      bg = const Color(0xFF191919);
      fg = const Color(0xFFE83C42);
      symbol = Text(
        'N',
        style: TextStyle(
          color: fg,
          fontSize: size * .62,
          fontWeight: FontWeight.w900,
        ),
      );
    } else if (name.contains('spotify')) {
      bg = const Color(0xFF191919);
      symbol = Icon(
        Icons.graphic_eq_rounded,
        color: const Color(0xFF52CD83),
        size: size * .62,
      );
    } else if (name.contains('notion')) {
      bg = const Color(0xFFF3F3F1);
      symbol = Text(
        'N',
        style: TextStyle(
          fontFamily: 'Newsreader',
          color: Palette.ink,
          fontSize: size * .65,
          fontWeight: FontWeight.w700,
        ),
      );
    } else if (name.contains('figma')) {
      bg = const Color(0xFFF4F0EC);
      symbol = CustomPaint(
        size: Size(size * .4, size * .6),
        painter: _FigmaMark(),
      );
    } else if (name.contains('adobe')) {
      bg = const Color(0xFFEA4944);
      symbol = Text(
        'A',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * .6,
          fontWeight: FontWeight.w800,
        ),
      );
    } else if (name.contains('icloud')) {
      bg = const Color(0xFFE8F3FC);
      symbol = Icon(
        Icons.cloud_rounded,
        color: const Color(0xFF4199DB),
        size: size * .65,
      );
    } else if (name.contains('strava')) {
      bg = const Color(0xFFFFF0E8);
      symbol = Icon(
        Icons.landscape_rounded,
        color: const Color(0xFFEE713B),
        size: size * .65,
      );
    } else if (name.contains('headspace')) {
      bg = const Color(0xFFFFF4E8);
      symbol = Icon(
        Icons.circle,
        color: const Color(0xFFEF9B51),
        size: size * .5,
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * .24),
      ),
      child: symbol,
    );
  }
}

class _FigmaMark extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 4;
    final colors = [
      const Color(0xFFE96E54),
      const Color(0xFFF49A87),
      const Color(0xFFA87BE7),
      const Color(0xFF70B9DC),
      const Color(0xFF64B99B),
    ];
    for (var i = 0; i < 5; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            i.isEven ? 0 : size.width / 2,
            (i ~/ 2) * size.height / 3,
            size.width / 2,
            size.height / 3,
          ),
          Radius.circular(r),
        ),
        Paint()..color = colors[i],
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.icon = Icons.layers_outlined,
  });
  final String title, message;
  final Widget? action;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 20),
    child: Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Palette.lightGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Palette.green, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Palette.muted, fontSize: 12),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

void showMessage(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Confirm',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirm),
          ),
        ],
      ),
    ) ??
    false;
