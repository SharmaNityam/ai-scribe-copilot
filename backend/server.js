const express = require('express');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const multer = require('multer');
const AWS = require('aws-sdk');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Request logging middleware
app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${req.method} ${req.path}`);
  if (req.query && Object.keys(req.query).length > 0) {
    console.log(`  Query params:`, req.query);
  }
  if (req.body && Object.keys(req.body).length > 0 && req.method !== 'PUT') {
    // Don't log binary data for PUT requests
    console.log(`  Body:`, JSON.stringify(req.body, null, 2));
  }
  next();
});

// In-memory storage (for mock server)
const sessions = new Map();
const patients = new Map();
const chunks = new Map();

// Mock S3 configuration (for presigned URLs)
const s3 = new AWS.S3({
  endpoint: process.env.S3_ENDPOINT || 'http://localhost:9000',
  s3ForcePathStyle: true,
  signatureVersion: 'v4',
  accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'minioadmin',
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'minioadmin',
});

// Configure multer for file uploads
const upload = multer({ storage: multer.memoryStorage() });

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Session Management Endpoints

// POST /v1/upload-session - Start recording
app.post('/v1/upload-session', (req, res) => {
  const { patientId, userId, patientName, status, startTime, templateId } = req.body;
  
  console.log(`[SESSION CREATE] userId: ${userId}, patientId: ${patientId || 'none'}, patientName: ${patientName || 'none'}`);
  
  if (!userId) {
    console.error(`[SESSION CREATE ERROR] Missing userId`);
    return res.status(400).json({ error: 'userId is required' });
  }

  const sessionId = uuidv4();
  const session = {
    id: sessionId,
    sessionId,
    userId,
    patientId: patientId || null,
    patientName: patientName || null,
    status: status || 'recording',
    startTime: startTime || new Date().toISOString(),
    templateId: templateId || null,
    chunks: [],
    createdAt: new Date().toISOString(),
  };

  sessions.set(sessionId, session);
  
  console.log(`[SESSION CREATE SUCCESS] Session ID: ${sessionId}, Status: ${session.status}`);

  res.status(201).json({
    id: sessionId,
  });
});

// POST /v1/get-presigned-url - Get chunk upload URL
app.post('/v1/get-presigned-url', (req, res) => {
  const { sessionId, chunkNumber, mimeType } = req.body;

  console.log(`[PRESIGNED URL REQUEST] Session: ${sessionId}, Chunk: ${chunkNumber}, MimeType: ${mimeType || 'audio/wav'}`);

  if (!sessionId || chunkNumber === undefined) {
    console.error(`[PRESIGNED URL ERROR] Missing sessionId or chunkNumber`);
    return res.status(400).json({ 
      error: 'sessionId and chunkNumber are required' 
    });
  }

  const session = sessions.get(sessionId);
  if (!session) {
    console.error(`[PRESIGNED URL ERROR] Session not found: ${sessionId}`);
    return res.status(404).json({ error: 'Session not found' });
  }

  // Generate presigned URL (mock - in production, use real GCS)
  const baseUrl = process.env.BASE_URL || 'https://ai-scribe-copilot-rev9.onrender.com';
  const gcsPath = `sessions/${sessionId}/chunk_${chunkNumber}.${mimeType ? mimeType.split('/')[1] : 'wav'}`;
  const url = `${baseUrl}/v1/upload-chunk/${sessionId}/${chunkNumber}`;
  const publicUrl = `${baseUrl}/public/${gcsPath}`;

  // Store chunk metadata
  const chunkId = `${sessionId}_chunk_${chunkNumber}`;
  const chunk = {
    chunkId,
    sessionId,
    chunkNumber,
    mimeType: mimeType || 'audio/wav',
    gcsPath,
    status: 'pending',
    uploadedAt: null,
  };
  chunks.set(chunkId, chunk);

  console.log(`[PRESIGNED URL SUCCESS] Session: ${sessionId}, Chunk: ${chunkNumber}, URL: ${url}`);

  res.json({
    url,
    gcsPath,
    publicUrl,
  });
});

// PUT {presignedUrl} - Upload audio chunk (raw binary data)
app.put('/v1/upload-chunk/:sessionId/:chunkNumber', express.raw({ type: ['audio/wav', 'audio/*', 'application/octet-stream'], limit: '50mb' }), (req, res) => {
  const { sessionId, chunkNumber } = req.params;
  const audioData = req.body;
  const fileSize = audioData ? audioData.length : 0;
  const fileSizeKB = (fileSize / 1024).toFixed(2);
  const fileSizeMB = (fileSize / (1024 * 1024)).toFixed(2);
  
  console.log(`[CHUNK UPLOAD] Session: ${sessionId}, Chunk: ${chunkNumber}, Size: ${fileSize} bytes (${fileSizeKB} KB / ${fileSizeMB} MB)`);
  
  if (!audioData || audioData.length === 0) {
    console.error(`[CHUNK UPLOAD ERROR] Empty audio data for Session: ${sessionId}, Chunk: ${chunkNumber}`);
    return res.status(400).json({ error: 'Audio data is required' });
  }

  const session = sessions.get(sessionId);
  if (!session) {
    console.error(`[CHUNK UPLOAD ERROR] Session not found: ${sessionId}`);
    return res.status(404).json({ error: 'Session not found' });
  }

  const chunkId = `${sessionId}_chunk_${chunkNumber}`;
  const chunkData = chunks.get(chunkId);
  if (chunkData) {
    chunkData.status = 'uploaded';
    chunkData.uploadedAt = new Date().toISOString();
    chunkData.fileSize = audioData.length;
    chunks.set(chunkId, chunkData);
  }

  // Add to session
  if (!session.chunks.includes(chunkId)) {
    session.chunks.push(chunkId);
  }

  console.log(`[CHUNK UPLOAD SUCCESS] Session: ${sessionId}, Chunk: ${chunkNumber}, Total chunks in session: ${session.chunks.length}`);

  // Return empty response for GCS compatibility
  res.status(200).send();
});

// POST /v1/notify-chunk-uploaded - Confirm chunk received
app.post('/v1/notify-chunk-uploaded', (req, res) => {
  const { 
    sessionId, 
    gcsPath, 
    chunkNumber, 
    isLast, 
    totalChunksClient, 
    publicUrl, 
    mimeType, 
    selectedTemplate, 
    selectedTemplateId, 
    model 
  } = req.body;

  console.log(`[CHUNK NOTIFY] Session: ${sessionId}, Chunk: ${chunkNumber}, IsLast: ${isLast || false}, TotalChunksClient: ${totalChunksClient || 'unknown'}`);

  if (!sessionId || !gcsPath || chunkNumber === undefined) {
    console.error(`[CHUNK NOTIFY ERROR] Missing required fields - sessionId: ${sessionId}, gcsPath: ${gcsPath}, chunkNumber: ${chunkNumber}`);
    return res.status(400).json({ error: 'sessionId, gcsPath, and chunkNumber are required' });
  }

  const session = sessions.get(sessionId);
  if (!session) {
    console.error(`[CHUNK NOTIFY ERROR] Session not found: ${sessionId}`);
    return res.status(404).json({ error: 'Session not found' });
  }

  const chunkId = `${sessionId}_chunk_${chunkNumber}`;
  const chunk = chunks.get(chunkId);
  if (chunk) {
    chunk.status = 'confirmed';
    chunk.gcsPath = gcsPath;
    chunk.publicUrl = publicUrl;
    chunk.isLast = isLast || false;
    chunks.set(chunkId, chunk);
  }

  if (isLast) {
    console.log(`[CHUNK NOTIFY] ⭐ LAST CHUNK RECEIVED for Session: ${sessionId}, Chunk: ${chunkNumber}`);
  }

  console.log(`[CHUNK NOTIFY SUCCESS] Session: ${sessionId}, Chunk: ${chunkNumber} confirmed, Total chunks in session: ${session.chunks.length}`);

  // Return empty response as per API spec
  res.status(200).json({});
});

// Patient Management Endpoints

// GET /v1/patients?userId={userId}
app.get('/v1/patients', (req, res) => {
  const { userId } = req.query;

  if (!userId) {
    return res.status(400).json({ error: 'userId is required' });
  }

  const userPatients = Array.from(patients.values())
    .filter(p => p.userId === userId);

  res.json({
    patients: userPatients,
    count: userPatients.length,
  });
});

// POST /v1/add-patient-ext - Add new patient
app.post('/v1/add-patient-ext', (req, res) => {
  const { userId, name, phoneNumber, email, dateOfBirth, gender, additionalInfo } = req.body;

  console.log(`[PATIENT ADD] userId: ${userId}, name: ${name}`);

  if (!userId || !name) {
    console.error(`[PATIENT ADD ERROR] Missing userId or name`);
    return res.status(400).json({ error: 'userId and name are required' });
  }

  const patientId = uuidv4();
  const patient = {
    id: patientId,
    userId,
    name,
    phoneNumber: phoneNumber || null,
    email: email || null,
    dateOfBirth: dateOfBirth || null,
    gender: gender || null,
    additionalInfo: additionalInfo || {},
    createdAt: new Date().toISOString(),
  };

  patients.set(patientId, patient);

  console.log(`[PATIENT ADD SUCCESS] Patient ID: ${patientId}, Name: ${name}`);

  res.status(201).json({
    message: 'Patient added successfully',
    patient,
  });
});

// GET /v1/fetch-session-by-patient/{patientId}
app.get('/v1/fetch-session-by-patient/:patientId', (req, res) => {
  const { patientId } = req.params;

  const patientSessions = Array.from(sessions.values())
    .filter(s => s.patientId === patientId)
    .map(s => ({
      id: s.id || s.sessionId,
      date: s.startTime ? s.startTime.split('T')[0] : new Date().toISOString().split('T')[0],
      session_title: s.templateId || 'Recording Session',
      session_summary: 'Patient consultation summary',
      start_time: s.startTime,
    }));

  res.json({
    sessions: patientSessions,
  });
});

// GET /v1/patient-details/{patientId}
app.get('/v1/patient-details/:patientId', (req, res) => {
  const { patientId } = req.params;

  const patient = patients.get(patientId);
  if (!patient) {
    return res.status(404).json({ error: 'Patient not found' });
  }

  res.json({
    id: patient.id,
    name: patient.name,
    pronouns: patient.pronouns || null,
    email: patient.email || null,
    background: patient.background || null,
    medical_history: patient.medical_history || null,
    family_history: patient.family_history || null,
    social_history: patient.social_history || null,
    previous_treatment: patient.previous_treatment || null,
  });
});

// GET /v1/all-session?userId={userId}
app.get('/v1/all-session', (req, res) => {
  const { userId } = req.query;

  console.log(`[SESSIONS LIST] userId: ${userId}`);

  if (!userId) {
    console.error(`[SESSIONS LIST ERROR] Missing userId`);
    return res.status(400).json({ error: 'userId is required' });
  }

  const userSessions = Array.from(sessions.values())
    .filter(s => s.userId === userId)
    .map(s => {
      const patient = s.patientId ? patients.get(s.patientId) : null;
      return {
        id: s.id || s.sessionId,
        user_id: s.userId,
        patient_id: s.patientId,
        session_title: s.templateId || 'Recording Session',
        session_summary: 'Patient consultation summary',
        transcript_status: 'pending',
        transcript: '',
        status: s.status || 'recording',
        date: s.startTime ? s.startTime.split('T')[0] : new Date().toISOString().split('T')[0],
        start_time: s.startTime,
        end_time: s.endTime || null,
        patient_name: patient?.name || s.patientName || null,
        pronouns: patient?.pronouns || null,
        email: patient?.email || null,
        background: patient?.background || null,
        duration: s.endTime && s.startTime 
          ? `${Math.round((new Date(s.endTime) - new Date(s.startTime)) / 60000)} minutes`
          : null,
        medical_history: patient?.medical_history || null,
        family_history: patient?.family_history || null,
        social_history: patient?.social_history || null,
        previous_treatment: patient?.previous_treatment || null,
        patient_pronouns: patient?.pronouns || null,
        clinical_notes: [],
      };
    });

  const patientMap = {};
  userSessions.forEach(s => {
    if (s.patient_id && !patientMap[s.patient_id]) {
      const patient = patients.get(s.patient_id);
      if (patient) {
        patientMap[s.patient_id] = {
          name: patient.name,
          pronouns: patient.pronouns || null,
        };
      }
    }
  });

  res.json({
    sessions: userSessions,
    patientMap,
  });
});

// GET /v1/fetch-default-template-ext?userId={userId}
app.get('/v1/fetch-default-template-ext', (req, res) => {
  const { userId } = req.query;

  if (!userId) {
    return res.status(400).json({ error: 'userId is required' });
  }

  // Mock templates
  const templates = [
    {
      id: 'new_patient_visit',
      title: 'New Patient Visit',
      type: 'default',
    },
    {
      id: 'follow_up_visit',
      title: 'Follow-up Visit',
      type: 'predefined',
    },
  ];

  res.json({
    success: true,
    data: templates,
  });
});

// GET /users/asd3fd2faec?email={email}
app.get('/users/asd3fd2faec', (req, res) => {
  const { email } = req.query;

  if (!email) {
    return res.status(400).json({ error: 'email is required' });
  }

  // Mock user resolution - in production, this would query a database
  res.json({
    id: `user_${email.replace('@', '_').replace('.', '_')}`,
  });
});

// DEBUG: GET /v1/debug/session/{sessionId}/chunks - View chunks for a session
app.get('/v1/debug/session/:sessionId/chunks', (req, res) => {
  const { sessionId } = req.params;

  const session = sessions.get(sessionId);
  if (!session) {
    return res.status(404).json({ error: 'Session not found' });
  }

  // Get all chunks for this session
  const sessionChunks = Array.from(chunks.values())
    .filter(c => c.sessionId === sessionId)
    .sort((a, b) => a.chunkNumber - b.chunkNumber)
    .map(c => ({
      chunkId: c.chunkId,
      chunkNumber: c.chunkNumber,
      status: c.status,
      fileSize: c.fileSize || 0,
      uploadedAt: c.uploadedAt,
      gcsPath: c.gcsPath,
      mimeType: c.mimeType,
    }));

  res.json({
    sessionId,
    sessionStatus: session.status,
    totalChunks: sessionChunks.length,
    chunks: sessionChunks,
    sessionChunkIds: session.chunks,
  });
});

// DEBUG: GET /v1/debug/chunks - View all chunks (for debugging)
app.get('/v1/debug/chunks', (req, res) => {
  const allChunks = Array.from(chunks.values())
    .sort((a, b) => {
      if (a.sessionId !== b.sessionId) {
        return a.sessionId.localeCompare(b.sessionId);
      }
      return a.chunkNumber - b.chunkNumber;
    })
    .map(c => ({
      chunkId: c.chunkId,
      sessionId: c.sessionId,
      chunkNumber: c.chunkNumber,
      status: c.status,
      fileSize: c.fileSize || 0,
      uploadedAt: c.uploadedAt,
      gcsPath: c.gcsPath,
      mimeType: c.mimeType,
    }));

  res.json({
    totalChunks: allChunks.length,
    chunks: allChunks,
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});

module.exports = app;


