import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the Android share sheet. Swapped out in tests.
final shareProvider = Provider<Future<void> Function({String? text, String? filePath})>(
    (ref) => ({String? text, String? filePath}) async {
          await SharePlus.instance
              .share(ShareParams(text: text, files: filePath == null ? null : [XFile(filePath)]));
        });

