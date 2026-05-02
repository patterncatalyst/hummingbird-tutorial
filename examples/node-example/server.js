// Trivial HTTP server used by the §4 multi-stage build example.
// See _docs/04-multi-stage-builds.md for the walkthrough.
//
// Uses pino for structured logging — gives the multi-stage build a
// real dependency to flow from the builder stage into the runtime
// stage. A pure-stdlib example wouldn't actually demonstrate the
// dependency-flow pattern that's the point of the multi-stage build.

const http = require('http');
const pino = require('pino');

const log = pino();
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
  log.info({ port }, 'listening');
});
