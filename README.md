# UBCI Bank

Retail mobile banking application (Flutter) — Android, iOS, and Web.

## Prerequisites

- Flutter SDK ^3.6.0
- Xcode (iOS), Android Studio / SDK (Android)
- Node.js (required for Chrome / web CORS proxy)

## Quick start (Android / iOS)

```bash
cp .env.example .env
# Edit .env — set OBDX_BASE_URL to your OBDX API host

chmod +x scripts/run_app.sh
./scripts/run_app.sh
```

Or open the project in Android Studio, run `./scripts/sync_ide_config.sh`, then select the **UBCI Bank** run configuration.

## Quick start (Web / Chrome)

Web needs the local CORS proxy so the browser can call OBDX.

1. Configure env:

```bash
cp .env.example .env
# Set OBDX_BASE_URL to your OBDX API host
# Keep OBDX_WEB_FALLBACK_URL=http://localhost:8082 (default)
```

2. Install and start the proxy (separate terminal):

```bash
npm install
set -a && source .env && set +a && node proxy.js
```

3. Run the Flutter web app:

```bash
chmod +x scripts/run_app.sh
./scripts/run_app.sh -d chrome
```

## Notes

- Never commit `.env` — only `.env.example` is tracked.
- `OBDX_BASE_URL` is a compile-time `--dart-define`. After changing `.env`, stop the app and run again (not hot restart).
- Sync Android Studio args after editing `.env`: `./scripts/sync_ide_config.sh`
