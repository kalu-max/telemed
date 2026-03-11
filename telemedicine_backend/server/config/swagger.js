const swaggerJsdoc = require('swagger-jsdoc');

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Telemedicine API',
      version: '1.0.0',
      description: 'REST API for the Telemedicine platform — authentication, appointments, chat, video calls, prescriptions, and more.',
      contact: { name: 'Telemedicine Team' },
    },
    servers: [
      { url: '/api', description: 'API base path' },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
      schemas: {
        User: {
          type: 'object',
          properties: {
            userId: { type: 'string' },
            email: { type: 'string', format: 'email' },
            name: { type: 'string' },
            role: { type: 'string', enum: ['patient', 'doctor', 'admin'] },
            phone: { type: 'string' },
          },
        },
        Doctor: {
          type: 'object',
          properties: {
            userId: { type: 'string' },
            specialization: { type: 'string' },
            bio: { type: 'string' },
            rating: { type: 'number' },
            consultationFee: { type: 'number' },
            isAvailable: { type: 'boolean' },
            yearsOfExperience: { type: 'integer' },
          },
        },
        Appointment: {
          type: 'object',
          properties: {
            appointmentId: { type: 'string' },
            doctorId: { type: 'string' },
            patientId: { type: 'string' },
            scheduledTime: { type: 'string', format: 'date-time' },
            status: { type: 'string', enum: ['scheduled', 'pending', 'connected', 'in-progress', 'completed', 'cancelled', 'missed'] },
            reason: { type: 'string' },
          },
        },
        Prescription: {
          type: 'object',
          properties: {
            prescriptionId: { type: 'string' },
            patientId: { type: 'string' },
            doctorId: { type: 'string' },
            diagnosis: { type: 'string' },
            medications: { type: 'array', items: { type: 'object' } },
            status: { type: 'string' },
          },
        },
        Review: {
          type: 'object',
          properties: {
            reviewId: { type: 'string' },
            doctorId: { type: 'string' },
            rating: { type: 'integer', minimum: 1, maximum: 5 },
            comment: { type: 'string' },
            isAnonymous: { type: 'boolean' },
          },
        },
        MedicalRecord: {
          type: 'object',
          properties: {
            recordId: { type: 'string' },
            patientId: { type: 'string' },
            diagnosis: { type: 'string' },
            treatment: { type: 'string' },
          },
        },
        AuditLog: {
          type: 'object',
          properties: {
            logId: { type: 'string' },
            userId: { type: 'string' },
            action: { type: 'string' },
            resourceType: { type: 'string' },
            resourceId: { type: 'string' },
            ipAddress: { type: 'string' },
            createdAt: { type: 'string', format: 'date-time' },
          },
        },
        Error: {
          type: 'object',
          properties: {
            error: { type: 'string' },
          },
        },
      },
    },
    security: [{ bearerAuth: [] }],

    paths: {
      '/auth/register': {
        post: {
          tags: ['Auth'],
          summary: 'Register a new user',
          security: [],
          requestBody: { required: true, content: { 'application/json': { schema: { type: 'object', required: ['email', 'password', 'name', 'role'], properties: { email: { type: 'string' }, password: { type: 'string', minLength: 8 }, name: { type: 'string' }, role: { type: 'string', enum: ['patient', 'doctor'] }, specialization: { type: 'string' } } } } } },
          responses: { 201: { description: 'User registered' }, 409: { description: 'Email taken' } },
        },
      },
      '/auth/login': {
        post: {
          tags: ['Auth'],
          summary: 'Login',
          security: [],
          requestBody: { required: true, content: { 'application/json': { schema: { type: 'object', required: ['email', 'password'], properties: { email: { type: 'string' }, password: { type: 'string' } } } } } },
          responses: { 200: { description: 'Login success with JWT token' }, 401: { description: 'Invalid credentials' } },
        },
      },
      '/auth/request-otp': {
        post: { tags: ['Auth'], summary: 'Request OTP for password reset', security: [], requestBody: { required: true, content: { 'application/json': { schema: { type: 'object', required: ['email'], properties: { email: { type: 'string' } } } } } }, responses: { 200: { description: 'OTP sent' } } },
      },
      '/auth/reset-password': {
        post: { tags: ['Auth'], summary: 'Reset password with OTP', security: [], requestBody: { required: true, content: { 'application/json': { schema: { type: 'object', required: ['email', 'otp', 'newPassword'], properties: { email: { type: 'string' }, otp: { type: 'string' }, newPassword: { type: 'string' } } } } } }, responses: { 200: { description: 'Password reset' }, 400: { description: 'Invalid OTP' } } },
      },
      '/users/doctors/available': {
        get: { tags: ['Doctors'], summary: 'Get available doctors', security: [], parameters: [{ in: 'query', name: 'specialization', schema: { type: 'string' } }], responses: { 200: { description: 'Doctor list' } } },
      },
      '/users/doctors/{doctorId}': {
        get: { tags: ['Doctors'], summary: 'Get doctor profile', parameters: [{ in: 'path', name: 'doctorId', required: true, schema: { type: 'string' } }], responses: { 200: { description: 'Doctor profile' } } },
        put: { tags: ['Doctors'], summary: 'Update doctor profile', parameters: [{ in: 'path', name: 'doctorId', required: true, schema: { type: 'string' } }], responses: { 200: { description: 'Updated' } } },
      },
      '/users/doctors/{doctorId}/reviews': {
        get: { tags: ['Reviews'], summary: 'Get doctor reviews', parameters: [{ in: 'path', name: 'doctorId', required: true, schema: { type: 'string' } }], responses: { 200: { description: 'Reviews list with average rating' } } },
        post: { tags: ['Reviews'], summary: 'Submit a review (patients only)', parameters: [{ in: 'path', name: 'doctorId', required: true, schema: { type: 'string' } }], requestBody: { required: true, content: { 'application/json': { schema: { type: 'object', required: ['rating'], properties: { rating: { type: 'integer', minimum: 1, maximum: 5 }, comment: { type: 'string' }, consultationId: { type: 'string' }, isAnonymous: { type: 'boolean' } } } } } }, responses: { 201: { description: 'Review created' }, 409: { description: 'Duplicate review' } } },
      },
      '/users/appointments': {
        get: { tags: ['Appointments'], summary: 'Get user appointments', responses: { 200: { description: 'Appointment list' } } },
      },
      '/users/appointments/book': {
        post: { tags: ['Appointments'], summary: 'Book appointment', requestBody: { required: true, content: { 'application/json': { schema: { type: 'object', required: ['doctorId'], properties: { doctorId: { type: 'string' }, slotTime: { type: 'string', format: 'date-time' }, reason: { type: 'string' } } } } } }, responses: { 201: { description: 'Appointment booked' } } },
      },
      '/users/medical-records': {
        get: { tags: ['Medical Records'], summary: 'Get medical records', responses: { 200: { description: 'Records list' } } },
        post: { tags: ['Medical Records'], summary: 'Create medical record', requestBody: { required: true, content: { 'application/json': { schema: { type: 'object', required: ['patientId', 'diagnosis'], properties: { patientId: { type: 'string' }, diagnosis: { type: 'string' }, treatment: { type: 'string' }, consultationId: { type: 'string' } } } } } }, responses: { 201: { description: 'Record created' } } },
      },
      '/users/consultations/{consultationId}/notes': {
        get: { tags: ['Consultations'], summary: 'Get consultation notes', parameters: [{ in: 'path', name: 'consultationId', required: true, schema: { type: 'string' } }], responses: { 200: { description: 'Notes data' } } },
        put: { tags: ['Consultations'], summary: 'Update consultation notes (doctor only)', parameters: [{ in: 'path', name: 'consultationId', required: true, schema: { type: 'string' } }], requestBody: { required: true, content: { 'application/json': { schema: { type: 'object', properties: { notes: { type: 'string' } } } } } }, responses: { 200: { description: 'Notes updated' } } },
      },
      '/users/chats/{chatId}/search': {
        get: { tags: ['Chat'], summary: 'Search messages in a chat', parameters: [{ in: 'path', name: 'chatId', required: true, schema: { type: 'string' } }, { in: 'query', name: 'q', required: true, schema: { type: 'string', minLength: 2 } }], responses: { 200: { description: 'Matching messages' } } },
      },
      '/users/patients/{patientId}/export': {
        get: { tags: ['GDPR'], summary: 'Export all patient data (JSON)', parameters: [{ in: 'path', name: 'patientId', required: true, schema: { type: 'string' } }], responses: { 200: { description: 'Patient data JSON file' } } },
      },
      '/users/admin/audit-logs': {
        get: { tags: ['Admin'], summary: 'Get HIPAA audit logs', parameters: [{ in: 'query', name: 'userId', schema: { type: 'string' } }, { in: 'query', name: 'resourceType', schema: { type: 'string' } }, { in: 'query', name: 'startDate', schema: { type: 'string' } }, { in: 'query', name: 'endDate', schema: { type: 'string' } }], responses: { 200: { description: 'Audit logs' } } },
      },
      '/users/reminders/upcoming': {
        get: { tags: ['Reminders'], summary: 'Trigger appointment reminders', parameters: [{ in: 'query', name: 'windowMinutes', schema: { type: 'integer', default: 30 } }], responses: { 200: { description: 'Reminder count' } } },
      },
      '/calls/initiate': {
        post: { tags: ['Calls'], summary: 'Initiate a call', requestBody: { required: true, content: { 'application/json': { schema: { type: 'object', required: ['recipientId', 'type'], properties: { recipientId: { type: 'string' }, type: { type: 'string', enum: ['audio', 'video'] }, initiatorName: { type: 'string' } } } } } }, responses: { 200: { description: 'Call initiated' } } },
      },
      '/prescriptions': {
        get: { tags: ['Prescriptions'], summary: 'List prescriptions', responses: { 200: { description: 'Prescription list' } } },
        post: { tags: ['Prescriptions'], summary: 'Create prescription (doctor only)', requestBody: { required: true, content: { 'application/json': { schema: { type: 'object', required: ['patientId', 'diagnosis', 'medications'], properties: { patientId: { type: 'string' }, diagnosis: { type: 'string' }, medications: { type: 'array', items: { type: 'object' } }, notes: { type: 'string' } } } } } }, responses: { 201: { description: 'Created' } } },
      },
    },
  },
  apis: [], // We define paths inline above
};

const swaggerSpec = swaggerJsdoc(options);

module.exports = swaggerSpec;
