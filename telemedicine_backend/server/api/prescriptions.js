const express = require('express');

const router = express.Router();

// In-memory prescription store for the lightweight auth/user setup in this backend.
const prescriptions = {};
const templatesByDoctor = {};

function getUserById(userId) {
  try {
    const { users } = require('./auth');
    return Object.values(users).find((u) => u.userId === userId) || null;
  } catch (_) {
    return null;
  }
}

function canAccessPrescription(user, prescription) {
  if (!user) return false;
  if (user.role === 'admin') return true;
  return prescription.patientId === user.userId || prescription.doctorId === user.userId;
}

router.get('/', (req, res) => {
  const requester = req.user;
  if (!requester) return res.status(401).json({ error: 'Unauthorized' });

  const list = Object.values(prescriptions).filter((rx) => {
    if (requester.role === 'doctor') return rx.doctorId === requester.userId;
    if (requester.role === 'patient') return rx.patientId === requester.userId;
    return true;
  });

  list.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

  res.json({
    success: true,
    count: list.length,
    prescriptions: list,
    data: list,
  });
});

router.post('/', (req, res) => {
  const requester = req.user;
  if (!requester) return res.status(401).json({ error: 'Unauthorized' });
  if (requester.role !== 'doctor' && requester.role !== 'admin') {
    return res.status(403).json({ error: 'Only doctors can create prescriptions' });
  }

  const {
    patientId,
    patientName,
    diagnosis,
    notes,
    medications,
    medicines,
    consultationId,
    consultationDate,
  } = req.body;

  if (!patientId || !diagnosis) {
    return res.status(400).json({ error: 'patientId and diagnosis are required' });
  }

  const patientUser = getUserById(patientId);
  const doctorUser = getUserById(requester.userId);

  const normalizedMeds = Array.isArray(medications)
    ? medications
    : Array.isArray(medicines)
      ? medicines
      : [];

  const prescriptionId = `rx_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  const now = new Date().toISOString();

  const prescription = {
    prescriptionId,
    patientId,
    patientName: patientName || patientUser?.name || patientId,
    doctorId: requester.userId,
    doctorName: requester.name || doctorUser?.name || 'Doctor',
    diagnosis,
    notes: notes || '',
    medications: normalizedMeds,
    consultationId: consultationId || null,
    consultationDate: consultationDate || null,
    status: 'active',
    patientViewed: false,
    createdAt: now,
    updatedAt: now,
  };

  prescriptions[prescriptionId] = prescription;

  res.status(201).json({
    success: true,
    message: 'Prescription created successfully',
    prescription,
    data: prescription,
  });
});

router.get('/templates', (req, res) => {
  const requester = req.user;
  if (!requester) return res.status(401).json({ error: 'Unauthorized' });
  if (requester.role !== 'doctor' && requester.role !== 'admin') {
    return res.status(403).json({ error: 'Only doctors can access templates' });
  }

  const list = templatesByDoctor[requester.userId] || [];
  res.json({ success: true, data: list });
});

router.post('/templates', (req, res) => {
  const requester = req.user;
  if (!requester) return res.status(401).json({ error: 'Unauthorized' });
  if (requester.role !== 'doctor' && requester.role !== 'admin') {
    return res.status(403).json({ error: 'Only doctors can create templates' });
  }

  const { templateName, templateDescription, medicines, diagnosis, additionalInstructions, isPublic } = req.body;
  if (!templateName) {
    return res.status(400).json({ error: 'templateName is required' });
  }

  if (!templatesByDoctor[requester.userId]) {
    templatesByDoctor[requester.userId] = [];
  }

  const template = {
    templateId: `tpl_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
    doctorId: requester.userId,
    templateName,
    templateDescription: templateDescription || '',
    medicines: Array.isArray(medicines) ? medicines : [],
    diagnosis: diagnosis || '',
    additionalInstructions: additionalInstructions || '',
    isPublic: Boolean(isPublic),
    createdAt: new Date().toISOString(),
  };

  templatesByDoctor[requester.userId].push(template);
  res.status(201).json({ success: true, data: template });
});

router.get('/:prescriptionId', (req, res) => {
  const requester = req.user;
  if (!requester) return res.status(401).json({ error: 'Unauthorized' });

  const { prescriptionId } = req.params;
  const prescription = prescriptions[prescriptionId];
  if (!prescription) {
    return res.status(404).json({ error: 'Prescription not found' });
  }

  if (!canAccessPrescription(requester, prescription)) {
    return res.status(403).json({ error: 'Access denied' });
  }

  res.json({ success: true, prescription, data: prescription });
});

router.put('/:prescriptionId', (req, res) => {
  const requester = req.user;
  if (!requester) return res.status(401).json({ error: 'Unauthorized' });

  const { prescriptionId } = req.params;
  const prescription = prescriptions[prescriptionId];
  if (!prescription) {
    return res.status(404).json({ error: 'Prescription not found' });
  }

  if (requester.role !== 'admin' && prescription.doctorId !== requester.userId) {
    return res.status(403).json({ error: 'Only the issuing doctor can update this prescription' });
  }

  const { status, diagnosis, notes, medications } = req.body;
  if (status) prescription.status = status;
  if (diagnosis) prescription.diagnosis = diagnosis;
  if (typeof notes === 'string') prescription.notes = notes;
  if (Array.isArray(medications)) prescription.medications = medications;
  prescription.updatedAt = new Date().toISOString();

  res.json({ success: true, prescription, data: prescription });
});

router.post('/:prescriptionId/mark-viewed', (req, res) => {
  const requester = req.user;
  if (!requester) return res.status(401).json({ error: 'Unauthorized' });

  const { prescriptionId } = req.params;
  const prescription = prescriptions[prescriptionId];
  if (!prescription) {
    return res.status(404).json({ error: 'Prescription not found' });
  }

  if (requester.role !== 'admin' && prescription.patientId !== requester.userId) {
    return res.status(403).json({ error: 'Only the patient can mark this as viewed' });
  }

  prescription.patientViewed = true;
  prescription.viewedAt = new Date().toISOString();
  prescription.updatedAt = new Date().toISOString();

  res.json({ success: true, prescription, data: prescription });
});

router.get('/:prescriptionId/pdf', (req, res) => {
  const requester = req.user;
  if (!requester) return res.status(401).json({ error: 'Unauthorized' });

  const { prescriptionId } = req.params;
  const prescription = prescriptions[prescriptionId];
  if (!prescription) {
    return res.status(404).json({ error: 'Prescription not found' });
  }

  if (!canAccessPrescription(requester, prescription)) {
    return res.status(403).json({ error: 'Access denied' });
  }

  const meds = Array.isArray(prescription.medications) ? prescription.medications : [];
  const medsRows = meds.length
    ? meds.map((m, i) => `
        <tr>
          <td>${i + 1}</td>
          <td>${escapeHtml(m.name || m.medicineName || '')}</td>
          <td>${escapeHtml(m.dosage || m.dose || '')}</td>
          <td>${escapeHtml(m.frequency || '')}</td>
          <td>${escapeHtml(m.duration || '')}</td>
          <td>${escapeHtml(m.instructions || m.notes || '')}</td>
        </tr>`).join('')
    : '<tr><td colspan="6" style="text-align:center;color:#777">No medications listed</td></tr>';

  const issuedDate = prescription.createdAt
    ? new Date(prescription.createdAt).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })
    : 'N/A';

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Prescription - ${escapeHtml(prescriptionId)}</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: Arial, sans-serif; color: #222; background: #fff; padding: 32px; }
  .header { display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid #0d9488; padding-bottom: 16px; margin-bottom: 24px; }
  .clinic-name { font-size: 24px; font-weight: bold; color: #0d9488; }
  .clinic-sub { font-size: 13px; color: #555; margin-top: 4px; }
  .rx-id { font-size: 12px; color: #888; text-align: right; }
  .section { margin-bottom: 20px; }
  .section-title { font-size: 13px; font-weight: bold; color: #0d9488; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px; }
  .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px 24px; }
  .info-row { font-size: 14px; }
  .info-label { color: #777; font-size: 12px; }
  .diagnosis-box { background: #f0fdfa; border-left: 4px solid #0d9488; padding: 10px 14px; border-radius: 4px; font-size: 14px; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  th { background: #0d9488; color: #fff; padding: 8px 10px; text-align: left; }
  td { border-bottom: 1px solid #e5e7eb; padding: 8px 10px; }
  tr:last-child td { border-bottom: none; }
  .notes { background: #f9fafb; border: 1px solid #e5e7eb; border-radius: 4px; padding: 10px 14px; font-size: 14px; color: #444; }
  .footer { margin-top: 40px; display: flex; justify-content: space-between; font-size: 12px; color: #888; border-top: 1px solid #e5e7eb; padding-top: 12px; }
  .signature { text-align: right; }
  .signature-line { border-top: 1px solid #555; width: 160px; margin: 40px 0 6px auto; }
  @media print {
    body { padding: 16px; }
    button { display: none; }
  }
</style>
</head>
<body>
<div class="header">
  <div>
    <div class="clinic-name">MediCare Connect</div>
    <div class="clinic-sub">Telemedicine Platform &mdash; Digital Prescription</div>
  </div>
  <div class="rx-id">
    <div><strong>Rx ID:</strong> ${escapeHtml(prescriptionId)}</div>
    <div><strong>Date:</strong> ${issuedDate}</div>
    <div><strong>Status:</strong> ${escapeHtml(prescription.status || 'active')}</div>
  </div>
</div>

<div style="display:flex;gap:32px;margin-bottom:20px;">
  <div class="section" style="flex:1">
    <div class="section-title">Patient Information</div>
    <div class="info-grid">
      <div><div class="info-label">Name</div><div class="info-row">${escapeHtml(prescription.patientName || prescription.patientId)}</div></div>
      <div><div class="info-label">Patient ID</div><div class="info-row">${escapeHtml(prescription.patientId)}</div></div>
    </div>
  </div>
  <div class="section" style="flex:1">
    <div class="section-title">Doctor Information</div>
    <div class="info-grid">
      <div><div class="info-label">Name</div><div class="info-row">Dr. ${escapeHtml(prescription.doctorName || prescription.doctorId)}</div></div>
      <div><div class="info-label">Doctor ID</div><div class="info-row">${escapeHtml(prescription.doctorId)}</div></div>
    </div>
  </div>
</div>

<div class="section">
  <div class="section-title">Diagnosis</div>
  <div class="diagnosis-box">${escapeHtml(prescription.diagnosis)}</div>
</div>

<div class="section">
  <div class="section-title">Prescribed Medications</div>
  <table>
    <thead>
      <tr>
        <th>#</th><th>Medicine</th><th>Dosage</th><th>Frequency</th><th>Duration</th><th>Instructions</th>
      </tr>
    </thead>
    <tbody>${medsRows}</tbody>
  </table>
</div>

${prescription.notes ? `<div class="section">
  <div class="section-title">Additional Notes</div>
  <div class="notes">${escapeHtml(prescription.notes)}</div>
</div>` : ''}

<div class="signature">
  <div class="signature-line"></div>
  <div>Dr. ${escapeHtml(prescription.doctorName || prescription.doctorId)}</div>
  <div style="font-size:11px;color:#888">Authorised Signature &amp; Stamp</div>
</div>

<div class="footer">
  <div>Generated: ${new Date().toLocaleString()}</div>
  <div>This is a digitally generated prescription from MediCare Connect.</div>
</div>

<div style="text-align:center;margin-top:24px">
  <button onclick="window.print()" style="background:#0d9488;color:#fff;border:none;padding:10px 28px;border-radius:6px;font-size:14px;cursor:pointer">
    &#128438; Print / Save as PDF
  </button>
</div>
</body>
</html>`;

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(html);
});

function escapeHtml(str) {
  if (str == null) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

module.exports = router;
module.exports.prescriptions = prescriptions;
