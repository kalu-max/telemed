# PostgreSQL + Firebase Integration - Quick Start

## What's Been Set Up

✅ **PostgreSQL Sequelize ORM** - Production-ready relational database  
✅ **Firebase Admin SDK** - Authentication, Firestore, Realtime DB, Storage  
✅ **Database Models** - User, Doctor, Patient, Consultation, MedicalRecord, Notification  
✅ **Database Configuration** - Connection pooling, migration support  
✅ **Environment Templates** - Ready-to-fill .env.example and firebaseConfig.example.json  
✅ **Initialization Scripts** - Automated database setup with seeding  

---

## Quick Start (5 minutes)

### 1. Install Dependencies
```bash
cd telemedicine_backend
npm install
```

### 2. Set Up PostgreSQL
**Windows:**
- Download from: https://www.postgresql.org/download/windows/
- Install with default settings
- Remember the `postgres` password

**Or use Docker:**
```bash
docker run --name telemedicine-db -e POSTGRES_PASSWORD=password -p 5432:5432 -d postgres:15
```

### 3. Configure Environment
Copy template and fill in your credentials:
```bash
cp .env.example .env
```

Edit `.env`:
```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=telemedicine_db
DB_USER=postgres
DB_PASSWORD=your_postgres_password
```

### 4. Initialize Database
```bash
npm run db:seed
```

This will:
- Create PostgreSQL tables
- Seed with sample data
- Log credentials

### 5. Start Server
```bash
npm run dev
```

Expected output:
```
✅ PostgreSQL connection established
✅ Database synchronized
✅ Firebase utilities loaded
🎥 Telemedicine Video Backend running on port 5000
```

---

## Test It Out

```bash
# Test PostgreSQL (psql must be installed)
psql -h localhost -U postgres -d telemedicine_db -c "SELECT COUNT(*) FROM users;"

# Login as sample user
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@telemedicine.com",
    "password": "admin123"
  }'
```

---

## Database Schema Overview

```
PostgreSQL Database: telemedicine_db
├── users (user ID, email, password, role)
├── doctors (profile, specialization, rating)
├── patients (medical history, allergies, medications)
├── consultations (appointments, status, notes)
├── medical_records (files, diagnosis, treatment)
└── notifications (messages, alerts)
```

---

## Default Test Credentials

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@telemedicine.com | admin123 |
| Doctor | johnson@telemedicine.com | doctor123 |
| Patient | alice@patient.com | patient123 |

---

## Firebase Setup (Optional)

### Get Firebase Credentials
1. Go to https://console.firebase.google.com/
2. Create a project called `telemedicine-app`
3. Enable: Authentication, Firestore, Realtime DB
4. Download service account JSON

### Add Credentials
```bash
# Copy downloaded JSON to project root
cp ~/Downloads/serviceAccountKey.json ./firebaseConfig.json
```

Update `.env`:
```env
FIREBASE_PROJECT_ID=your-project-id
```

---

## Common Tasks

### Reset Database
```bash
npm run db:reset
```

### View Users
```bash
psql -h localhost -U postgres -d telemedicine_db
SELECT * FROM users;
```

### Add a Doctor
```javascript
// In Node shell or API
const { User, Doctor } = require('./server/models');
const bcrypt = require('bcryptjs');

const hash = await bcrypt.hash('password123', 10);
const user = await User.create({
  userId: `user_${Date.now()}`,
  email: 'newdoctor@telemedicine.com',
  password: hash,
  name: 'Dr. New Doctor',
  role: 'doctor'
});

await Doctor.create({
  userId: user.userId,
  specialization: 'General Practice',
  yearsOfExperience: 5,
  consultationFee: 50
});
```

---

## Troubleshooting

### PostgreSQL won't connect
```bash
# Check if running
pg_isready -h localhost

# Try default password
psql -h localhost -U postgres -d postgres
```

### npm install fails
```bash
# Clear cache and reinstall
npm cache clean --force
npm install
```

### Port 5432 already in use
```bash
# Change DB_PORT in .env to 5433
# Or kill process using 5432
lsof -ti:5432 | xargs kill -9
```

---

## Next Steps

1. **Update API Routes** - Replace old auth.js with new database-backed auth
2. **Add Validation** - Add input validation to API routes
3. **Security** - Implement rate limiting, CORS, HTTPS
4. **Testing** - Write unit and integration tests
5. **Deployment** - Deploy to production with managed databases

See [DATABASE_SETUP_GUIDE.md](../DATABASE_SETUP_GUIDE.md) for detailed instructions.

---

## Files Added/Modified

**New Files:**
- `server/config/database.js` - PostgreSQL setup
- `server/config/firebase.js` - Firebase setup
- `server/models/index.js` - Data models
- `scripts/initDatabase.js` - Database initialization
- `DATABASE_SETUP_GUIDE.md` - Complete guide
- `firebaseConfig.example.json` - Firebase template

**Modified Files:**
- `server.js` - Database initialization
- `.env.example` - PostgreSQL/Firebase config
- `package.json` - New dependencies + scripts

---

**You're all set!** Everything is ready to use. Start with `npm run dev` 🚀
