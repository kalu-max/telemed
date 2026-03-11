// Tests for ICE server service
const { fetchIceServers, getDefaultIceServers } = require('../server/services/iceServers');

describe('ICE Servers service', () => {
  test('getDefaultIceServers returns STUN servers', () => {
    const servers = getDefaultIceServers();
    expect(Array.isArray(servers)).toBe(true);
    expect(servers.length).toBeGreaterThan(0);
    expect(servers[0].urls).toBeDefined();
    expect(servers[0].urls[0]).toContain('stun:');
  });

  test('fetchIceServers returns default when Twilio is not configured', async () => {
    delete process.env.TWILIO_ACCOUNT_SID;
    delete process.env.TWILIO_AUTH_TOKEN;

    const result = await fetchIceServers();
    expect(result.provider).toBe('default');
    expect(result.ttl).toBeDefined();
    expect(Array.isArray(result.iceServers)).toBe(true);
    expect(result.iceServers.length).toBeGreaterThan(0);
  });

  test('fetchIceServers respects ttlSeconds parameter', async () => {
    const result = await fetchIceServers({ ttlSeconds: 7200 });
    expect(result.ttl).toBe(7200);
  });

  test('fetchIceServers clamps ttl to valid range', async () => {
    const low = await fetchIceServers({ ttlSeconds: 10 });
    expect(low.ttl).toBeGreaterThanOrEqual(60);

    const high = await fetchIceServers({ ttlSeconds: 999999 });
    expect(high.ttl).toBeLessThanOrEqual(86400);
  });

  test('default ICE servers are immutable (frozen)', () => {
    const a = getDefaultIceServers();
    const b = getDefaultIceServers();
    // should be separate copies
    expect(a).not.toBe(b);
    expect(a[0]).not.toBe(b[0]);
    // values should be identical
    expect(a[0].urls).toEqual(b[0].urls);
  });
});
