# Doctor Telemedicine App

> **Note:** The doctor app is integrated with the hosted backend (`https://telemed-backend.onrender.com`) by default. Mock data has been removed and appointments are fetched from the server using the built-in `TeleMedicineApiClient`.

> If the app still points to a local server, reset the server URL in Settings.


This Flutter app is for doctors to manage teleconsultations, appointments, and video calls. It connects to the same backend as the patient app.

## How to run

1. Navigate to this directory:
   ```
   cd telemedicine_app/doctor_app
   ```
2. Get dependencies:
   ```
   flutter pub get
   ```
3. Run the app:
   ```
   flutter run -d chrome   # or use an emulator/device
   ```

## Features
- Doctor login
- View and confirm appointments
- Video call with patients (WebRTC)
- View patient details
- Upload/view reports
- Optimized for low bandwidth, high resolution

## Next steps
- Implement UI and connect to backend endpoints
- Reuse and adapt code from the patient app as needed
