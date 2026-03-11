const http = require('http');
const data = JSON.stringify({
  email: 'drtest@example.com',
  password: 'password123',
  name: 'Dr Test',
  role: 'doctor',
  specialization: 'Cardiologist'
});

const options = {
  hostname: 'localhost',
  port: 5000,
  path: '/api/auth/register',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
};

const req = http.request(options, res => {
  let body = '';
  res.on('data', chunk => (body += chunk));
  res.on('end', () => console.log('STATUS', res.statusCode, body));
});
req.on('error', console.error);
req.write(data);
req.end();
