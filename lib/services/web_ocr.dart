@JS()
library;

import 'dart:js_interop';

@JS('recognizeReceiptImage')
external JSPromise<JSString> _recognizeReceiptImage(JSString imageUrl);

Future<String> recognizeReceiptImage(String imagePath) async {
  final text = await _recognizeReceiptImage(imagePath.toJS).toDart;
  return text.toDart;
}
