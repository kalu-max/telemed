const twilio = require('twilio');

const DEFAULT_ICE_SERVERS = Object.freeze([
  {
    urls: ['stun:stun.l.google.com:19302'],
  },
  {
    urls: ['stun:stun1.l.google.com:19302'],
  },
]);

function cloneIceServer(server) {
  return {
    ...server,
    urls: Array.isArray(server.urls) ? [...server.urls] : server.urls,
  };
}

function getDefaultIceServers() {
  return DEFAULT_ICE_SERVERS.map(cloneIceServer);
}

function parseTtl(ttlSeconds) {
  const parsed = Number.parseInt(`${ttlSeconds ?? ''}`, 10);
  if (Number.isNaN(parsed)) {
    return 3600;
  }

  return Math.min(Math.max(parsed, 60), 86400);
}

function normalizeIceServer(server) {
  const urls = server?.urls || server?.url;
  if (!urls) {
    return null;
  }

  const normalized = {
    urls: Array.isArray(urls) ? urls : [urls],
  };

  if (server.username) {
    normalized.username = server.username;
  }

  if (server.credential) {
    normalized.credential = server.credential;
  }

  return normalized;
}

function isTwilioConfigured() {
  return Boolean(
    process.env.TWILIO_ACCOUNT_SID && process.env.TWILIO_AUTH_TOKEN,
  );
}

async function fetchIceServers({ ttlSeconds } = {}) {
  const ttl = parseTtl(ttlSeconds);

  if (!isTwilioConfigured()) {
    return {
      provider: 'default',
      ttl,
      iceServers: getDefaultIceServers(),
    };
  }

  const client = twilio(
    process.env.TWILIO_ACCOUNT_SID,
    process.env.TWILIO_AUTH_TOKEN,
  );
  const token = await client.tokens.create({ ttl });

  const iceServers = Array.isArray(token.iceServers)
    ? token.iceServers.map(normalizeIceServer).filter(Boolean)
    : [];

  return {
    provider: 'twilio',
    ttl: Number.parseInt(`${token.ttl}`, 10) || ttl,
    iceServers: iceServers.length > 0 ? iceServers : getDefaultIceServers(),
  };
}

module.exports = {
  fetchIceServers,
  getDefaultIceServers,
};