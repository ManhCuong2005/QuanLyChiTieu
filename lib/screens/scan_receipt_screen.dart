import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../models/receipt_result.dart';
import '../services/ocr_service.dart';
import '../services/database_service.dart';
import '../services/receipt_image_storage.dart';

class ScanReceiptScreen extends StatefulWidget {
  final DatabaseService databaseService;
  final String? initialImagePath;
  final String? initialSampleText;

  const ScanReceiptScreen({
    super.key,
    required this.databaseService,
    this.initialImagePath,
    this.initialSampleText,
  });

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  ExpenseCategory _selectedCategory = ExpenseCategory.other;

  bool _isProcessing = false;
  ReceiptResult? _parsedResult;
  String? _pickedImagePath;
  bool _showRawText = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialImagePath != null) {
        _processInitialPath(widget.initialImagePath!);
      } else if (widget.initialSampleText != null) {
        _processSampleText(widget.initialSampleText!);
      }
    });
  }

  Future<void> _processInitialPath(String path) async {
    setState(() {
      _isProcessing = true;
      _pickedImagePath = path;
    });
    try {
      final result = await OcrService.processReceiptFromPath(path);
      if (mounted) _applyParsedResult(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi nhận diện hóa đơn: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _processSampleText(String text) {
    setState(() {
      _isProcessing = true;
    });
    final result = OcrService.processReceiptText(text);
    _applyParsedResult(result);
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (image == null) return;

      setState(() {
        _isProcessing = true;
        _pickedImagePath = image.path;
      });

      final result = await OcrService.processReceiptFromPath(image.path);
      _applyParsedResult(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi xử lý ảnh: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _processSampleReceipt(Map<String, String> sample) {
    setState(() {
      _isProcessing = true;
      _pickedImagePath = null;
    });

    final text = sample['text']!;
    final result = OcrService.processReceiptText(text);
    _applyParsedResult(result);

    setState(() {
      _isProcessing = false;
    });
  }

  void _applyParsedResult(ReceiptResult result) {
    setState(() {
      _parsedResult = result;

      // Fill in extracted fields
      if (result.merchantName != null && result.merchantName!.isNotEmpty) {
        _merchantController.text = result.merchantName!;
        _titleController.text = result.merchantName!;
      } else {
        _titleController.text = 'Chi tiêu hóa đơn';
      }

      if (result.totalAmount != null) {
        _amountController.text = result.totalAmount!.toStringAsFixed(0);
      }

      if (result.transactionDate != null) {
        _selectedDate = result.transactionDate!;
      }

      if (result.suggestedCategory != null) {
        _selectedCategory = ExpenseCategory.fromId(result.suggestedCategory!);
      }
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final amount =
        double.tryParse(
          _amountController.text.replaceAll(RegExp(r'[^0-9.]'), ''),
        ) ??
        0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')),
      );
      return;
    }

    final expenseId = const Uuid().v4();
    String? cachedImagePath = _pickedImagePath;
    try {
      cachedImagePath = await cacheReceiptImage(_pickedImagePath, expenseId);
    } catch (e) {
      debugPrint('Could not cache receipt image: $e');
    }

    final newExpense = Expense(
      id: expenseId,
      title:
          _titleController.text.trim().isEmpty
              ? _merchantController.text
              : _titleController.text.trim(),
      amount: amount,
      category: _selectedCategory,
      date: _selectedDate,
      merchant: _merchantController.text.trim(),
      note: _noteController.text.trim(),
      receiptImagePath: cachedImagePath,
      rawOcrText: _parsedResult?.rawText,
      isOcrScanned: true,
    );

    await widget.databaseService.addExpense(newExpense);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã lưu khoản chi tiêu vào sổ thành công!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét Hóa Đơn (OCR)'),
        actions: [
          if (_parsedResult != null)
            TextButton.icon(
              onPressed: _saveExpense,
              icon: const Icon(Icons.check_rounded, color: Colors.white),
              label: const Text(
                'Lưu',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Action Buttons Card
            Card(
              elevation: 0,
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.document_scanner_rounded,
                          color: Color(0xFF3B82F6),
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Google ML Kit OCR & Regex Parser',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tự động bóc tách: Tổng tiền, Ngày giờ, Tên nơi bán',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _isProcessing
                                    ? null
                                    : () => _pickAndProcessImage(
                                      ImageSource.camera,
                                    ),
                            icon: const Icon(Icons.camera_alt_rounded),
                            label: const Text('Chụp ảnh'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _isProcessing
                                    ? null
                                    : () => _pickAndProcessImage(
                                      ImageSource.gallery,
                                    ),
                            icon: const Icon(Icons.photo_library_rounded),
                            label: const Text('Chọn từ máy'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Sample Receipts Section for Live Demo & Testing
            ExpansionTile(
              initiallyExpanded: _parsedResult == null,
              leading: const Icon(
                Icons.receipt_long_rounded,
                color: Color(0xFF8B5CF6),
              ),
              title: const Text(
                'Thử nghiệm hóa đơn mẫu (Live Demo)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: const Text(
                'Bấm vào để thử nghiệm ngay không cần giấy hóa đơn',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        OcrService.sampleReceipts.map((sample) {
                          return ActionChip(
                            avatar: const Icon(
                              Icons.bolt_rounded,
                              size: 16,
                              color: Color(0xFF8B5CF6),
                            ),
                            label: Text(sample['title']!),
                            onPressed:
                                _isProcessing
                                    ? null
                                    : () => _processSampleReceipt(sample),
                            backgroundColor: const Color(
                              0xFF8B5CF6,
                            ).withValues(alpha: 0.08),
                            side: BorderSide(
                              color: const Color(
                                0xFF8B5CF6,
                              ).withValues(alpha: 0.3),
                            ),
                          );
                        }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),

            const SizedBox(height: 14),

            // Loading Indicator
            if (_isProcessing) ...[
              const SizedBox(height: 24),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'Đang nhận diện ký tự (OCR) & Bóc tách Regex...',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Parsed Result Review & Form
            if (_parsedResult != null) ...[
              // Confidence Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Đã phân tích hóa đơn thành công! (Độ tin cậy: ${(_parsedResult!.confidenceScore * 100).toStringAsFixed(0)}%)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF047857),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Monetary Total
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Tổng số tiền (VNĐ) *',
                        prefixIcon: const Icon(Icons.attach_money_rounded),
                        suffixText: 'VNĐ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập số tiền';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // Merchant Name
                    TextFormField(
                      controller: _merchantController,
                      decoration: InputDecoration(
                        labelText: 'Tên nơi bán / Cửa hàng',
                        prefixIcon: const Icon(Icons.storefront_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Tiêu đề chi tiêu *',
                        prefixIcon: const Icon(Icons.title_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập tiêu đề';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // Date & Time Picker
                    InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Ngày giao dịch',
                          prefixIcon: const Icon(Icons.calendar_today_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        child: Text(
                          dateFormatter.format(_selectedDate),
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Category Selector Chips
                    const Text(
                      'Danh mục chi tiêu:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          ExpenseCategory.defaultCategories.map((cat) {
                            final isSelected = _selectedCategory.id == cat.id;
                            return ChoiceChip(
                              avatar: Icon(
                                cat.icon,
                                size: 16,
                                color: isSelected ? Colors.white : cat.color,
                              ),
                              label: Text(cat.name),
                              selected: isSelected,
                              selectedColor: cat.color,
                              labelStyle: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedCategory = cat;
                                  });
                                }
                              },
                            );
                          }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Note
                    TextFormField(
                      controller: _noteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Ghi chú thêm',
                        prefixIcon: const Icon(Icons.note_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Raw OCR Inspection (For Grading / Verification)
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showRawText = !_showRawText;
                        });
                      },
                      icon: Icon(
                        _showRawText
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                      label: Text(
                        _showRawText
                            ? 'Ẩn văn bản thô OCR'
                            : 'Xem chi tiết văn bản thô OCR',
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    if (_showRawText) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: SelectableText(
                          _parsedResult!.rawText,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _saveExpense,
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text(
                          'LƯU VÀO SỔ CHI TIÊU',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
