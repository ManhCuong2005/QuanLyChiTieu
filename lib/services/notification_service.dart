import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/personal_task.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _initialized = true;
  }

  List<int> _ids(String taskId) {
    final base = taskId.hashCode.abs() % 700000000;
    return [base * 3, base * 3 + 1, base * 3 + 2];
  }

  Future<void> scheduleTask(PersonalTask task) async {
    if (kIsWeb) return;
    await init();
    await cancelTask(task.id);
    if (task.isCompleted) return;
    final now = DateTime.now();
    final reminders = <({Duration before, String label})>[
      (before: const Duration(days: 1), label: 'còn 1 ngày'),
      (before: const Duration(hours: 12), label: 'còn 12 giờ'),
      (before: const Duration(hours: 1), label: 'còn 1 giờ'),
    ];
    final ids = _ids(task.id);
    for (var index = 0; index < reminders.length; index++) {
      final when = task.dueDate.subtract(reminders[index].before);
      if (!when.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        ids[index],
        'Sắp đến hạn: ${task.title}',
        '${reminders[index].label} để thực hiện công việc.',
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'personal_tasks',
            'Nhắc việc cá nhân',
            channelDescription: 'Thông báo trước hạn cho lịch cá nhân',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelTask(String taskId) async {
    if (kIsWeb) return;
    for (final id in _ids(taskId)) {
      await _plugin.cancel(id);
    }
  }
}
