/**
 * Appointment Reminder Scheduler
 *
 * Runs a periodic check for upcoming appointments and sends
 * push notifications + in-app notifications to both patient and doctor.
 *
 * Triggered every 5 minutes. Sends reminders at 30-minute and 5-minute windows.
 */

const { Op } = require('sequelize');
const logger = require('../utils/logger');

let reminderInterval = null;

function startReminderScheduler(models, pushNotification) {
  const { Consultation } = models;
  const CHECK_INTERVAL_MS = 5 * 60 * 1000; // 5 minutes
  const REMINDER_WINDOWS = [30, 5]; // minutes before appointment

  // Track already-sent reminders to avoid duplicates
  const sentReminders = new Set();

  // Cleanup old entries every hour
  setInterval(() => {
    const cutoff = Date.now() - 2 * 60 * 60 * 1000;
    for (const key of sentReminders) {
      const ts = parseInt(key.split('|')[1] || '0');
      if (ts < cutoff) sentReminders.delete(key);
    }
  }, 60 * 60 * 1000);

  async function checkReminders() {
    try {
      const now = new Date();

      for (const windowMin of REMINDER_WINDOWS) {
        const windowStart = new Date(now.getTime() + (windowMin - 2.5) * 60000);
        const windowEnd = new Date(now.getTime() + (windowMin + 2.5) * 60000);

        const upcoming = await Consultation.findAll({
          where: {
            scheduledTime: { [Op.between]: [windowStart, windowEnd] },
            status: { [Op.in]: ['scheduled', 'pending'] },
          },
        });

        for (const appt of upcoming) {
          const key = `${appt.consultationId}|${now.getTime()}|${windowMin}`;
          const dedupKey = `${appt.consultationId}|${windowMin}`;
          if (sentReminders.has(dedupKey)) continue;
          sentReminders.add(dedupKey);

          const label = windowMin >= 30 ? `${windowMin} minutes` : `${windowMin} minutes`;

          if (appt.patientId) {
            await pushNotification(
              appt.patientId,
              `⏰ Reminder: Your appointment with ${appt.doctorName || 'your doctor'} starts in ${label}`
            );
          }
          if (appt.doctorId) {
            await pushNotification(
              appt.doctorId,
              `⏰ Reminder: Appointment with ${appt.patientName || 'patient'} starts in ${label}`
            );
          }
          logger.info(`Reminder sent for consultation ${appt.consultationId} (${windowMin}min window)`);
        }
      }
    } catch (e) {
      logger.warn(`Reminder check failed: ${e.message}`);
    }
  }

  // Initial check after 10 seconds
  setTimeout(checkReminders, 10000);
  reminderInterval = setInterval(checkReminders, CHECK_INTERVAL_MS);

  logger.info('📅 Appointment reminder scheduler started (every 5 minutes)');
  return reminderInterval;
}

function stopReminderScheduler() {
  if (reminderInterval) {
    clearInterval(reminderInterval);
    reminderInterval = null;
  }
}

module.exports = { startReminderScheduler, stopReminderScheduler };
