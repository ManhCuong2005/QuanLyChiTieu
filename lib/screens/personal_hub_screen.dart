import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'personal_screen.dart';

class PersonalHubScreen extends StatelessWidget {
  final DatabaseService databaseService;
  const PersonalHubScreen({super.key, required this.databaseService});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
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
            padding: const EdgeInsets.all(16),
            children: [
              _MenuCard(
                icon: Icons.qr_code_2_rounded,
                color: const Color(0xFF6366F1),
                title: 'Mã QR chuyển khoản',
                subtitle:
                    databaseService.qrImageBase64 == null
                        ? 'Chưa có ảnh QR · Nhấn để thêm'
                        : 'Xem hoặc thay đổi ảnh QR của bạn',
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => PersonalScreen(
                              databaseService: databaseService,
                              showTasks: false,
                            ),
                      ),
                    ),
              ),
              const SizedBox(height: 12),
              _MenuCard(
                icon: Icons.event_note_rounded,
                color: const Color(0xFF10B981),
                title: 'Việc cần làm',
                subtitle:
                    databaseService.personalTasks.isEmpty
                        ? 'Chưa có công việc · Nhấn để thêm'
                        : '${databaseService.personalTasks.length} công việc trong lịch',
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => PersonalScreen(
                              databaseService: databaseService,
                              showQr: false,
                            ),
                      ),
                    ),
              ),
            ],
          ),
        ),
  );
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _MenuCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}
