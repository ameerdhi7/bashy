const http = require('http');

const port = process.env.PORT || 3000;
const host = process.env.HOST || '0.0.0.0';

const server = http.createServer((req, res) => {
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/plain; charset=utf-8');
  res.end('Hello World');
});

server.listen(port, host, () => {
  console.log(`Server listening on http://${host}:${port}`);
});


