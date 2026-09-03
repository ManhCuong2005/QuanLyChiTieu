import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/database_service.dart';
import '../services/ocr_service.dart';
import 'scan_receipt_screen.dart';

class CameraViewfinderScreen extends StatefulWidget {
  final DatabaseService databaseService;

  const CameraViewfinderScreen({
    super.key,
    required this.databaseService,
  });

  @override
  State<CameraViewfinderScreen> createState() => _CameraViewfinderScreenState();
}

class _CameraViewfinderScreenState extends State<CameraViewfinderScreen>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  late AnimationController _scanLaserController;

  // Camera settings state
  int _flashMode = 0; // 0: Off, 1: On, 2: Auto
  Offset? _focusPoint;
  bool _showFocusRing = false;

  @override
  void initState() {
    super.initState();
    _scanLaserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanLaserController.dispose();
    super.dispose();
  }

  void _onTapToFocus(TapDownDetails details) {
    setState(() {
      _focusPoint = details.localPosition;
      _showFocusRing = true;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _showFocusRing = false;
        });
      }
    });
  }

  void _toggleFlash() {
    setState(() {
      _flashMode = (_flashMode + 1) % 3;
    });
    final messages = ['Đèn flash: Tắt', 'Đèn flash: Bật', 'Đèn flash: Tự động'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(messages[_flashMode]),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  Future<void> _captureFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image != null && mounted) {
        _navigateToReview(imagePath: image.path);
      }
    } catch (e) {
      if (mounted) {
        _showSampleReceiptsDialog();
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image != null && mounted) {
        _navigateToReview(imagePath: image.path);
      }
    } catch (e) {
      if (mounted) {
        _showSampleReceiptsDialog();
      }
    }
  }

  void _navigateToReview({String? imagePath, String? sampleText}) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ScanReceiptScreen(
          databaseService: widget.databaseService,
          initialImagePath: imagePath,
          initialSampleText: sampleText,
        ),
      ),
    );
  }

  void _showSampleReceiptsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: Color(0xFF6366F1)),
                SizedBox(width: 10),
                Text(
                  'Chọn hóa đơn mẫu thực tế',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Dành cho kiểm thử Live Demo / Thiết bị không có camera:',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ...OcrService.sampleReceipts.map((sample) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_rounded, color: Color(0xFF6366F1)),
                ),
                title: Text(sample['title']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Tự động bóc tách hóa đơn ${sample['store']}'),
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateToReview(sampleText: sample['text']);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flashIcons = [Icons.flash_off_rounded, Icons.flash_on_rounded, Icons.flash_auto_rounded];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Viewfinder Background with Tap-to-Focus
          GestureDetector(
            onTapDown: _onTapToFocus,
            child: Container(
              color: const Color(0xFF111827),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Camera Live Viewfinder',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 14,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Framing Crop Overlay with Darkened Cutout
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              final frameWidth = min(width * 0.85, 360.0);
              final frameHeight = min(height * 0.58, 480.0);
              final frameRect = Rect.fromCenter(
                center: Offset(width / 2, height * 0.44),
                width: frameWidth,
                height: frameHeight,
              );

              return Stack(
                children: [
                  // Mask Painter (Dark vignette outside the receipt box)
                  CustomPaint(
                    size: Size(width, height),
                    painter: _ViewfinderOverlayPainter(frameRect: frameRect),
                  ),

                  // Animated Scanning Laser
                  AnimatedBuilder(
                    animation: _scanLaserController,
                    builder: (context, child) {
                      final laserY = frameRect.top + _scanLaserController.value * frameRect.height;
                      return Positioned(
                        left: frameRect.left + 8,
                        top: laserY,
                        width: frameRect.width - 16,
                        height: 2.5,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0xFF6366F1),
                                Color(0xFF60A5FA),
                                Color(0xFF6366F1),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.7),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Framing Corner Brackets
                  Positioned.fromRect(
                    rect: frameRect,
                    child: CustomPaint(
                      painter: _CornerBracketsPainter(
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ),

                  // Instruction Text above the frame
                  Positioned(
                    top: frameRect.top - 42,
                    left: 20,
                    right: 20,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.crop_free_rounded, size: 14, color: Colors.white70),
                            SizedBox(width: 6),
                            Text(
                              'Căn chỉnh hóa đơn vào giữa khung hình',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // 3. Interactive Focus Ring indicator on Tap
          if (_showFocusRing && _focusPoint != null)
            Positioned(
              left: _focusPoint!.dx - 30,
              top: _focusPoint!.dy - 30,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.3, end: 1.0),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFBBF24), width: 1.8),
                      ),
                      child: Center(
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFBBF24),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // 4. Top App Bar Controls (Flash, Close, Info)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Text(
                      'Quét Hóa Đơn OCR',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: Icon(flashIcons[_flashMode], color: _flashMode > 0 ? const Color(0xFFFBBF24) : Colors.white),
                      onPressed: _toggleFlash,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Bottom Controls Bar (Shutter, Gallery, Samples)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Gallery Button
                        IconButton(
                          icon: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 28),
                          tooltip: 'Chọn từ thư viện',
                          onPressed: _pickFromGallery,
                        ),

                        // Big Shutter Button
                        GestureDetector(
                          onTap: _captureFromCamera,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              color: Colors.transparent,
                            ),
                            child: Center(
                              child: Container(
                                width: 62,
                                height: 62,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Sample Receipts Button
                        IconButton(
                          icon: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28),
                          tooltip: 'Hóa đơn mẫu',
                          onPressed: _showSampleReceiptsDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _showSampleReceiptsDialog,
                      icon: const Icon(Icons.bolt_rounded, color: Color(0xFF818CF8), size: 16),
                      label: const Text(
                        'Thử nghiệm hóa đơn mẫu (Highlands, WinMart...)',
                        style: TextStyle(color: Color(0xFF818CF8), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter drawing the darkened vignette surrounding the crop frame
class _ViewfinderOverlayPainter extends CustomPainter {
  final Rect frameRect;

  _ViewfinderOverlayPainter({required this.frameRect});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.62)
      ..style = PaintingStyle.fill;

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(16)));

    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    canvas.drawPath(overlayPath, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderOverlayPainter oldDelegate) {
    return oldDelegate.frameRect != frameRect;
  }
}

/// CustomPainter drawing framing corner brackets
class _CornerBracketsPainter extends CustomPainter {
  final Color color;

  _CornerBracketsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 24.0;

    // Top-Left
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, len), paint);

    // Top-Right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);

    // Bottom-Left
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - len), paint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - len, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - len), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter oldDelegate) => false;
}
