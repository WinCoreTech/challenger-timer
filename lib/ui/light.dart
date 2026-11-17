import 'package:flutter/material.dart';

/// Light theme (plan v2 phase 3).
///
/// The app is drawn once, in the dark navy palette. The light theme reverses
/// brightness while keeping hues (the same as CSS `invert(1) hue-rotate(180deg)`):
/// navy becomes pale blue-grey, white text becomes dark, orange stays orange.
/// Photos are filtered a second time, which restores ordinary colours. Very
/// saturated pixels can shift slightly because values are clamped in between.
const List<double> _lightMatrix = [
  0.574, -1.430, -0.144, 0, 255, //
  -0.426, -0.430, -0.144, 0, 255,
  -0.426, -1.430, 0.856, 0, 255,
  0, 0, 0, 1, 0,
];

const ColorFilter lightFilter = ColorFilter.matrix(_lightMatrix);

class LightMode extends InheritedWidget {
  const LightMode({super.key, required this.light, required super.child});
  final bool light;
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<LightMode>()?.light ?? false;
  @override
  bool updateShouldNotify(LightMode old) => old.light != light;
}

/// Wraps the whole app: applies the filter in light mode.
class ThemeSwitch extends StatelessWidget {
  const ThemeSwitch({super.key, required this.setting, required this.child});

  /// 'dark', 'light' or 'system'.
  final String setting;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final light = setting == 'light' || (setting == 'system' && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    return LightMode(light: light, child: light ? ColorFiltered(colorFilter: lightFilter, child: child) : child);
  }
}

/// Cancels the light filter for photos and other content that must keep its colours.
class Unfilter extends StatelessWidget {
  const Unfilter({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LightMode.of(context) ? ColorFiltered(colorFilter: lightFilter, child: child) : child;
}
