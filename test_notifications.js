const http = require('http');

// Test the notifications endpoint
const options = {
  hostname: 'localhost',
  port: 5000,
  path: '/api/users/notifications',
  method: 'GET',
  headers: {
    'Authorization': 'Bearer test_token_here',
    'Content-Type': 'application/json'
  }
};

const req = http.request(options, (res) => {
  console.log(`Status: ${res.statusCode}`);
  console.log('Headers:', res.headers);

  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });

  res.on('end', () => {
    console.log('Response:', data);
  });
});

req.on('error', (error) => {
  console.error('Error:', error);
  process.exit(1);
});

req.end();
