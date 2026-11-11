/// Everything that would need a server, an account or an API key sits behind
/// this interface. The app ships with [LocalBackend], which is honest about
/// not being connected: it never invents people, numbers or results.
/// BACKEND.md lists what a real implementation needs.
library;

class BackendUnavailable implements Exception {
  const BackendUnavailable(this.feature);
  final String feature;
  @override
  String toString() => '$feature needs a server that is not set up yet.';
}

abstract class Backend {
  /// False until a real server implementation is plugged in.
  bool get connected;

  /// 131, 383: commit links pushed by [user] on the given local date.
  Future<List<String>> githubCommits(String user, DateTime date);

  /// 479, 146: upload the JSON export. Returns the time of the backup.
  Future<DateTime> backup(String json);

  /// 478: sign in and return a display name.
  Future<String> signIn();
}

class LocalBackend implements Backend {
  const LocalBackend();
  @override
  bool get connected => false;
  @override
  Future<List<String>> githubCommits(String user, DateTime date) async => throw const BackendUnavailable('GitHub sync');
  @override
  Future<DateTime> backup(String json) async => throw const BackendUnavailable('Cloud backup');
  @override
  Future<String> signIn() async => throw const BackendUnavailable('Google login');
}
