import 'dart:io';

import 'package:image/image.dart' as image;
import 'package:path_provider/path_provider.dart';

/// Applies the same central framing used by the camera overlay to a captured
/// receipt, reducing background noise before ML Kit runs.
Future<String> cropReceiptImage(String sourcePath) async {
  final source = File(sourcePath);
  final bytes = await source.readAsBytes();
  final decoded = image.decodeImage(bytes);
  if (decoded == null) return sourcePath;

  final normalized = image.bakeOrientation(decoded);
  final x = (normalized.width * 0.075).round();
  final y = (normalized.height * 0.14).round();
  final width = (normalized.width * 0.85).round();
  final height = (normalized.height * 0.64).round();
  final cropped = image.copyCrop(
    normalized,
    x: x.clamp(0, normalized.width - 1),
    y: y.clamp(0, normalized.height - 1),
    width: width.clamp(1, normalized.width - x),
    height: height.clamp(1, normalized.height - y),
  );

  final temporaryDirectory = await getTemporaryDirectory();
  final destination = File(
    '${temporaryDirectory.path}${Platform.pathSeparator}receipt_crop_${DateTime.now().microsecondsSinceEpoch}.jpg',
  );
  await destination.writeAsBytes(image.encodeJpg(cropped, quality: 92));
  return destination.path;
}
