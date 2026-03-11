/**
 * Socket.IO handlers for doctor presence and availability management
 * Handles real-time presence updates, doctor discovery, and subscription management
 */

module.exports = (io, db) => {
  const presenceData = new Map(); // Store active doctor presence
  const subscriptions = new Map(); // Track which users are watching which doctors

  const presenceNamespace = io.of('/presence');

  presenceNamespace.on('connection', (socket) => {
    let userId = null;
    let userRole = null;
    const watchingDoctors = new Set();

    // Authenticate connection
    socket.on('authenticate', (data) => {
      userId = data.userId;
      userRole = data.userRole;
      socket.userId = userId;
      socket.userRole = userRole;

      console.log(`[Presence] ${userRole} ${userId} connected`);

      // If doctor, register presence
      if (userRole === 'doctor') {
        presenceData.set(userId, {
          doctorId: userId,
          status: 'online',
          lastSeen: new Date(),
          socket: socket.id,
        });

        // Broadcast to all patients that doctor is online
        presenceNamespace.emit('doctorOnline', {
          doctorId: userId,
          status: 'online',
          timestamp: new Date(),
        });
      }
    });

    // Doctor updates their presence status
    socket.on('updatePresenceStatus', async (data) => {
      if (userRole !== 'doctor') return;

      const status = data.status;
      const timestamp = new Date();

      // Update in-memory store
      if (presenceData.has(userId)) {
        const presence = presenceData.get(userId);
        const oldStatus = presence.status;
        presence.status = status;
        presence.lastSeen = timestamp;
      }

      // Update database
      try {
        await db.models.DoctorPresence.upsert({
          doctorId: userId,
          status: status,
          lastSeen: timestamp,
          isOnline: status === 'online',
        });

        // Notify all watching patients
        presenceNamespace.emit('presenceChanged', {
          doctorId: userId,
          newStatus: status,
          timestamp: timestamp,
        });

        console.log(`[Presence] Doctor ${userId} status changed to ${status}`);
      } catch (error) {
        console.error('[Presence] Error updating status:', error);
      }
    });

    // Doctor sets availability until a specific time
    socket.on('setAvailabilityUntil', async (data) => {
      if (userRole !== 'doctor') return;

      const availableUntil = new Date(data.availableUntil);

      try {
        await db.models.DoctorPresence.upsert({
          doctorId: userId,
          availableUntil: availableUntil,
        });

        presenceNamespace.emit('availabilityUpdated', {
          doctorId: userId,
          availableUntil: availableUntil,
        });

        console.log(`[Presence] Doctor ${userId} available until ${availableUntil}`);
      } catch (error) {
        console.error('[Presence] Error setting availability:', error);
      }
    });

    // Doctor updates consultation type availability
    socket.on('updateConsultationType', async (data) => {
      if (userRole !== 'doctor') return;

      const consultationType = data.consultationType;

      try {
        await db.models.DoctorPresence.upsert({
          doctorId: userId,
          consultationType: consultationType,
        });

        presenceNamespace.emit('consultationTypeUpdated', {
          doctorId: userId,
          consultationType: consultationType,
        });
      } catch (error) {
        console.error('[Presence] Error updating consultation type:', error);
      }
    });

    // Patient requests to watch a doctor's presence
    socket.on('watchDoctor', (data) => {
      const doctorId = data.doctorId;
      watchingDoctors.add(doctorId);

      // Track subscriptions for broadcasting
      if (!subscriptions.has(doctorId)) {
        subscriptions.set(doctorId, new Set());
      }
      subscriptions.get(doctorId).add(socket.id);

      // Send current presence immediately
      const presence = presenceData.get(doctorId);
      if (presence) {
        socket.emit('presenceUpdate', {
          doctorId: doctorId,
          status: presence.status,
          lastSeen: presence.lastSeen,
        });
      }

      console.log(`[Presence] User ${userId} watching doctor ${doctorId}`);
    });

    // Patient stops watching doctor
    socket.on('unwatchDoctor', (data) => {
      const doctorId = data.doctorId;
      watchingDoctors.delete(doctorId);

      if (subscriptions.has(doctorId)) {
        subscriptions.get(doctorId).delete(socket.id);
      }

      console.log(`[Presence] User ${userId} stopped watching doctor ${doctorId}`);
    });

    // Patient requests list of available doctors
    socket.on('getAvailableDoctors', async (data) => {
      const specialty = data.specialty;
      const limit = data.limit || 20;

      try {
        let query = db.models.DoctorPresence.findAll({
          where: {
            status: 'online',
            isOnline: true,
          },
          limit: limit,
          order: [['availabilityScore', 'DESC']],
        });

        if (specialty) {
          query = db.models.DoctorPresence.findAll({
            where: {
              status: 'online',
              isOnline: true,
              specialty: { [db.Sequelize.Op.like]: `%${specialty}%` },
            },
            limit: limit,
            order: [['availabilityScore', 'DESC']],
          });
        }

        const doctors = await query;
        socket.emit('availableDoctors', doctors.map(d => d.toJSON()));

        console.log(`[Presence] Sent ${doctors.length} available doctors to ${userId}`);
      } catch (error) {
        console.error('[Presence] Error fetching available doctors:', error);
        socket.emit('error', { message: 'Failed to fetch available doctors' });
      }
    });

    // Sync all doctors' presence on periodic intervals
    socket.on('syncPresence', async () => {
      try {
        const allPresence = await db.models.DoctorPresence.findAll({
          where: { isOnline: true },
          order: [['availabilityScore', 'DESC']],
        });

        socket.emit('presenceSyncData', {
          doctors: allPresence.map(d => d.toJSON()),
          timestamp: new Date(),
        });
      } catch (error) {
        console.error('[Presence] Error syncing presence:', error);
      }
    });

    // Handle doctor state changes (in consultation, etc)
    socket.on('setDoctorInConsultation', async (data) => {
      if (userRole !== 'doctor') return;

      const patientId = data.patientId;
      const inConsultation = data.inConsultation;

      try {
        if (presenceData.has(userId)) {
          const presence = presenceData.get(userId);
          if (inConsultation) {
            presence.status = 'busy';
            presence.currentPatient = patientId;
          } else {
            presence.status = 'online';
            delete presence.currentPatient;
          }
          presence.lastSeen = new Date();
        }

        await db.models.DoctorPresence.update(
          {
            status: inConsultation ? 'busy' : 'online',
            currentPatientId: inConsultation ? patientId : null,
            lastSeen: new Date(),
          },
          { where: { doctorId: userId } }
        );

        presenceNamespace.emit('presenceChanged', {
          doctorId: userId,
          newStatus: inConsultation ? 'busy' : 'online',
          currentPatientId: inConsultation ? patientId : null,
          timestamp: new Date(),
        });

        console.log(`[Presence] Doctor ${userId} consultation state: ${inConsultation}`);
      } catch (error) {
        console.error('[Presence] Error updating consultation state:', error);
      }
    });

    // Handle disconnection
    socket.on('disconnect', async () => {
      if (userRole === 'doctor' && userId) {
        try {
          await db.models.DoctorPresence.update(
            {
              status: 'offline',
              isOnline: false,
              lastSeen: new Date(),
            },
            { where: { doctorId: userId } }
          );

          presenceData.delete(userId);

          // Notify subscribers
          presenceNamespace.emit('doctorOffline', {
            doctorId: userId,
            timestamp: new Date(),
          });

          console.log(`[Presence] Doctor ${userId} disconnected and marked offline`);
        } catch (error) {
          console.error('[Presence] Error handling doctor disconnection:', error);
        }
      }

      // Clean up subscriptions
      watchingDoctors.forEach(doctorId => {
        if (subscriptions.has(doctorId)) {
          subscriptions.get(doctorId).delete(socket.id);
        }
      });

      console.log(`[Presence] User ${userId} disconnected`);
    });

    // Error handling
    socket.on('error', (error) => {
      console.error('[Presence] Socket error:', error);
    });
  });

  // Periodic presence cleanup (remove stale entries)
  setInterval(() => {
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);

    presenceData.forEach((presence, doctorId) => {
      if (presence.lastSeen < fiveMinutesAgo) {
        presenceData.delete(doctorId);
        console.log(`[Presence] Cleaned up stale presence for doctor ${doctorId}`);
      }
    });
  }, 5 * 60 * 1000);

  return presenceNamespace;
};
