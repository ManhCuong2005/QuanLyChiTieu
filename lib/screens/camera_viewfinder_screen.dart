import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
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

  // Camera state
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isCameraError = false;
  String _cameraErrorMsg = '';
  int _selectedCameraIndex = 0;

  // Camera settings state
  FlashMode _flashMode = FlashMode.off;
  Offset? _focusPoint;
  bool _showFocusRing = false;
  bool _isCapturing = false;

  static const List<FlashMode> _flashModes = [
    FlashMode.off,
    FlashMode.torch,
    FlashMode.auto,
  ];
  static const List<IconData> _flashIcons = [
    Icons.flash_off_rounded,
    Icons.flash_on_rounded,
    Icons.flash_auto_rounded,
  ];
  static const List<String> _flashLabels = ['Tắt', 'Bật', 'Tự động'];

  @override
  void initState() {
    super.initState();
    _scanLaserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    if (!kIsWeb) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _isCameraError = true;
          _cameraErrorMsg = 'Không tìm thấy camera trên thiết bị này.';
        });
        return;
      }
      await _startCamera(_selectedCameraIndex);
    } catch (e) {
      setState(() {
        _isCameraError = true;
        _cameraErrorMsg = 'Không thể khởi động camera: $e';
      });
    }
  }

  Future<void> _startCamera(int index) async {
    final oldController = _cameraController;
    if (oldController != null) {
      setState(() => _isCameraInitialized = false);
      await oldController.dispose();
    }

    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _cameraController = controller;

    try {
      await controller.initialize();
      await controller.setFlashMode(_flashMode);
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isCameraError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraError = true;
          _cameraErrorMsg = 'Lỗi khởi tạo camera: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _scanLaserController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _onTapToFocus(TapDownDetails details) async {
    setState(() {
      _focusPoint = details.localPosition;
      _showFocusRing = true;
    });

    if (_cameraController != null && _isCameraInitialized) {
      try {
        // Convert tap position to offset (0.0–1.0)
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final size = renderBox.size;
          final offset = Offset(
            details.localPosition.dx / size.width,
            details.localPosition.dy / size.height,
          );
          await _cameraController!.setFocusPoint(offset);
          await _cameraController!.setExposurePoint(offset);
        }
      } catch (_) {}
    }

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showFocusRing = false);
    });
  }

  Future<void> _toggleFlash() async {
    final currentIndex = _flashModes.indexOf(_flashMode);
    final nextMode = _flashModes[(currentIndex + 1) % _flashModes.length];
    setState(() => _flashMode = nextMode);

    if (_cameraController != null && _isCameraInitialized) {
      try {
        await _cameraController!.setFlashMode(nextMode);
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đèn flash: ${_flashLabels[_flashModes.indexOf(nextMode)]}'),
          duration: const Duration(milliseconds: 800),
          backgroundColor: const Color(0xFF374151),
        ),
      );
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _startCamera(_selectedCameraIndex);
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;

    // --- Mobile: use live CameraController ---
    if (!kIsWeb && _cameraController != null && _isCameraInitialized) {
      setState(() => _isCapturing = true);
      try {
        final file = await _cameraController!.takePicture();
        if (mounted) {
          _navigateToReview(imagePath: file.path);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi chụp ảnh: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isCapturing = false);
      }
      return;
    }

    // --- Web or camera unavailable: open image picker ---
    setState(() => _isCapturing = true);
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (image != null && mounted) {
        _navigateToReview(imagePath: image.path);
      }
    } catch (e) {
      // Camera truly not available — fall back to gallery
      if (mounted) _pickFromGallery();
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (image != null && mounted) {
        _navigateToReview(imagePath: image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể mở thư viện ảnh: $e')),
        );
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

  /// Only show sample receipts when user explicitly taps the demo button
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
                  'Hóa đơn mẫu thực tế (Demo)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Chọn để thử nghiệm bóc tách OCR mà không cần chụp ảnh:',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
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
                subtitle: Text('Hóa đơn ${sample['store']}'),
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Camera Preview ──────────────────────────────────────
          _buildCameraPreview(),

          // ── 2. Framing Crop Overlay ────────────────────────────────
          LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final frameW = min(w * 0.85, 360.0);
            final frameH = min(h * 0.58, 480.0);
            final frameRect = Rect.fromCenter(
              center: Offset(w / 2, h * 0.44),
              width: frameW,
              height: frameH,
            );
            return Stack(children: [
              // Dark vignette
              CustomPaint(
                size: Size(w, h),
                painter: _ViewfinderOverlayPainter(frameRect: frameRect),
              ),
              // Scan laser
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
              // Corner brackets
              Positioned.fromRect(
                rect: frameRect,
                child: CustomPaint(
                  painter: _CornerBracketsPainter(color: const Color(0xFF6366F1)),
                ),
              ),
              // Instruction label
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
                          style: TextStyle(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ]);
          }),

          // ── 3. Tap-to-Focus overlay ────────────────────────────────
          if (!kIsWeb)
            Positioned.fill(
              child: GestureDetector(
                onTapDown: _onTapToFocus,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
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

          // ── 4. Top Controls ────────────────────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Close
                    _iconBtn(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    // Title
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Quét Hóa Đơn',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    // Flash toggle (only on mobile with camera)
                    if (!kIsWeb && _isCameraInitialized)
                      _iconBtn(
                        icon: _flashIcons[_flashModes.indexOf(_flashMode)],
                        onTap: _toggleFlash,
                      )
                    else
                      const SizedBox(width: 44),
                  ],
                ),
              ),
            ),
          ),

          // ── 5. Bottom Controls ─────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32, left: 32, right: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Web notice
                    if (kIsWeb)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '🌐 Web: Chọn ảnh từ thư viện hoặc dùng hóa đơn mẫu bên dưới',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Gallery button
                        Column(
                          children: [
                            _iconBtn(
                              icon: Icons.photo_library_rounded,
                              size: 48,
                              onTap: _pickFromGallery,
                            ),
                            const SizedBox(height: 6),
                            const Text('Thư viện',
                                style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),

                        // Shutter button
                        GestureDetector(
                          onTap: _capturePhoto,
                          child: Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFF6366F1), width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: _isCapturing
                                ? const Padding(
                                    padding: EdgeInsets.all(18),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Color(0xFF6366F1),
                                    ),
                                  )
                                : const Icon(Icons.camera_rounded,
                                    size: 38, color: Color(0xFF6366F1)),
                          ),
                        ),

                        // Switch camera / Demo button
                        Column(
                          children: [
                            if (!kIsWeb && _cameras.length >= 2)
                              _iconBtn(
                                icon: Icons.flip_camera_android_rounded,
                                size: 48,
                                onTap: _switchCamera,
                              )
                            else
                              _iconBtn(
                                icon: Icons.receipt_long_rounded,
                                size: 48,
                                onTap: _showSampleReceiptsDialog,
                              ),
                            const SizedBox(height: 6),
                            Text(
                              (!kIsWeb && _cameras.length >= 2) ? 'Đổi camera' : 'Hóa đơn mẫu',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildCameraPreview() {
    // Web: show instruction background
    if (kIsWeb) {
      return Container(
        color: const Color(0xFF111827),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_outlined,
                  size: 72, color: Colors.white.withValues(alpha: 0.15)),
              const SizedBox(height: 16),
              Text(
                'Chụp ảnh hóa đơn từ điện thoại\nhoặc chọn ảnh từ thư viện',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Mobile: camera not initialized
    if (!_isCameraInitialized || _cameraController == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: _isCameraError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.no_photography_rounded,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _cameraErrorMsg,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _initCamera,
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      label: const Text('Thử lại', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                )
              : const CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    // Mobile: show live CameraPreview
    return GestureDetector(
      onTapDown: _onTapToFocus,
      child: CameraPreview(_cameraController!),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required VoidCallback onTap,
    double size = 44,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINTERS
// ─────────────────────────────────────────────────────────────────────────────

class _ViewfinderOverlayPainter extends CustomPainter {
  final Rect frameRect;
  const _ViewfinderOverlayPainter({required this.frameRect});

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Offset.zero & size;
    final inner = RRect.fromRectAndRadius(frameRect, const Radius.circular(12));

    final path = Path()
      ..addRect(outer)
      ..addRRect(inner)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );
  }

  @override
  bool shouldRepaint(_ViewfinderOverlayPainter old) => old.frameRect != frameRect;
}

class _CornerBracketsPainter extends CustomPainter {
  final Color color;
  const _CornerBracketsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const len = 28.0;
    const thick = 3.5;
    final paint = Paint()
      ..color = color
      ..strokeWidth = thick
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final corners = [
      // top-left
      [Offset(0, len), Offset.zero, Offset(len, 0)],
      // top-right
      [Offset(size.width - len, 0), Offset(size.width, 0), Offset(size.width, len)],
      // bottom-left
      [Offset(0, size.height - len), Offset(0, size.height), Offset(len, size.height)],
      // bottom-right
      [
        Offset(size.width - len, size.height),
        Offset(size.width, size.height),
        Offset(size.width, size.height - len)
      ],
    ];

    for (final pts in corners) {
      final path = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_CornerBracketsPainter old) => old.color != color;
}
