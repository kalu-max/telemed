process.env.NODE_ENV = 'test';

module.exports = {
  testEnvironment: 'node',
  testTimeout: 30000,
  verbose: true,
  testMatch: ['**/test/**/*.test.js'],
  // run test files serially to avoid port conflicts
  maxWorkers: 1
};
