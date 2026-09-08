import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/personal_task.dart';
import '../services/database_service.dart';

class PersonalScreen extends StatelessWidget {
  final DatabaseService databaseService;
  final bool showQr;
  final bool showTasks;
  const PersonalScreen({
    super.key,
    required this.databaseService,
    this.showQr = true,
    this.showTasks = true,
  });

  Future<void> _chooseQrImage(BuildContext context) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    try {
      final decoded = img.decodeImage(await picked.readAsBytes());
      if (decoded == null) throw const FormatException('Ảnh không hợp lệ');
      final resized =
          decoded.width > 1200 ? img.copyResize(decoded, width: 1200) : decoded;
      await databaseService.setQrImage(
        base64Encode(img.encodeJpg(resized, quality: 88)),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã lưu ảnh mã QR.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể lưu ảnh: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: databaseService,
      builder:
          (context, _) => Scaffold(
            appBar: AppBar(
              title: const Text(
                'Tôi',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              children: [
                if (showQr)
                  _QrCard(
                    imageBase64: databaseService.qrImageBase64,
                    onChoose: () => _chooseQrImage(context),
                  ),
                if (showTasks) const SizedBox(height: 20),
                if (showTasks)
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Lịch cá nhân',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _showTaskForm(context),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Thêm việc'),
                      ),
                    ],
                  ),
                if (showTasks) const SizedBox(height: 10),
                if (showTasks && databaseService.personalTasks.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(
                        child: Text('Chưa có công việc nào trong lịch.'),
                      ),
                    ),
                  )
                else if (showTasks)
                  ...databaseService.personalTasks.map(
                    (task) => _TaskCard(
                      task: task,
                      onMoveToTop:
                          () => databaseService.movePersonalTaskToTop(task.id),
                      onEdit: () => _showTaskForm(context, task: task),
                      onComplete: () => _confirmComplete(context, task),
                      onDelete: () => _confirmDelete(context, task),
                    ),
                  ),
              ],
            ),
          ),
    );
  }

  Future<void> _showTaskForm(BuildContext context, {PersonalTask? task}) async {
    final title = TextEditingController(text: task?.title ?? '');
    final description = TextEditingController(text: task?.description ?? '');
    var dueDate = task?.dueDate ?? DateTime.now().add(const Duration(hours: 1));
    final result = await showDialog<PersonalTask>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(
                    task == null ? 'Thêm việc cần làm' : 'Chỉnh sửa công việc',
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: title,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Tên việc *',
                            prefixIcon: Icon(Icons.task_alt_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_rounded),
                          title: const Text('Ngày cần làm'),
                          subtitle: Text(
                            DateFormat('dd/MM/yyyy').format(dueDate),
                          ),
                          trailing: const Icon(Icons.edit_calendar_rounded),
                          onTap: () async {
                            final value = await showDatePicker(
                              context: context,
                              initialDate: dueDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (value != null) {
                              setDialogState(
                                () =>
                                    dueDate = DateTime(
                                      value.year,
                                      value.month,
                                      value.day,
                                      dueDate.hour,
                                      dueDate.minute,
                                    ),
                              );
                            }
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.schedule_rounded),
                          title: const Text('Giờ thực hiện'),
                          subtitle: Text(DateFormat('HH:mm').format(dueDate)),
                          trailing: const Icon(Icons.more_time_rounded),
                          onTap: () async {
                            final value = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(dueDate),
                            );
                            if (value != null) {
                              setDialogState(
                                () =>
                                    dueDate = DateTime(
                                      dueDate.year,
                                      dueDate.month,
                                      dueDate.day,
                                      value.hour,
                                      value.minute,
                                    ),
                              );
                            }
                          },
                        ),
                        TextField(
                          controller: description,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Mô tả cụ thể (không bắt buộc)',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.notes_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Hủy'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final cleanTitle = title.text.trim();
                        if (cleanTitle.isEmpty) return;
                        Navigator.pop(
                          dialogContext,
                          task == null
                              ? PersonalTask(
                                id:
                                    DateTime.now().microsecondsSinceEpoch
                                        .toString(),
                                title: cleanTitle,
                                description: description.text.trim(),
                                createdAt: DateTime.now(),
                                dueDate: dueDate,
                              )
                              : task.copyWith(
                                title: cleanTitle,
                                description: description.text.trim(),
                                dueDate: dueDate,
                              ),
                        );
                      },
                      child: const Text('Lưu'),
                    ),
                  ],
                ),
          ),
    );
    title.dispose();
    description.dispose();
    if (result == null) return;
    task == null
        ? await databaseService.addPersonalTask(result)
        : await databaseService.updatePersonalTask(result);
  }

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String message,
    String action, {
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: Text(title),
                content: Text(message),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Hủy'),
                  ),
                  FilledButton(
                    style:
                        destructive
                            ? FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                            )
                            : null,
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(action),
                  ),
                ],
              ),
        ) ??
        false;
  }

  Future<void> _confirmComplete(BuildContext context, PersonalTask task) async {
    if (await _confirm(
      context,
      'Xác nhận hoàn thành',
      'Bạn đã hoàn thành “${task.title}”?',
      'Hoàn thành',
    )) {
      await databaseService.updatePersonalTask(
        task.copyWith(isCompleted: true),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, PersonalTask task) async {
    if (await _confirm(
      context,
      'Xóa công việc?',
      '“${task.title}” sẽ bị xóa và không thể khôi phục.',
      'Xóa',
      destructive: true,
    )) {
      await databaseService.deletePersonalTask(task.id);
    }
  }
}

class _QrCard extends StatelessWidget {
  final String? imageBase64;
  final VoidCallback onChoose;
  const _QrCard({required this.imageBase64, required this.onChoose});

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    try {
      if (imageBase64 != null) bytes = base64Decode(imageBase64!);
    } catch (_) {}
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.qr_code_2_rounded, color: Color(0xFF6366F1)),
                SizedBox(width: 8),
                Text(
                  'Mã QR chuyển khoản',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (bytes == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.image_outlined,
                      size: 54,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 10),
                    const Text('Bạn chưa có ảnh mã QR'),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: onChoose,
                      icon: const Icon(Icons.upload_rounded),
                      label: const Text('Chọn ảnh QR'),
                    ),
                  ],
                ),
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onChoose,
                icon: const Icon(Icons.change_circle_outlined, size: 18),
                label: const Text(
                  'Thay đổi ảnh',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final PersonalTask task;
  final VoidCallback onMoveToTop, onEdit, onComplete, onDelete;
  const _TaskCard({
    required this.task,
    required this.onMoveToTop,
    required this.onEdit,
    required this.onComplete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd/MM/yyyy');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      decoration:
                          task.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (!task.isCompleted)
                  IconButton(
                    tooltip: 'Đưa lên đầu',
                    onPressed: onMoveToTop,
                    icon: const Icon(Icons.vertical_align_top_rounded),
                  ),
              ],
            ),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _DateLabel(
                  icon: Icons.add_circle_outline,
                  text: 'Thêm: ${format.format(task.createdAt)}',
                ),
                _DateLabel(
                  icon: Icons.event_rounded,
                  text: 'Cần làm: ${format.format(task.dueDate)}',
                ),
              ],
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                task.description,
                style: const TextStyle(color: Color(0xFF475569)),
              ),
            ],
            if (task.isCompleted)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Chip(
                  avatar: Icon(Icons.check_circle_rounded, size: 18),
                  label: Text('Đã hoàn thành'),
                ),
              ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!task.isCompleted)
                  TextButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Hoàn thành'),
                  ),
                IconButton(
                  tooltip: 'Chỉnh sửa',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Xóa',
                  onPressed: onDelete,
                  color: Colors.red,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DateLabel({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: Colors.grey),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    ],
  );
}
