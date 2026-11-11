import 'dart:math' as math;
import 'package:flutter/material.dart';

const cyan = Color(0xFF00E5FF);
const ink = Color(0xFF000000);
const panel = Color(0xFF0E1417);
const line = Color(0xFF1E2A30);
const dim = Color(0xFF8FA3AD);
const gold = Color(0xFFFFC53D);

ThemeData appTheme({bool rest = false}) {
  final bg = rest ? cyan : ink;
  final fg = rest ? ink : Colors.white;
  final accent = rest ? ink : cyan;
  final scheme = ColorScheme.fromSeed(seedColor: cyan, brightness: rest ? Brightness.light : Brightness.dark)
      .copyWith(surface: bg, primary: accent, onPrimary: bg, onSurface: fg, secondary: accent);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    textTheme: Typography.whiteMountainView.apply(bodyColor: fg, displayColor: fg),
    appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
    navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ink,
        indicatorColor: cyan.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1))),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: bg,
            minimumSize: const Size(64, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            minimumSize: const Size(64, 52),
            side: BorderSide(color: accent, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5))),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent, minimumSize: const Size(48, 48))),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: rest ? Colors.white24 : panel,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
        hintStyle: TextStyle(color: rest ? Colors.black54 : dim)),
    chipTheme: ChipThemeData(
        backgroundColor: panel,
        selectedColor: cyan,
        side: const BorderSide(color: line),
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
        secondaryLabelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w900),
        checkmarkColor: ink),
    dividerColor: line,
    snackBarTheme: const SnackBarThemeData(backgroundColor: panel, contentTextStyle: TextStyle(color: Colors.white)),
  );
}

/// Bold uppercase heading.
class H extends StatelessWidget {
  const H(this.text, {super.key, this.size = 14, this.color});
  final String text;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: TextStyle(
          fontSize: size, fontWeight: FontWeight.w900, letterSpacing: 2, color: color ?? dim, height: 1.1));
}

class Big extends StatelessWidget {
  const Big(this.text, {super.key, this.size = 56, this.color});
  final String text;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          height: 1,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()]));
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.onTap, this.border, this.padding = 16});
  final Widget child;
  final VoidCallback? onTap;
  final Color? border;
  final double padding;
  @override
  Widget build(BuildContext context) => Material(
      color: panel,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), side: BorderSide(color: border ?? line, width: border == null ? 1 : 2)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: EdgeInsets.all(padding), child: child)));
}

class Bar extends StatelessWidget {
  const Bar(this.value, {super.key, this.color = cyan, this.height = 10});
  final double value;
  final Color color;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0), minHeight: height, color: color, backgroundColor: line));
}

Future<String?> askText(BuildContext context, String title,
    {String hint = '', String initial = '', String ok = 'SAVE', TextInputType? keyboard}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
              backgroundColor: panel,
              title: H(title, color: Colors.white, size: 16),
              content: TextField(
                  controller: c,
                  autofocus: true,
                  keyboardType: keyboard,
                  decoration: InputDecoration(hintText: hint),
                  onSubmitted: (v) => Navigator.pop(ctx, v)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
                FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(ok)),
              ]));
}

Future<bool> confirm(BuildContext context, String title, String body, {String ok = 'OK', String cancel = 'NOT NOW'}) async =>
    await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                backgroundColor: panel,
                title: H(title, color: Colors.white, size: 16),
                content: Text(body),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancel)),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
                ])) ??
    false;

void toast(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

// ---- Poster illustrations, drawn in code --------------------------------
enum PosterArt { flame, door, vault, shield, hourglass }

class Poster extends StatelessWidget {
  const Poster(this.art, {super.key, this.size = 96, this.color = cyan, this.level = 1});
  final PosterArt art;
  final double size;
  final Color color;

  /// 0..1, used by the flame to grow with the streak.
  final double level;
  @override
  Widget build(BuildContext context) => SizedBox.square(
      dimension: size, child: CustomPaint(painter: _PosterPainter(art, color, level)));
}

class _PosterPainter extends CustomPainter {
  _PosterPainter(this.art, this.color, this.level);
  final PosterArt art;
  final Color color;
  final double level;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final fill = Paint()..color = color;
    final dark = Paint()..color = ink;
    final soft = Paint()..color = color.withValues(alpha: 0.25);
    switch (art) {
      case PosterArt.flame:
        final k = 0.55 + 0.45 * level.clamp(0.0, 1.0);
        Path flame(double sc) {
          final cx = w / 2, base = h * 0.95, top = base - h * 0.9 * sc, r = w * 0.36 * sc;
          return Path()
            ..moveTo(cx, top)
            ..cubicTo(cx + r * 0.3, top + (base - top) * 0.3, cx + r * 1.2, top + (base - top) * 0.45, cx + r, base - r * 0.7)
            ..arcToPoint(Offset(cx - r, base - r * 0.7), radius: Radius.circular(r), clockwise: true)
            ..cubicTo(cx - r * 1.2, top + (base - top) * 0.55, cx - r * 0.4, top + (base - top) * 0.5, cx, top)
            ..close();
        }
        canvas.drawPath(flame(k), fill);
        canvas.drawPath(flame(k * 0.5), dark);
      case PosterArt.door:
        canvas.drawRect(Rect.fromLTWH(w * 0.2, h * 0.08, w * 0.6, h * 0.84), fill);
        final open = Path()
          ..moveTo(w * 0.28, h * 0.16)
          ..lineTo(w * 0.62, h * 0.24)
          ..lineTo(w * 0.62, h * 0.92)
          ..lineTo(w * 0.28, h * 0.92)
          ..close();
        canvas.drawPath(open, dark);
        canvas.drawCircle(Offset(w * 0.55, h * 0.58), w * 0.03, fill);
        canvas.drawRect(Rect.fromLTWH(w * 0.05, h * 0.92, w * 0.9, h * 0.04), fill);
      case PosterArt.vault:
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.1, h * 0.12, w * 0.8, h * 0.76), Radius.circular(w * 0.06)), fill);
        canvas.drawCircle(Offset(w / 2, h / 2), w * 0.24, dark);
        canvas.drawCircle(Offset(w / 2, h / 2), w * 0.08, fill);
        for (var i = 0; i < 4; i++) {
          final a = i * math.pi / 2 + math.pi / 4;
          canvas.drawLine(Offset(w / 2, h / 2), Offset(w / 2 + math.cos(a) * w * 0.2, h / 2 + math.sin(a) * w * 0.2),
              Paint()..color = color..strokeWidth = w * 0.035);
        }
      case PosterArt.shield:
        final p = Path()
          ..moveTo(w / 2, h * 0.06)
          ..lineTo(w * 0.88, h * 0.22)
          ..lineTo(w * 0.82, h * 0.62)
          ..quadraticBezierTo(w * 0.7, h * 0.86, w / 2, h * 0.95)
          ..quadraticBezierTo(w * 0.3, h * 0.86, w * 0.18, h * 0.62)
          ..lineTo(w * 0.12, h * 0.22)
          ..close();
        canvas.drawPath(p, fill);
        canvas.drawPath(
            Path()
              ..moveTo(w * 0.32, h * 0.5)
              ..lineTo(w * 0.46, h * 0.64)
              ..lineTo(w * 0.7, h * 0.36),
            Paint()..color = ink..style = PaintingStyle.stroke..strokeWidth = w * 0.08..strokeCap = StrokeCap.round);
      case PosterArt.hourglass:
        canvas.drawRect(Rect.fromLTWH(w * 0.2, h * 0.06, w * 0.6, h * 0.07), fill);
        canvas.drawRect(Rect.fromLTWH(w * 0.2, h * 0.87, w * 0.6, h * 0.07), fill);
        canvas.drawPath(
            Path()
              ..moveTo(w * 0.26, h * 0.13)
              ..lineTo(w * 0.74, h * 0.13)
              ..lineTo(w * 0.5, h * 0.5)
              ..close(),
            soft);
        canvas.drawPath(
            Path()
              ..moveTo(w * 0.5, h * 0.5)
              ..lineTo(w * 0.74, h * 0.87)
              ..lineTo(w * 0.26, h * 0.87)
              ..close(),
            fill);
    }
  }

  @override
  bool shouldRepaint(_PosterPainter old) => old.art != art || old.color != color || old.level != level;
}

/// One year of days as a 53x7 grid. [level] returns 0 (empty), 1 (half
/// credit), 3 (full) or 4 (gold); negative means a frozen day.
class Heatmap extends StatelessWidget {
  const Heatmap({super.key, required this.today, required this.level});
  final int today;
  final int Function(int day) level;
  @override
  Widget build(BuildContext context) => AspectRatio(
      aspectRatio: 53 / 7, child: CustomPaint(painter: _HeatPainter(today, level)));
}

class _HeatPainter extends CustomPainter {
  _HeatPainter(this.today, this.level);
  final int today;
  final int Function(int day) level;
  @override
  void paint(Canvas canvas, Size s) {
    final cell = s.width / 53;
    // Column 52 holds the current week; rows are Monday..Sunday.
    final weekday = DateTime.utc(1970, 1, 1 + today).weekday; // 1..7
    final lastMonday = today - (weekday - 1);
    for (var c = 0; c < 53; c++) {
      for (var r = 0; r < 7; r++) {
        final day = lastMonday - (52 - c) * 7 + r;
        if (day > today) continue;
        final l = level(day);
        final paint = Paint()
          ..color = l < 0
              ? const Color(0xFF3A5560)
              : l == 0
                  ? line
                  : l >= 4
                      ? gold
                      : cyan.withValues(alpha: 0.35 + 0.65 * (l.clamp(1, 3) / 3));
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(c * cell + 0.8, r * cell + 0.8, cell - 1.6, cell - 1.6), const Radius.circular(1.5)),
            paint);
      }
    }
  }

  @override
  bool shouldRepaint(_HeatPainter old) => true;
}
