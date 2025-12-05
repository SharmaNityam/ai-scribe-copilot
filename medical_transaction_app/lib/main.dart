import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/di/service_locator.dart';
import 'core/services/interruption_handler.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/recording/recording_controller.dart';
import 'features/recording/recording_screen.dart';
import 'features/patients/patients_list_screen.dart';
import 'features/sessions/sessions_list_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/theme_language_provider.dart';
import 'core/utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await NotificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeLanguageProvider(),
      child: Consumer<ThemeLanguageProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Medical Transaction App',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppTheme.primaryBlue,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              cardTheme: CardThemeData(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppTheme.primaryBlue,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              cardTheme: CardThemeData(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            themeMode: themeProvider.themeMode,
            home: const HomeScreen(),
            routes: {
              '/settings': (context) => const SettingsScreen(),
            },
          );
        },
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  
  late final RecordingController _recordingController;
  late final InterruptionHandler _interruptionHandler;
  final ServiceLocator _serviceLocator = ServiceLocator();

  final String _userId = 'user_123';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _recordingController = RecordingController(
      transcriptionService: _serviceLocator.transcriptionService,
      audioRecorder: _serviceLocator.audioRecorderService,
      sessionService: _serviceLocator.sessionService,
      uploadService: _serviceLocator.uploadService,
    );
    
    _interruptionHandler = _serviceLocator.interruptionHandler;
    _interruptionHandler.setPhoneCallStateCallback((isPaused) {
      AppLogger.info('Phone call state callback invoked: isPaused=$isPaused');
      if (isPaused) {
        AppLogger.info('Calling handlePhoneCallPause on RecordingController');
        _recordingController.handlePhoneCallPause();
      } else {
        AppLogger.info('Calling handlePhoneCallResume on RecordingController');
        _recordingController.handlePhoneCallResume();
      }
    });
    AppLogger.info('Phone call state callback registered');
    
    _recoverSession();
  }
  
  Future<void> _recoverSession() async {
    try {
      final recoveredSession = await _serviceLocator.sessionService.recoverSession();
      if (recoveredSession != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recovered active session from ${recoveredSession.startTime}'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
              },
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to recover session', e);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _serviceLocator.uploadService.processPendingChunks();
        _interruptionHandler.handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _interruptionHandler.handleAppPaused();
        break;
      case AppLifecycleState.detached:
        _interruptionHandler.handleAppDetached();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeLanguageProvider>(context);
    final localizations = AppLocalizations(themeProvider.languageCode);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.translate('app_title'),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
          IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.settings,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildHeroCard(context, localizations, isDark),
                    const SizedBox(height: 32),
                    
                    _buildQuickActionsGrid(context, localizations, isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, AppLocalizations localizations, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.mic,
              size: 50,
              color: Colors.black,
            ),
            ),
            const SizedBox(height: 24),
          Text(
            localizations.translate('tap_to_begin_session'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChangeNotifierProvider.value(
                      value: _recordingController,
                      child: RecordingScreen(
                        userId: _userId,
                      ),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: isDark ? 4 : 2,
                shadowColor: Colors.black.withValues(alpha: 0.2),
              ),
              child: Text(
                localizations.translate('start_recording'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, AppLocalizations localizations, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.translate('quick_actions'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            _buildActionCard(
              context,
              icon: Icons.people,
              title: localizations.translate('patients'),
              gradient: AppTheme.primaryGradient,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PatientsListScreen(userId: _userId),
                  ),
                );
              },
              isDark: isDark,
            ),
            _buildActionCard(
              context,
              icon: Icons.history,
              title: localizations.translate('recordings'),
              gradient: AppTheme.accentGradient,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SessionsListScreen(userId: _userId),
                  ),
                );
              },
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Gradient gradient,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
