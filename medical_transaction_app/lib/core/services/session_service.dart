import '../models/session.dart';
import '../repositories/api_repository.dart';
import '../repositories/local_storage_repository.dart';
import '../utils/logger.dart';
import '../utils/validation.dart';

class SessionService {
  final ApiRepository _apiRepository;
  final LocalStorageRepository _localStorage;

  SessionService({
    ApiRepository? apiRepository,
    LocalStorageRepository? localStorage,
  })  : _apiRepository = apiRepository ?? ApiRepository(),
        _localStorage = localStorage ?? LocalStorageRepository();

  Future<RecordingSession> createSession({
    required String userId,
    String? patientId,
    String? patientName,
    String? templateId,
  }) async {
    if (!Validation.isNotEmpty(userId)) {
      throw ArgumentError('userId cannot be empty');
    }
    
    try {
    final uploadSessionData = await _apiRepository.createUploadSession(
      userId: userId,
      patientId: patientId,
      patientName: patientName,
      templateId: templateId,
    );

      final backendSessionId = Validation.getString(uploadSessionData, 'id');
      if (backendSessionId == null) {
        throw Exception('Backend did not return a session ID');
      }
    
    final session = RecordingSession(
      sessionId: backendSessionId, // Use backend session ID
      patientId: patientId,
      userId: userId,
      startTime: DateTime.now(),
      status: 'recording',
      uploadSessionId: backendSessionId,
    );

    await _localStorage.saveSession(session);
      
      AppLogger.info('Created session: $backendSessionId for user: $userId');

    return session;
    } catch (e) {
      AppLogger.error('Failed to create session', e);
      rethrow;
    }
  }

  Future<RecordingSession?> getSession(String sessionId) async {
    return await _localStorage.getSession(sessionId);
  }

  Future<List<RecordingSession>> getActiveSessions() async {
    return await _localStorage.getActiveSessions();
  }

  Future<void> updateSession(RecordingSession session) async {
    await _localStorage.updateSession(session);
  }

  Future<void> pauseSession(String sessionId) async {
    final session = await getSession(sessionId);
    if (session != null) {
      final updated = session.copyWith(status: 'paused');
      await updateSession(updated);
    }
  }

  Future<void> resumeSession(String sessionId) async {
    final session = await getSession(sessionId);
    if (session != null) {
      final updated = session.copyWith(status: 'recording');
      await updateSession(updated);
    }
  }

  Future<void> completeSession(String sessionId) async {
    final session = await getSession(sessionId);
    if (session != null) {
      final updated = session.copyWith(
        status: 'completed',
        endTime: DateTime.now(),
      );
      await updateSession(updated);
    }
  }

  Future<RecordingSession?> recoverSession() async {
    try {
    final activeSessions = await getActiveSessions();
      if (activeSessions.isEmpty) {
        AppLogger.debug('No active sessions to recover');
        return null;
      }
      
      activeSessions.sort((a, b) => b.startTime.compareTo(a.startTime));
      final recoveredSession = activeSessions.first;
      
      final sessionAge = DateTime.now().difference(recoveredSession.startTime);
      if (sessionAge.inDays > 1) {
        AppLogger.warning('Session ${recoveredSession.sessionId} is too old, marking as completed');
        await completeSession(recoveredSession.sessionId);
        return null;
      }
      
      AppLogger.info('Recovered session: ${recoveredSession.sessionId}');
      return recoveredSession;
    } catch (e) {
      AppLogger.error('Failed to recover session', e);
      return null;
    }
  }
}

