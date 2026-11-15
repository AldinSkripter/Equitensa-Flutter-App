import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a server-generated file (PDF, XML, ZIP) to the OS share sheet / "save to files".
Future<void> shareBytes(Uint8List bytes, String filename, String mime) async {
  final XFile file;
  if (kIsWeb) {
    file = XFile.fromData(bytes, mimeType: mime, name: filename);
  } else {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$filename');
    await f.writeAsBytes(bytes, flush: true);
    file = XFile(f.path, mimeType: mime, name: filename);
  }
  await SharePlus.instance.share(ShareParams(files: [file], subject: filename));
}
