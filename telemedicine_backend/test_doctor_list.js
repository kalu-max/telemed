const http = require('http');
const loginData = JSON.stringify({ email: 'drtest@example.com', password: 'password123' });

function makeRequest(options, data) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, res => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => resolve({ status: res.statusCode, body }));
    });
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

(async () => {
  // login to get token
  const loginResp = await makeRequest({
    hostname: 'localhost', port: 5000, path: '/api/auth/login', method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Content-Length': loginData.length }
  }, loginData);
  console.log('Login', loginResp.status, loginResp.body);
  if (loginResp.status !== 200) return;
  const token = JSON.parse(loginResp.body).token;

  const listResp = await makeRequest({
    hostname: 'localhost', port: 5000, path: '/api/users/doctors/available', method: 'GET',
    headers: { 'Authorization': 'Bearer ' + token }
  });
  console.log('Doctors list', listResp.status, listResp.body);
})();