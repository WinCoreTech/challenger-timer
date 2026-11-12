import 'package:flutter/services.dart';

/// Everything that needs Android. The Kotlin side lives in
/// android/app/src/main/kotlin. Tests use [FakeNative].
abstract class Native {
  /// Pushes the state the alarms, blocker and buddy report need while the
  /// Flutter side is not running, and (re)schedules all alarms.
  Future<void> sync(Map<String, Object?> state);
  Future<void> startTimer(int endMs, String title);
  Future<void> stopTimer();

  /// A start requested from a notification, alarm screen or block overlay.
  Future<Map<String, Object?>?> takeLaunchAction();
  Future<bool> requestPermission(String name);
  Future<Map<String, bool>> status();
  Future<void> openSettings(String which);
  Future<List<Map<String, String>>> listApps();
  Future<bool> sendSms(String phone, String text);
  Future<void> tone();

  Future<void> openUrl(String url);

  /// Voice note recording (max 20 s) to [path]; false if not permitted.
  Future<bool> recStart(String path);
  Future<void> recStop();
  Future<void> play(String path);

  /// Do Not Disturb on or off (needs notification-policy access).
  Future<void> dnd(bool on);

  /// Today's phone usage: {granted, pickups, total, apps: [{label, minutes}]}.
  Future<Map<String, Object?>> usage();
  Future<void> faceDown(bool on);

  /// Keeps the screen awake (hard mode).
  Future<void> keepScreenOn(bool on);

  /// True if the screen was on when the app last went to the background.
  Future<bool> leftWithScreenOn();

  /// Generated background noise: 'brown', 'rain', 'white', or '' to stop.
  Future<void> noise(String kind);

  /// Speech to text through the phone's recogniser. Null if nothing was heard.
  Future<String?> listen();

  /// Short vibration: light on start, heavy on completion.
  void haptic({bool heavy = false});
  set onAction(void Function() callback);
}

class ChannelNative implements Native {
  ChannelNative() {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'action') _onAction?.call();
    });
  }
  static const _ch = MethodChannel('pct/native');
  void Function()? _onAction;

  @override
  set onAction(void Function() callback) => _onAction = callback;

  Future<T?> _call<T>(String m, [Object? args]) async {
    try {
      return await _ch.invokeMethod<T>(m, args);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> sync(Map<String, Object?> state) => _call<void>('sync', state);
  @override
  Future<void> startTimer(int endMs, String title) =>
      _call<void>('startTimer', {'endMs': endMs, 'title': title});
  @override
  Future<void> stopTimer() => _call<void>('stopTimer');
  @override
  Future<Map<String, Object?>?> takeLaunchAction() async =>
      (await _call<Map>('takeLaunchAction'))?.cast<String, Object?>();
  @override
  Future<bool> requestPermission(String name) async =>
      await _call<bool>('requestPermission', name) ?? false;
  @override
  Future<Map<String, bool>> status() async =>
      (await _call<Map>('status'))?.cast<String, bool>() ?? const {};
  @override
  Future<void> openSettings(String which) => _call<void>('openSettings', which);
  @override
  Future<List<Map<String, String>>> listApps() async => [
        for (final a in await _call<List>('listApps') ?? const []) (a as Map).cast<String, String>()
      ];
  @override
  Future<bool> sendSms(String phone, String text) async =>
      await _call<bool>('sendSms', {'phone': phone, 'text': text}) ?? false;
  @override
  Future<void> tone() => _call<void>('tone');
  @override
  Future<void> openUrl(String url) => _call<void>('openUrl', url);
  @override
  Future<bool> recStart(String path) async => await _call<bool>('recStart', path) ?? false;
  @override
  Future<void> recStop() => _call<void>('recStop');
  @override
  Future<void> play(String path) => _call<void>('play', path);
  @override
  Future<void> dnd(bool on) => _call<void>('dnd', on);
  @override
  Future<Map<String, Object?>> usage() async => (await _call<Map>('usage'))?.cast<String, Object?>() ?? const {'granted': false};
  @override
  Future<void> faceDown(bool on) => _call<void>('faceDown', on);
  @override
  Future<void> keepScreenOn(bool on) => _call<void>('keepScreenOn', on);
  @override
  Future<bool> leftWithScreenOn() async => await _call<bool>('leftWithScreenOn') ?? true;
  @override
  Future<void> noise(String kind) => _call<void>('noise', kind);
  @override
  Future<String?> listen() => _call<String>('listen');
  @override
  void haptic({bool heavy = false}) =>
      heavy ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
}

class FakeNative implements Native {
  final List<String> calls = [];
  Map<String, Object?> lastSync = const {};
  Map<String, bool> permissions = {};
  Map<String, Object?>? launchAction;
  final List<String> sms = [];
  void Function()? action;

  @override
  set onAction(void Function() callback) => action = callback;
  @override
  Future<void> sync(Map<String, Object?> state) async {
    calls.add('sync');
    lastSync = state;
  }

  @override
  Future<void> startTimer(int endMs, String title) async => calls.add('startTimer:$endMs');
  @override
  Future<void> stopTimer() async => calls.add('stopTimer');
  @override
  Future<Map<String, Object?>?> takeLaunchAction() async {
    final a = launchAction;
    launchAction = null;
    return a;
  }

  @override
  Future<bool> requestPermission(String name) async {
    calls.add('request:$name');
    return permissions[name] ?? false;
  }

  @override
  Future<Map<String, bool>> status() async => permissions;
  @override
  Future<void> openSettings(String which) async => calls.add('settings:$which');
  @override
  Future<List<Map<String, String>>> listApps() async => const [
        {'package': 'com.example.reels', 'label': 'Reels'},
        {'package': 'com.example.game', 'label': 'Game'}
      ];
  @override
  Future<bool> sendSms(String phone, String text) async {
    if (permissions['sms'] != true) return false;
    sms.add('$phone|$text');
    return true;
  }

  @override
  Future<void> tone() async => calls.add('tone');
  String? heard;
  bool screenOnAtPause = true;
  @override
  Future<void> openUrl(String url) async => calls.add('url:$url');
  @override
  Future<bool> recStart(String path) async {
    calls.add('rec:$path');
    return permissions['mic'] == true;
  }

  @override
  Future<void> recStop() async => calls.add('recStop');
  @override
  Future<void> play(String path) async => calls.add('play:$path');
  Map<String, Object?> usageData = const {'granted': false};
  @override
  Future<void> dnd(bool on) async => calls.add('dnd:$on');
  @override
  Future<Map<String, Object?>> usage() async => usageData;
  @override
  Future<void> faceDown(bool on) async => calls.add('faceDown:$on');
  @override
  Future<void> keepScreenOn(bool on) async => calls.add('keepOn:$on');
  @override
  Future<bool> leftWithScreenOn() async => screenOnAtPause;
  @override
  Future<void> noise(String kind) async => calls.add('noise:$kind');
  @override
  Future<String?> listen() async => heard;
  @override
  void haptic({bool heavy = false}) => calls.add(heavy ? 'haptic:heavy' : 'haptic');
}
