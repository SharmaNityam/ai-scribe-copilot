import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/session.dart';
import '../models/audio_chunk.dart';

class LocalStorageRepository {
  static final LocalStorageRepository _instance = LocalStorageRepository._internal();
  factory LocalStorageRepository() => _instance;
  LocalStorageRepository._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'medical_transcription.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions (
        sessionId TEXT PRIMARY KEY,
        patientId TEXT,
        userId TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT,
        status TEXT NOT NULL,
        uploadedChunkIds TEXT,
        totalChunks INTEGER DEFAULT 0,
        uploadSessionId TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE audio_chunks (
        chunkId TEXT PRIMARY KEY,
        sessionId TEXT NOT NULL,
        sequenceNumber INTEGER NOT NULL,
        filePath TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        fileSize INTEGER,
        status TEXT NOT NULL,
        presignedUrl TEXT,
        retryCount INTEGER DEFAULT 0,
        errorMessage TEXT,
        FOREIGN KEY (sessionId) REFERENCES sessions (sessionId)
      )
    ''');

    await db.execute('CREATE INDEX idx_chunks_session ON audio_chunks(sessionId)');
    await db.execute('CREATE INDEX idx_chunks_status ON audio_chunks(status)');
  }

  Future<void> saveSession(RecordingSession session) async {
    final db = await database;
    final json = session.toJson();
    // Convert List<String> to JSON string for SQLite
    final chunkIds = json['uploadedChunkIds'] as List?;
    json['uploadedChunkIds'] = chunkIds != null && chunkIds.isNotEmpty
        ? jsonEncode(chunkIds)
        : null;
    await db.insert(
      'sessions',
      json,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<RecordingSession?> getSession(String sessionId) async {
    final db = await database;
    final maps = await db.query(
      'sessions',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );

    if (maps.isEmpty) return null;
    final map = Map<String, dynamic>.from(maps.first);
    if (map['uploadedChunkIds'] != null && map['uploadedChunkIds'] is String) {
      map['uploadedChunkIds'] = jsonDecode(map['uploadedChunkIds']);
    }
    return RecordingSession.fromJson(map);
  }

  Future<List<RecordingSession>> getActiveSessions() async {
    final db = await database;
    final maps = await db.query(
      'sessions',
      where: 'status IN (?, ?)',
      whereArgs: ['recording', 'paused'],
    );

    return maps.map((map) {
      final sessionMap = Map<String, dynamic>.from(map);
      if (sessionMap['uploadedChunkIds'] != null && sessionMap['uploadedChunkIds'] is String) {
        sessionMap['uploadedChunkIds'] = jsonDecode(sessionMap['uploadedChunkIds']);
      }
      return RecordingSession.fromJson(sessionMap);
    }).toList();
  }

  Future<void> updateSession(RecordingSession session) async {
    final db = await database;
    final json = session.toJson();
    // Convert List<String> to JSON string for SQLite
    final chunkIds = json['uploadedChunkIds'] as List?;
    json['uploadedChunkIds'] = chunkIds != null && chunkIds.isNotEmpty
        ? jsonEncode(chunkIds)
        : null;
    await db.update(
      'sessions',
      json,
      where: 'sessionId = ?',
      whereArgs: [session.sessionId],
    );
  }

  Future<void> saveChunk(AudioChunk chunk) async {
    final db = await database;
    await db.insert(
      'audio_chunks',
      chunk.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AudioChunk>> getPendingChunks(String sessionId) async {
    final db = await database;
    final maps = await db.query(
      'audio_chunks',
      where: 'sessionId = ? AND status IN (?, ?)',
      whereArgs: [sessionId, 'pending', 'failed'],
      orderBy: 'sequenceNumber ASC',
    );

    return maps.map((map) => AudioChunk.fromJson(map)).toList();
  }

  Future<List<AudioChunk>> getAllPendingChunks() async {
    final db = await database;
    final maps = await db.query(
      'audio_chunks',
      where: 'status IN (?, ?)',
      whereArgs: ['pending', 'failed'],
      orderBy: 'sequenceNumber ASC',
    );

    return maps.map((map) => AudioChunk.fromJson(map)).toList();
  }

  Future<List<AudioChunk>> getChunksBySession(String sessionId) async {
    final db = await database;
    final maps = await db.query(
      'audio_chunks',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'sequenceNumber ASC',
    );

    return maps.map((map) => AudioChunk.fromJson(map)).toList();
  }

  Future<void> updateChunk(AudioChunk chunk) async {
    final db = await database;
    await db.update(
      'audio_chunks',
      chunk.toJson(),
      where: 'chunkId = ?',
      whereArgs: [chunk.chunkId],
    );
  }

  Future<void> deleteChunk(String chunkId) async {
    final db = await database;
    await db.delete(
      'audio_chunks',
      where: 'chunkId = ?',
      whereArgs: [chunkId],
    );
  }

  Future<void> clearCompletedChunks(String sessionId) async {
    final db = await database;
    await db.delete(
      'audio_chunks',
      where: 'sessionId = ? AND status = ?',
      whereArgs: [sessionId, 'uploaded'],
    );
  }
}

