import 'package:flutter/material.dart';
import 'services/database_service.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final databaseService = DatabaseService();
  await databaseService.init();
  await NotificationService.instance.init();
  for (final task in databaseService.personalTasks) {
    await NotificationService.instance.scheduleTask(task);
  }

  runApp(ExpenseTrackerApp(databaseService: databaseService));
}

class ExpenseTrackerApp extends StatelessWidget {
  final DatabaseService databaseService;
  final bool autoCheckForUpdates;

  const ExpenseTrackerApp({
    super.key,
    required this.databaseService,
    this.autoCheckForUpdates = true,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OCR Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1E293B),
          elevation: 0,
          centerTitle: false,
          scrolledUnderElevation: 1,
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
          ),
        ),
      ),
      home: HomeScreen(
        databaseService: databaseService,
        autoCheckForUpdates: autoCheckForUpdates,
      ),
    );
  }
}
