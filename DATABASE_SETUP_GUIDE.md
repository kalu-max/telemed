# PostgreSQL + Firebase Integration Guide

## Overview
This guide walks you through setting up PostgreSQL for persistent data storage and Firebase for authentication and real-time features.

---

## 1. PostgreSQL Setup

### Option A: Install PostgreSQL Locally (Windows)
1. Download PostgreSQL installer from https://www.postgresql.org/download/windows/
2. Run the installer and follow the setup wizard
3. Choose a password for the `postgres` user (remember this!)
4. Keep the default port `5432`

### Option B: Use a Cloud PostgreSQL Service
- **Amazon RDS**: https://console.aws.amazon.com/rds/
- **Google Cloud SQL**: https://cloud.google.com/sql
- **Heroku Postgres**: https://www.heroku.com/postgres
- **Azure Database**: https://azure.microsoft.com/en-us/products/postgresql/

### Option C: Use Docker
```bash
docker run --name telemedicine-db \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=yourPassword \
  -e POSTGRES_DB=telemedicine_db \
  -p 5432:5432 \
  -d postgres:15
```

### Verify PostgreSQL Connection
```bash
psql -h localhost -U postgres -d telemedicine_db
```

---

## 2. Configure Environment Variables

Create a `.env` file in `telemedicine_backend/` with PostgreSQL credentials:

```env
# PostgreSQL Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=telemedicine_db
DB_USER=postgres
DB_PASSWORD=your_password_here

# Firebase Configuration (see Section 3)
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CONFIG_PATH=./firebaseConfig.json
```

---

## 3. Firebase Setup

### Step 1: Create Firebase Project
1. Go to https://console.firebase.google.com/
2. Click "Add project"
3. Enter project name: `telemedicine-app`
4. Enable Google Analytics (optional)
5. Create the project

### Step 2: Get Service Account Key
1. In Firebase Console, go to **Settings** (⚙️ icon)
2. Click **Service Accounts**
3. Click **Generate New Private Key**
4. Save the JSON file as `firebaseConfig.json` in the backend root

**WARNING:** Never commit `firebaseConfig.json` to Git! Add it to `.gitignore`

### Step 3: Enable Required Firebase Services
In Firebase Console:

1. **Authentication**
   - Click **Build** → **Authentication**
   - Click **Get Started**
   - Enable: Email/Password
   - (Optional) Enable: Google Sign-In, Phone Number

2. **Firestore Database**
   - Click **Build** → **Firestore Database**
   - Click **Create Database**
   - Start in **Production mode** (for development use test mode)
   - Select region close to users

3. **Realtime Database** (optional)
   - Click **Build** → **Realtime Database**
   - Click **Create Database**
   - Start in **Locked mode**

4. **Storage** (for file uploads)
   - Click **Build** → **Storage**
   - Click **Get Started**
   - Start in **Locked mode**

---

## 4. Install Dependencies

Run from `telemedicine_backend/`:

```bash
npm install
```

This installs:
- `sequelize` - ORM for PostgreSQL
- `pg` - PostgreSQL driver
- `firebase-admin` - Firebase Admin SDK

---

## 5. Initialize the Database

### Create Database Tables
```bash
npm run dev
```

The server will:
1. Connect to PostgreSQL
2. Run `syncDatabase()`
3. Create all tables defined in [server/models/index.js](server/models/index.js)

### Verify Tables Created
```bash
psql -h localhost -U postgres -d telemedicine_db

# In psql:
\dt  # List tables
\d users  # Show users table schema
```

---

## 6. Usage Examples

### Using PostgreSQL

```javascript
// In your API routes
const { User, Doctor, Consultation } = require('../models');

// Create a patient
const patient = await User.create({
  userId: `user_${Date.now()}`,
  email: 'patient@example.com',
  password: hashedPassword,
  name: 'John Doe',
  role: 'patient'
});

// Find a doctor
const doctor = await Doctor.findOne({
  where: { specialization: 'Cardiology' }
});

// Create a consultation
const consultation = await Consultation.create({
  consultationId: `consult_${Date.now()}`,
  patientId: patient.userId,
  doctorId: doctor.userId,
  scheduledTime: new Date(),
  status: 'scheduled'
});

// Query with associations
const fullConsultation = await Consultation.findByPk(consultationId, {
  include: [
    { association: 'patient', include: ['Patient'] },
    { association: 'Doctor' }
  ]
});
```

### Using Firestore

```javascript
const { firestore } = require('../config/firebase');

// Store real-time chat messages
await firestore.set('chats', 'consult_123', {
  messages: [
    { sender: 'doctor_1', text: 'How are you?', timestamp: Date.now() }
  ],
  participants: ['patient_1', 'doctor_1']
});

// Get chat history
const chat = await firestore.get('chats', 'consult_123');

// Query doctors with 5-star ratings
const topDoctors = await firestore.query('doctors', {
  rating: 5
});

// Batch update multiple records
await firestore.batch([
  {
    type: 'set',
    collection: 'notifications',
    docId: 'notif_1',
    data: { message: 'Appointment confirmed', read: false }
  },
  {
    type: 'set',
    collection: 'notifications',
    docId: 'notif_2',
    data: { message: 'Doctor accepted', read: false }
  }
]);
```

### Using Firebase Authentication

```javascript
const { firebaseAuth } = require('../config/firebase');

// Create a Firebase user
const firebaseUser = await firebaseAuth.createUser(
  'patient@example.com',
  'password123'
);

// Get Firebase user by UID
const user = await firebaseAuth.getUser(firebaseUser.uid);

// Generate custom token for client login
const token = await firebaseAuth.generateIdToken(firebaseUser.uid);

// Verify client token
const decoded = await firebaseAuth.verifyToken(clientToken);
```

---

## 7. Database Schema

### Users Table
```
users (PostgreSQL)
├── userId (PK)
├── email (UNIQUE)
├── password (hashed)
├── name
├── role (patient | doctor | admin)
├── isOnline
├── phone
├── avatar
├── lastLogin
└── timestamps
```

### Doctors Table
```
doctors (PostgreSQL)
├── userId (FK → users.userId)
├── specialization
├── bio
├── licenseNumber
├── yearsOfExperience
├── rating
├── consultationFee
├── isAvailable
├── totalConsultations
└── timestamps
```

### Patients Table
```
patients (PostgreSQL)
├── userId (FK → users.userId)
├── dateOfBirth
├── gender
├── medicalHistory
├── emergencyContact
├── allergies
├── currentMedications
├── insuranceProvider
├── insurancePolicyNumber
└── timestamps
```

### Consultations Table
```
consultations (PostgreSQL)
├── consultationId (PK)
├── patientId (FK)
├── doctorId (FK)
├── scheduledTime
├── startTime
├── endTime
├── status (scheduled | ongoing | completed | cancelled)
├── reason
├── notes
├── prescription
├── recordingUrl
└── timestamps
```

### Firebase Collections (Examples)
- `chats/{consultationId}/messages` - Real-time messages
- `notifications/{userId}/items` - User notifications
- `activeUsers/{userId}` - Online status tracking
- `consultationRooms/{consultationId}` - Video call data

---

## 8. Troubleshooting

### PostgreSQL Connection Error
```
Error: connect ECONNREFUSED 127.0.0.1:5432
```
**Solution:**
- Check PostgreSQL is running: `pg_isready`
- Verify credentials in `.env`
- Try: `psql -h localhost -U postgres`

### Firebase Not Initialized
```
⚠️ Firebase initialization skipped: Cannot find module 'firebaseConfig.json'
```
**Solution:**
- Copy `firebaseConfig.example.json` to `firebaseConfig.json`
- Get real credentials from Firebase Console
- Or set `FIREBASE_CONFIG` environment variable with JSON string

### Module Not Found: Sequelize/pg
```
Error: Cannot find module 'sequelize'
```
**Solution:**
- Run: `npm install`
- Verify package.json updated

### Database Sync Fails
```
Error: Accesss denied for user 'postgres'@'localhost'
```
**Solution:**
- Check DB_USER and DB_PASSWORD in `.env`
- Ensure PostgreSQL user exists: `createuser -U postgres -P telemedicine_user`
- Test connection: `psql -h localhost -U telemedicine_user -d telemedicine_db`

---

## 9. Production Deployment

### PostgreSQL (Production)
- Use managed database (AWS RDS, Google Cloud SQL)
- Enable SSL connections
- Set strong passwords
- Enable backups
- Use connection pooling (Sequelize pool settings)

### Firebase (Production)
- Enable Firestore security rules
- Restrict authentication methods
- Monitor usage in Firebase Console
- Set Firebase pricing alerts

### Environment Variables
Use your hosting platform's secrets management:
- Heroku: `heroku config:set DB_HOST=...`
- AWS Lambda: Use AWS Secrets Manager
- Google Cloud: Use Secret Manager
- Azure: Use Key Vault

---

## 10. Quick Start Commands

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Run tests
npm test

# Production start
npm start

# Check PostgreSQL
psql -h localhost -U postgres -d telemedicine_db -c "SELECT version();"
```

---

## Resources

- PostgreSQL Docs: https://www.postgresql.org/docs/
- Sequelize Docs: https://sequelize.org/
- Firebase Admin SDK: https://firebase.google.com/docs/database/admin/start
- Firestore: https://firebase.google.com/docs/firestore
