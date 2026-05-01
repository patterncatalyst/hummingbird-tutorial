// Web service for §7 of the Hummingbird tutorial.
const http = require('http');
const port = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    status: 'ok',
    note: 'real implementation would talk to db and otel here',
    databaseUrl: process.env.DATABASE_URL ? 'configured' : 'unset',
    otelEndpoint: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'unset'
  }));
});

server.listen(port, '0.0.0.0', () => {
  console.log(JSON.stringify({
    ts: new Date().toISOString(),
    level: 'info',
    msg: 'web listening',
    port
  }));
});
