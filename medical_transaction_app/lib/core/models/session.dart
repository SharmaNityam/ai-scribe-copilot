class RecordingSession {
  final String sessionId;
  final String? patientId;
  final String userId;
  final DateTime startTime;
  DateTime? endTime;
  final String status;
  final List<String> uploadedChunkIds;
  final int totalChunks;
  final String? uploadSessionId; // Backend session ID

  RecordingSession({
    required this.sessionId,
    this.patientId,
    required this.userId,
    required this.startTime,
    this.endTime,
    this.status = 'recording',
    List<String>? uploadedChunkIds,
    this.totalChunks = 0,
    this.uploadSessionId,
  }) : uploadedChunkIds = uploadedChunkIds ?? [];

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'patientId': patientId,
      'userId': userId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'status': status,
      'uploadedChunkIds': uploadedChunkIds,
      'totalChunks': totalChunks,
      'uploadSessionId': uploadSessionId,
    };
  }

  factory RecordingSession.fromJson(Map<String, dynamic> json) {
    return RecordingSession(
      sessionId: json['sessionId'],
      patientId: json['patientId'],
      userId: json['userId'],
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      status: json['status'] ?? 'recording',
      uploadedChunkIds: List<String>.from(json['uploadedChunkIds'] ?? []),
      totalChunks: json['totalChunks'] ?? 0,
      uploadSessionId: json['uploadSessionId'],
    );
  }

  RecordingSession copyWith({
    String? sessionId,
    String? patientId,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    List<String>? uploadedChunkIds,
    int? totalChunks,
    String? uploadSessionId,
  }) {
    return RecordingSession(
      sessionId: sessionId ?? this.sessionId,
      patientId: patientId ?? this.patientId,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      uploadedChunkIds: uploadedChunkIds ?? this.uploadedChunkIds,
      totalChunks: totalChunks ?? this.totalChunks,
      uploadSessionId: uploadSessionId ?? this.uploadSessionId,
    );
  }
}

