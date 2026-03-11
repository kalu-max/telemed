/**
 * Socket.IO handlers for prescription management
 * Handles real-time prescription creation, updates, and sync
 */

module.exports = (io, db) => {
  const prescriptionNamespace = io.of('/prescription');

  prescriptionNamespace.on('connection', (socket) => {
    let userId = null;
    let userRole = null;

    socket.on('authenticate', (data) => {
      userId = data.userId;
      userRole = data.userRole;
      socket.userId = userId;
      socket.userRole = userRole;

      console.log(`[Prescription] ${userRole} ${userId} connected`);
    });

    // Doctor issues a prescription during consultation
    socket.on('issuePrescription', async (data) => {
      if (userRole !== 'doctor') return;

      try {
        // Create prescription
        const prescription = await db.models.Prescription.create({
          prescriptionId: data.prescriptionId,
          patientId: data.patientId,
          patientName: data.patientName,
          patientEmail: data.patientEmail,
          patientPhone: data.patientPhone,
          doctorId: userId,
          doctorName: data.doctorName,
          doctorLicenseNumber: data.doctorLicenseNumber,
          consultationId: data.consultationId,
          consultationDate: data.consultationDate,
          symptoms: data.symptoms,
          diagnosis: data.diagnosis,
          clinicalNotes: data.clinicalNotes,
          status: 'active',
          issuedAt: new Date(),
          expiryDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
          isEncrypted: true,
          patientViewed: false,
          createdAt: new Date(),
        });

        // Create medicines for prescription
        if (data.medicines && Array.isArray(data.medicines)) {
          for (const med of data.medicines) {
            await db.models.Medicine.create({
              medicineId: med.medicineId,
              prescriptionId: prescription.prescriptionId,
              medicineName: med.medicineName,
              genericName: med.genericName,
              dosage: med.dosage,
              dosageUnit: med.dosageUnit,
              frequency: med.frequency,
              durationDays: med.durationDays,
              instructions: med.instructions,
              sideEffects: JSON.stringify(med.sideEffects || []),
              contraindications: JSON.stringify(med.contraindications || []),
              requiresRefill: med.requiresRefill,
              manufacturerName: med.manufacturerName,
              price: med.price,
            });
          }
        }

        // Store lab tests if provided
        if (data.labTests && Array.isArray(data.labTests)) {
          await db.models.Prescription.update(
            { labTests: JSON.stringify(data.labTests) },
            { where: { prescriptionId: prescription.prescriptionId } }
          );
        }

        // Notify patient of new prescription
        prescriptionNamespace
          .to(`patient_${data.patientId}`)
          .emit('prescriptionIssued', prescription.toJSON());

        // Acknowledge to doctor
        socket.emit('prescriptionCreated', { prescriptionId: prescription.prescriptionId });

        console.log(`[Prescription] New prescription ${prescription.prescriptionId} issued`);
      } catch (error) {
        console.error('[Prescription] Error creating prescription:', error);
        socket.emit('error', { message: 'Failed to create prescription' });
      }
    });

    // Update prescription
    socket.on('updatePrescription', async (data) => {
      try {
        await db.models.Prescription.update(
          {
            symptoms: data.symptoms,
            diagnosis: data.diagnosis,
            clinicalNotes: data.clinicalNotes,
            status: data.status,
          },
          { where: { prescriptionId: data.prescriptionId } }
        );

        // Notify patient
        const prescription = await db.models.Prescription.findByPk(data.prescriptionId);

        prescriptionNamespace
          .to(`patient_${prescription.patientId}`)
          .emit('prescriptionUpdated', prescription.toJSON());

        socket.emit('prescriptionUpdated', { prescriptionId: data.prescriptionId });

        console.log(`[Prescription] Prescription ${data.prescriptionId} updated`);
      } catch (error) {
        console.error('[Prescription] Error updating prescription:', error);
        socket.emit('error', { message: 'Failed to update prescription' });
      }
    });

    // Patient marks prescription as viewed
    socket.on('markPrescriptionViewed', async (data) => {
      try {
        await db.models.Prescription.update(
          {
            patientViewed: true,
            viewedAt: new Date(),
          },
          { where: { prescriptionId: data.prescriptionId } }
        );

        // Notify doctor
        const prescription = await db.models.Prescription.findByPk(data.prescriptionId);
        prescriptionNamespace
          .to(`doctor_${prescription.doctorId}`)
          .emit('patientViewedPrescription', { prescriptionId: data.prescriptionId });

        console.log(`[Prescription] Prescription ${data.prescriptionId} marked as viewed`);
      } catch (error) {
        console.error('[Prescription] Error marking prescription as viewed:', error);
      }
    });

    // Get user's prescriptions
    socket.on('syncPrescriptions', async (data) => {
      try {
        let prescriptions;

        if (userRole === 'patient') {
          prescriptions = await db.models.Prescription.findAll({
            where: { patientId: userId },
            include: [{ model: db.models.Medicine }],
            order: [['issuedAt', 'DESC']],
          });
        } else if (userRole === 'doctor') {
          prescriptions = await db.models.Prescription.findAll({
            where: { doctorId: userId },
            include: [{ model: db.models.Medicine }],
            order: [['issuedAt', 'DESC']],
          });
        }

        socket.emit('prescriptionsList', prescriptions.map(p => p.toJSON()));

        console.log(`[Prescription] Synced ${prescriptions.length} prescriptions for ${userRole} ${userId}`);
      } catch (error) {
        console.error('[Prescription] Error syncing prescriptions:', error);
        socket.emit('error', { message: 'Failed to sync prescriptions' });
      }
    });

    // Generate prescription PDF
    socket.on('generatePrescriptionPdf', async (data) => {
      try {
        const prescription = await db.models.Prescription.findByPk(data.prescriptionId, {
          include: [{ model: db.models.Medicine }],
        });

        if (!prescription) {
          socket.emit('error', { message: 'Prescription not found' });
          return;
        }

        // In production, use a PDF library like pdfkit or puppeteer
        // For now, return placeholder
        const pdfUrl = `/prescriptions/pdf/${prescription.prescriptionId}.pdf`;

        // Update prescription with PDF URL
        await db.models.Prescription.update(
          { pdfUrl: pdfUrl },
          { where: { prescriptionId: prescription.prescriptionId } }
        );

        socket.emit('prescriptionPdfReady', { pdfUrl: pdfUrl });

        console.log(`[Prescription] PDF generated for prescription ${data.prescriptionId}`);
      } catch (error) {
        console.error('[Prescription] Error generating PDF:', error);
        socket.emit('error', { message: 'Failed to generate PDF' });
      }
    });

    // Set medicine reminder (for patient)
    socket.on('setMedicineReminder', async (data) => {
      if (userRole !== 'patient') return;

      try {
        const reminder = await db.models.MedicineReminder.create({
          reminderId: data.reminderId,
          prescriptionId: data.prescriptionId,
          medicineId: data.medicineId,
          medicineName: data.medicineName,
          reminderTimes: JSON.stringify(data.reminderTimes),
          isActive: true,
          takenAt: JSON.stringify([]),
          missedAt: JSON.stringify([]),
          createdAt: new Date(),
        });

        socket.emit('medicineReminderSet', { reminderId: reminder.reminderId });

        console.log(`[Prescription] Reminder set for ${data.medicineName}`);
      } catch (error) {
        console.error('[Prescription] Error setting reminder:', error);
        socket.emit('error', { message: 'Failed to set reminder' });
      }
    });

    // Mark medicine as taken
    socket.on('medicineMarkedAsTaken', async (data) => {
      try {
        const reminder = await db.models.MedicineReminder.findByPk(data.reminderId);

        if (reminder) {
          const takenAt = JSON.parse(reminder.takenAt || '[]');
          takenAt.push(new Date());

          await db.models.MedicineReminder.update(
            { takenAt: JSON.stringify(takenAt) },
            { where: { reminderId: data.reminderId } }
          );

          // Calculate and update adherence
          const prescription = await db.models.Prescription.findByPk(reminder.prescriptionId);
          const adherence = (takenAt.length / 10) * 100; // Example calculation

          console.log(`[Prescription] Medicine marked as taken, adherence: ${adherence}%`);
        }
      } catch (error) {
        console.error('[Prescription] Error marking medicine as taken:', error);
      }
    });

    // Save prescription template (for doctors)
    socket.on('createPrescriptionTemplate', async (data) => {
      if (userRole !== 'doctor') return;

      try {
        const template = await db.models.PrescriptionTemplate.create({
          templateId: data.templateId,
          doctorId: userId,
          templateName: data.templateName,
          templateDescription: data.templateDescription,
          medicines: JSON.stringify(data.medicines || []),
          diagnosis: data.diagnosis,
          additionalInstructions: data.additionalInstructions,
          createdAt: new Date(),
          isPublic: data.isPublic || false,
        });

        socket.emit('templateCreated', { templateId: template.templateId });

        console.log(`[Prescription] Template ${template.templateName} created`);
      } catch (error) {
        console.error('[Prescription] Error creating template:', error);
        socket.emit('error', { message: 'Failed to create template' });
      }
    });

    // Handle disconnection
    socket.on('disconnect', () => {
      console.log(`[Prescription] User ${userId} disconnected`);
    });
  });

  return prescriptionNamespace;
};
