import 'dart:io';

import 'package:challenger_timer/brand.dart';
import 'package:challenger_timer/core/backup.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  test('the name and slogan are the ones in the brief', () {
    expect(appName, 'Productivity Go');
    expect(appSlogan, 'Start in 2 minutes. Stay for the streak.');
  });

  test('backups carry the new name and old backups still load', () async {
    final r = Rig();
    await r.session();
    final text = r.app.exportJson();
    expect(text, contains('"app": "Productivity Go"'));
    expect(decodeBackup(text).events, isNotEmpty);
    const old = '{"app":"Productivity Challenger Timer","exportedAt":1,"settings":{},"events":[],"records":[]}';
    expect(decodeBackup(old).format, 1);
    expect(() => decodeBackup('{"app":"Other","events":[],"records":[]}'), throwsA(predicate((e) => '$e'.contains('Productivity Go'))));
  });

  test('the manifest label, notification icon and launcher icons are the new brand', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:label="Productivity Go"'));
    expect(manifest, contains('productivitygo'));
    expect(manifest, contains('challengertimer'), reason: 'the old NFC link keeps working');
    for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      for (final f in ['ic_launcher', 'ic_launcher_foreground', 'ic_launcher_monochrome']) {
        expect(File('android/app/src/main/res/mipmap-$d/$f.png').existsSync(), isTrue, reason: '$d/$f');
      }
    }
    final adaptive = File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync();
    expect(adaptive, allOf(contains('monochrome'), contains('ic_launcher_foreground'), contains('ic_launcher_background')));
    expect(File('android/app/src/main/res/values/colors.xml').readAsStringSync(), contains('#0F2A52'));
    expect(File('android/app/src/main/res/drawable/ic_stat.xml').readAsStringSync(), contains('M256,106 A150,150'));
    for (final f in ['logo.svg', 'logo_foreground.svg', 'logo_mono.svg', 'playstore_512.png', 'logo_1024.png']) {
      expect(File('brand/$f').existsSync(), isTrue, reason: f);
    }
  });

  test('no user-visible trace of the old name in code, assets or docs a user reads', () {
    final bad = RegExp(r'challenger timer|goget|startline', caseSensitive: false);
    // "Productivity Challenger Timer" survives only as the legacy backup name.
    final allowed = {'lib/brand.dart', 'lib/core/backup.dart'};
    for (final dir in ['lib', 'android/app/src/main/res', 'android/app/src/main/AndroidManifest.xml', 'assets', 'README.md']) {
      final ents = FileSystemEntity.isDirectorySync(dir) ? Directory(dir).listSync(recursive: true).whereType<File>() : [File(dir)];
      for (final f in ents) {
        if (allowed.contains(f.path) || !RegExp(r'\.(dart|xml|json|md)$').hasMatch(f.path)) continue;
        final text = f.readAsStringSync();
        expect(bad.hasMatch(text), isFalse, reason: 'old name in ${f.path}');
      }
    }
  });
}
