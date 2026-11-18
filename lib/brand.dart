import 'dart:ui';

/// The one place the product name lives. Changing the name is one edit here
/// (plus android:label in the manifests, which cannot read Dart).
const String appName = 'Productivity Go';
const String appSlogan = 'Start in 2 minutes. Stay for the streak.';

/// Brand colours (logo and design system).
const Color brandNavy = Color(0xFF0F2A52);
const Color brandDeepNavy = Color(0xFF091528);
const Color brandOrange = Color(0xFFFF6A1F);
const Color brandAmber = Color(0xFFFFC15A);
const Color brandCream = Color(0xFFFFF1E0);

/// Older builds called the app these. Backups made by them still load.
const List<String> legacyAppNames = ['Productivity Challenger Timer'];
