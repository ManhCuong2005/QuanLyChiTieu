/// Browser camera paths are blob URLs. Keep the original image on Web because
/// the native temporary-file crop pipeline is unavailable there.
Future<String> cropReceiptImage(String sourcePath) async => sourcePath;
