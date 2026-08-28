const http = require('http');
const httpProxy = require('http-proxy');

const target = process.env.OBDX_BASE_URL;
const port = Number(process.env.PROXY_PORT || 8082);
// Bind all interfaces so LAN clients can reach the proxy (not only localhost).
const host = process.env.PROXY_HOST || '0.0.0.0';

if (!target) {
  console.error(
    'OBDX_BASE_URL is not set. Example:\n' +
      '  OBDX_BASE_URL=http://your-host:7777 node proxy.js\n' +
      'Or: set -a && source .env && set +a && node proxy.js',
  );
  process.exit(1);
}

const proxy = httpProxy.createProxyServer({
  target,
  changeOrigin: true,
});

function applyCors(headers, req) {
  // Drop upstream CORS headers (OBDX may send ACAO: file:// which breaks browsers).
  for (const key of Object.keys(headers)) {
    if (key.toLowerCase().startsWith('access-control-')) {
      delete headers[key];
    }
  }

  const origin = req.headers.origin;
  if (origin) {
    headers['access-control-allow-origin'] = origin;
    headers['access-control-allow-credentials'] = 'true';
    headers['vary'] = 'Origin';
  } else {
    headers['access-control-allow-origin'] = '*';
  }
  headers['access-control-allow-methods'] =
    'GET,POST,PUT,PATCH,DELETE,OPTIONS,HEAD';
  headers['access-control-allow-headers'] =
    req.headers['access-control-request-headers'] ||
    [
      'Content-Type',
      'Authorization',
      'X-Requested-With',
      'X-Target-Unit',
      'X-Token-Type',
      'Accept',
      'Accept-Language',
      'Token_id',
      'X-Challenge',
      'X-Challenge_response',
      'x-authentication-type',
    ].join(', ');
  headers['access-control-expose-headers'] = [
    'set-cookie',
    'content-type',
    'X-Challenge',
    'X-Challenge_response',
    'x-challenge',
    'x-challenge_response',
  ].join(', ');
}

proxy.on('proxyRes', (proxyRes, req) => {
  applyCors(proxyRes.headers, req);

  const cookies = proxyRes.headers['set-cookie'];
  if (cookies) {
    proxyRes.headers['set-cookie'] = cookies.map((c) =>
      c
        .replace(/;\s*Secure/gi, '')
        .replace(/SameSite=Strict/gi, 'SameSite=Lax')
        .replace(/SameSite=None/gi, 'SameSite=Lax')
        .replace(/;\s*Domain=[^;]*/gi, ''),
    );
  }
});

proxy.on('error', (err, _req, res) => {
  console.error('Proxy error:', err.message);
  if (res && !res.headersSent && typeof res.writeHead === 'function') {
    res.writeHead(502, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Bad gateway', detail: err.message }));
  }
});

http
  .createServer((req, res) => {
    if (req.method === 'OPTIONS') {
      const headers = {};
      applyCors(headers, req);
      res.writeHead(204, headers);
      res.end();
      return;
    }

    proxy.web(req, res);
  })
  .listen(port, host, () => {
    console.log(`OBDX web proxy: http://${host}:${port} → ${target}`);
    console.log(
      `Local Dio:  OBDX_WEB_FALLBACK_URL=http://localhost:${port}`,
    );
    console.log(
      `LAN Dio:    OBDX_WEB_FALLBACK_URL=http://<this-host-ip>:${port}`,
    );
    console.log(
      'Do NOT point OBDX_BASE_URL at the Flutter static web port — use the OBDX API host, and proxy for web.',
    );
    console.log('Then re-run: ./scripts/run_app.sh -d chrome');
  });
