import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where the next voice note is written.
final voicePathProvider = Provider<Future<String> Function()>((ref) => () async {
      final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'proof'));
      await dir.create(recursive: true);
      return p.join(dir.path, 'v${DateTime.now().millisecondsSinceEpoch}.m4a');
    });

/// Takes a compressed camera photo and returns the saved file path.
final photoProvider = Provider<Future<String?> Function()>((ref) => () async {
      final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, maxHeight: 1600, imageQuality: 70);
      if (x == null) return null;
      final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'proof'));
      await dir.create(recursive: true);
      final dest = p.join(dir.path, 'p${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(x.path).copy(dest);
      return dest;
    });

