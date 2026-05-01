// Trivial HTTP server used by the §4 multi-stage build example.
// See docs/04-multi-stage-builds.md for the walkthrough.

const http = require('http');
const port = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    status: 'ok',
    runtime: 'hummingbird-nodejs',
    nodeVersion: process.version
  }));
});

server.listen(port, '0.0.0.0', () => {
  console.log(JSON.stringify({
    ts: new Date().toISOString(),
    level: 'info',
    msg: 'listening',
    port
  }));
});
