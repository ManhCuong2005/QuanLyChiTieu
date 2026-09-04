import 'dart:io';

import 'package:flutter/material.dart';

class ReceiptImagePreview extends StatelessWidget {
  final String imagePath;

  const ReceiptImagePreview({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) => Image.file(
    File(imagePath),
    fit: BoxFit.cover,
    errorBuilder:
        (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)),
  );
}
