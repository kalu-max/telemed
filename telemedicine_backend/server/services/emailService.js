const nodemailer = require('nodemailer');
const logger = require('../utils/logger');

// Create transporter from environment configuration
let transporter;

function getTransporter() {
  if (transporter) return transporter;

  const host = process.env.SMTP_HOST;
  const port = parseInt(process.env.SMTP_PORT || '587', 10);
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;

  if (!host || !user || !pass) {
    logger.warn('SMTP not configured (set SMTP_HOST, SMTP_USER, SMTP_PASS). Emails will be logged only.');
    return null;
  }

  transporter = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: { user, pass },
  });

  logger.info(`SMTP transport configured: ${host}:${port}`);
  return transporter;
}

/**
 * Send an OTP email for password reset.
 * Falls back to console logging when SMTP is not configured.
 */
async function sendOtpEmail(recipientEmail, otp) {
  const transport = getTransporter();
  const fromAddress = process.env.SMTP_FROM || process.env.SMTP_USER || 'noreply@telemedicine.app';

  if (!transport) {
    logger.info(`[DEV] OTP for ${recipientEmail}: ${otp}`);
    return { sent: false, reason: 'SMTP not configured' };
  }

  const mailOptions = {
    from: `"Telemedicine App" <${fromAddress}>`,
    to: recipientEmail,
    subject: 'Your Password Reset OTP',
    text: `Your one-time password (OTP) is: ${otp}\n\nThis code expires in 10 minutes. If you did not request this, please ignore this email.`,
    html: `
      <div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;padding:24px;border:1px solid #e0e0e0;border-radius:8px;">
        <h2 style="color:#00796b;">Telemedicine App</h2>
        <p>Your one-time password (OTP) for password reset is:</p>
        <div style="font-size:32px;font-weight:bold;letter-spacing:6px;text-align:center;padding:16px;background:#f5f5f5;border-radius:8px;margin:16px 0;">${otp}</div>
        <p style="color:#757575;font-size:13px;">This code expires in 10&nbsp;minutes. If you did not request this, please ignore this email.</p>
      </div>
    `,
  };

  try {
    const info = await transport.sendMail(mailOptions);
    logger.info(`OTP email sent to ${recipientEmail} (messageId: ${info.messageId})`);
    return { sent: true, messageId: info.messageId };
  } catch (err) {
    logger.error(`Failed to send OTP email to ${recipientEmail}: ${err.message}`);
    // Fall back to logging so the OTP is still usable in dev
    logger.info(`[DEV-FALLBACK] OTP for ${recipientEmail}: ${otp}`);
    return { sent: false, reason: err.message };
  }
}

/**
 * Send a generic notification email.
 */
async function sendNotificationEmail(recipientEmail, subject, bodyText, bodyHtml) {
  const transport = getTransporter();
  const fromAddress = process.env.SMTP_FROM || process.env.SMTP_USER || 'noreply@telemedicine.app';

  if (!transport) {
    logger.info(`[DEV] Email to ${recipientEmail}: ${subject}`);
    return { sent: false, reason: 'SMTP not configured' };
  }

  try {
    const info = await transport.sendMail({
      from: `"Telemedicine App" <${fromAddress}>`,
      to: recipientEmail,
      subject,
      text: bodyText,
      html: bodyHtml || undefined,
    });
    logger.info(`Notification email sent to ${recipientEmail} (messageId: ${info.messageId})`);
    return { sent: true, messageId: info.messageId };
  } catch (err) {
    logger.error(`Failed to send email to ${recipientEmail}: ${err.message}`);
    return { sent: false, reason: err.message };
  }
}

module.exports = { sendOtpEmail, sendNotificationEmail };
