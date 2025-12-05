class AudioChunk {
  final String chunkId;
  final String sessionId;
  final int sequenceNumber;
  final String filePath;
  final DateTime timestamp;
  final int? fileSize;
  final String status; // 'pending', 'uploading', 'uploaded', 'failed'
  final String? presignedUrl;
  final int retryCount;
  final String? errorMessage;

  AudioChunk({
    required this.chunkId,
    required this.sessionId,
    required this.sequenceNumber,
    required this.filePath,
    required this.timestamp,
    this.fileSize,
    this.status = 'pending',
    this.presignedUrl,
    this.retryCount = 0,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'chunkId': chunkId,
      'sessionId': sessionId,
      'sequenceNumber': sequenceNumber,
      'filePath': filePath,
      'timestamp': timestamp.toIso8601String(),
      'fileSize': fileSize,
      'status': status,
      'presignedUrl': presignedUrl,
      'retryCount': retryCount,
      'errorMessage': errorMessage,
    };
  }

  factory AudioChunk.fromJson(Map<String, dynamic> json) {
    return AudioChunk(
      chunkId: json['chunkId'],
      sessionId: json['sessionId'],
      sequenceNumber: json['sequenceNumber'],
      filePath: json['filePath'],
      timestamp: DateTime.parse(json['timestamp']),
      fileSize: json['fileSize'],
      status: json['status'] ?? 'pending',
      presignedUrl: json['presignedUrl'],
      retryCount: json['retryCount'] ?? 0,
      errorMessage: json['errorMessage'],
    );
  }

  AudioChunk copyWith({
    String? chunkId,
    String? sessionId,
    int? sequenceNumber,
    String? filePath,
    DateTime? timestamp,
    int? fileSize,
    String? status,
    String? presignedUrl,
    int? retryCount,
    String? errorMessage,
  }) {
    return AudioChunk(
      chunkId: chunkId ?? this.chunkId,
      sessionId: sessionId ?? this.sessionId,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      filePath: filePath ?? this.filePath,
      timestamp: timestamp ?? this.timestamp,
      fileSize: fileSize ?? this.fileSize,
      status: status ?? this.status,
      presignedUrl: presignedUrl ?? this.presignedUrl,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

