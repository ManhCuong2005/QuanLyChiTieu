/// Browser captures are represented by temporary blob URLs. Do not persist an
/// invalid URL with the expense after OCR has completed.
Future<String?> cacheReceiptImage(String? sourcePath, String expenseId) async {
  return null;
}

Future<void> deleteReceiptImage(String? imagePath) async {}
