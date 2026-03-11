const axios = require('axios');

(async () => {
  const baseURL = 'http://localhost:5000';
  const api = axios.create({ baseURL, validateStatus: () => true, timeout: 15000 });
  const ts = Date.now();

  const doctorReg = {
    email: `doctor_${ts}@example.com`,
    password: 'Pass@123',
    name: 'Doctor Test',
    role: 'doctor',
    specialization: 'Cardiologist'
  };

  const patientReg = {
    email: `patient_${ts}@example.com`,
    password: 'Pass@123',
    name: 'Patient Test',
    role: 'patient'
  };

  const result = {
    registerDoctor: null,
    registerPatient: null,
    loginDoctor: null,
    loginPatient: null,
    appointmentBook: null,
    doctorAppointments: null,
    callInitiate: null,
    callAnswer: null,
    callMetrics: null,
    callEnd: null,
    callHistoryDoctor: null,
    chatStart: null,
    chatSendPatient: null,
    chatSendDoctor: null,
    chatMessages: null,
    uploadReportEndpoint: null,
    prescriptionEndpoint: null,
    ids: {}
  };

  function auth(token) {
    return { headers: { Authorization: `Bearer ${token}` } };
  }

  // Register
  let r = await api.post('/api/auth/register', doctorReg);
  result.registerDoctor = { status: r.status, ok: r.status === 201, body: r.data?.message || r.data?.error };

  r = await api.post('/api/auth/register', patientReg);
  result.registerPatient = { status: r.status, ok: r.status === 201, body: r.data?.message || r.data?.error };

  // Login
  const doctorLogin = await api.post('/api/auth/login', { email: doctorReg.email, password: doctorReg.password });
  const patientLogin = await api.post('/api/auth/login', { email: patientReg.email, password: patientReg.password });

  result.loginDoctor = { status: doctorLogin.status, ok: doctorLogin.status === 200 };
  result.loginPatient = { status: patientLogin.status, ok: patientLogin.status === 200 };

  if (doctorLogin.status !== 200 || patientLogin.status !== 200) {
    console.log(JSON.stringify(result, null, 2));
    process.exit(0);
  }

  const doctorToken = doctorLogin.data.token;
  const patientToken = patientLogin.data.token;
  const doctorId = doctorLogin.data.user.userId;
  const patientId = patientLogin.data.user.userId;

  result.ids = { doctorId, patientId };

  // Book appointment
  const book = await api.post('/api/users/appointments/book', {
    doctorId,
    slotTime: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
    reason: 'Routine checkup'
  }, auth(patientToken));
  result.appointmentBook = { status: book.status, ok: book.status === 201, appointmentId: book.data?.appointmentId };

  const appointmentId = book.data?.appointmentId;

  // Doctor gets appointments
  const dAppts = await api.get('/api/users/appointments', auth(doctorToken));
  result.doctorAppointments = { status: dAppts.status, ok: dAppts.status === 200, count: dAppts.data?.count };

  // Call REST flow
  const initCall = await api.post('/api/calls/initiate', {
    recipientId: doctorId,
    type: 'video',
    initiatorName: 'Patient Test'
  }, auth(patientToken));
  result.callInitiate = { status: initCall.status, ok: initCall.status === 201, callId: initCall.data?.callId };

  const callId = initCall.data?.callId;

  let answer = { status: 0 };
  let metrics = { status: 0 };
  let end = { status: 0 };
  if (callId) {
    answer = await api.post('/api/calls/answer', { callId }, auth(doctorToken));
    metrics = await api.post(`/api/calls/${callId}/metrics`, {
      networkQuality: 'good',
      videoResolution: '720p',
      frameRate: 24,
      bitrate: 1500,
      latency: 75,
      packetLoss: 0.5,
      bandwidth: 3.2
    }, auth(doctorToken));
    end = await api.post('/api/calls/end', { callId }, auth(patientToken));
  }

  result.callAnswer = { status: answer.status, ok: answer.status === 200 };
  result.callMetrics = { status: metrics.status, ok: metrics.status === 200 };
  result.callEnd = { status: end.status, ok: end.status === 200 };

  const history = await api.get('/api/calls/history', auth(doctorToken));
  result.callHistoryDoctor = { status: history.status, ok: history.status === 200, count: history.data?.count };

  // Chat flow
  const chatStart = await api.post('/api/users/chats/start', { participants: [doctorId, patientId] }, auth(patientToken));
  const chatId = chatStart.data?.chatId;
  result.chatStart = { status: chatStart.status, ok: chatStart.status === 201, chatId };

  let pMsg = { status: 0 }, dMsg = { status: 0 }, chatMsgs = { status: 0 };
  if (chatId) {
    pMsg = await api.post(`/api/users/chats/${chatId}/message`, { text: 'Hello doctor' }, auth(patientToken));
    dMsg = await api.post(`/api/users/chats/${chatId}/message`, { text: 'Hello patient, please share report.' }, auth(doctorToken));
    chatMsgs = await api.get(`/api/users/chats/${chatId}/messages`, auth(doctorToken));
  }

  result.chatSendPatient = { status: pMsg.status, ok: pMsg.status === 200 };
  result.chatSendDoctor = { status: dMsg.status, ok: dMsg.status === 200 };
  result.chatMessages = { status: chatMsgs.status, ok: chatMsgs.status === 200, count: chatMsgs.data?.messages?.length };

  // Report upload endpoint check (expected by frontend)
  if (appointmentId) {
    const report = await api.post(`/api/users/appointments/${appointmentId}/report`, {
      name: 'sample-report.jpg',
      contentBase64: 'aGVsbG8='
    }, auth(patientToken));
    result.uploadReportEndpoint = {
      status: report.status,
      ok: report.status >= 200 && report.status < 300,
      note: report.status === 404 ? 'Endpoint missing in backend routes' : 'Endpoint exists'
    };
  }

  // Prescription endpoint check (doctor app expects /api/prescriptions)
  const prescription = await api.get('/api/prescriptions', auth(doctorToken));
  result.prescriptionEndpoint = {
    status: prescription.status,
    ok: prescription.status >= 200 && prescription.status < 300,
    note: prescription.status === 404 ? 'Route file exists but not mounted in server.js' : 'Endpoint exists'
  };

  console.log(JSON.stringify(result, null, 2));
})();
