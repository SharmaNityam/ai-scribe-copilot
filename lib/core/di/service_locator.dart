import '../repositories/api_repository.dart';
import '../repositories/local_storage_repository.dart';
import '../services/audio_recorder_service.dart';
import '../services/session_service.dart';
import '../services/upload_service.dart';
import '../services/interruption_handler.dart';
import '../services/audio_player_service.dart';
import '../services/transcription_service.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();
  
  ApiRepository? _apiRepository;
  LocalStorageRepository? _localStorageRepository;
  
  AudioRecorderService? _audioRecorderService;
  SessionService? _sessionService;
  UploadService? _uploadService;
  InterruptionHandler? _interruptionHandler;
  AudioPlayerService? _audioPlayerService;
  TranscriptionService? _transcriptionService;
  ApiRepository get apiRepository {
    _apiRepository ??= ApiRepository();
    return _apiRepository!;
  }
  
  LocalStorageRepository get localStorageRepository {
    _localStorageRepository ??= LocalStorageRepository();
    return _localStorageRepository!;
  }
  
  AudioRecorderService get audioRecorderService {
    _audioRecorderService ??= AudioRecorderService();
    return _audioRecorderService!;
  }
  
  SessionService get sessionService {
    _sessionService ??= SessionService(
      apiRepository: apiRepository,
      localStorage: localStorageRepository,
    );
    return _sessionService!;
  }
  
  UploadService get uploadService {
    _uploadService ??= UploadService(
      apiRepository: apiRepository,
      localStorage: localStorageRepository,
      sessionService: sessionService,
    );
    return _uploadService!;
  }
  
  InterruptionHandler get interruptionHandler {
    _interruptionHandler ??= InterruptionHandler(
      audioRecorder: audioRecorderService,
      sessionService: sessionService,
      uploadService: uploadService,
      transcriptionService: transcriptionService,
    );
    return _interruptionHandler!;
  }
  
  AudioPlayerService get audioPlayerService {
    _audioPlayerService ??= AudioPlayerService();
    return _audioPlayerService!;
  }
  
  TranscriptionService get transcriptionService {
    _transcriptionService ??= TranscriptionService();
    return _transcriptionService!;
  }
  
  void reset() {
    _audioRecorderService?.dispose();
    _uploadService?.dispose();
    _audioPlayerService?.dispose();
    _interruptionHandler?.dispose();
    _transcriptionService?.dispose();
    
    _apiRepository = null;
    _localStorageRepository = null;
    _audioRecorderService = null;
    _sessionService = null;
    _uploadService = null;
    _interruptionHandler = null;
    _audioPlayerService = null;
    _transcriptionService = null;
  }
}

