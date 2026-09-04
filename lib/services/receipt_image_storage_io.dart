import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Copies a camera temporary file into the application's documents directory.
Future<String?> cacheReceiptImage(String? sourcePath, String expenseId) async {
  if (sourcePath == null || sourcePath.isEmpty) return null;

  final source = File(sourcePath);
  if (!await source.exists()) return null;

  final documents = await getApplicationDocumentsDirectory();
  final receiptDirectory = Directory(
    '${documents.path}${Platform.pathSeparator}receipt_thumbnails',
  );
  await receiptDirectory.create(recursive: true);

  final dot = sourcePath.lastIndexOf('.');
  final extension = dot >= 0 ? sourcePath.substring(dot).toLowerCase() : '.jpg';
  final destination = File(
    '${receiptDirectory.path}${Platform.pathSeparator}$expenseId$extension',
  );
  await source.copy(destination.path);
  return destination.path;
}

Future<void> deleteReceiptImage(String? imagePath) async {
  if (imagePath == null || imagePath.isEmpty) return;
  final file = File(imagePath);
  if (await file.exists()) await file.delete();
}
