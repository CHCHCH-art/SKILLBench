# Proxy and Presets

This reference covers built-in geo presets, custom preset loading, and proxy behavior in camofox-browser.

Related:
- `../SKILL.md`
- `./session-management.md`
- `./api-endpoints.md`
- `./cli-commands.md`

Source of truth for development: `AGENTS.md`

## Table of Contents

1. Built-in geo presets (8)
2. Preset resolution and validation
3. Custom presets (`CAMOFOX_PRESETS_FILE`)
4. Proxy model and per-session behavior
5. CLI proxy options and examples
6. API examples
7. Notes and caveats

---

## 1) Built-in geo presets (8)

Defined in `src/utils/presets.ts` as `BUILT_IN_PRESETS`:

| Preset | Locale | Timezone | Geolocation (lat, lon) |
|---|---|---|---|
| `us-east` | `en-US` | `America/New_York` | `40.7128, -74.006` |
| `us-west` | `en-US` | `America/Los_Angeles` | `34.0522, -118.2437` |
| `japan` | `ja-JP` | `Asia/Tokyo` | `35.6895, 139.6917` |
| `uk` | `en-GB` | `Europe/London` | `51.5074, -0.1278` |
| `germany` | `de-DE` | `Europe/Berlin` | `52.52, 13.405` |
| `vietnam` | `vi-VN` | `Asia/Ho_Chi_Minh` | `10.8231, 106.6297` |
| `singapore` | `en-SG` | `Asia/Singapore` | `1.3521, 103.8198` |
| `australia` | `en-AU` | `Australia/Sydney` | `-33.8688, 151.2093` |

---

## 2) Preset resolution and validation

`resolveContextOptions()` behavior:

1. Start from `preset` if provided
2. Apply explicit overrides: `locale`, `timezoneId`, `geolocation`, `viewport`
3. Validate with `validateContextOptions()`

Validation includes locale format, IANA timezone validity (when available), geolocation ranges, and viewport bounds.

---

## 3) Custom presets (`CAMOFOX_PRESETS_FILE`)

Custom presets are loaded at module init via environment variable:

```bash
CAMOFOX_PRESETS_FILE=/absolute/path/to/presets.json
```

Example file:

```json
{
  "canada-east": {
    "locale": "en-CA",
    "timezoneId": "America/Toronto",
    "geolocation": { "latitude": 43.6532, "longitude": -79.3832 }
  }
}
```

Rules:

- file must be a JSON object
- keys are normalized to lowercase
- custom preset names override built-ins on conflict
- load failures are logged as warnings and do not crash startup

---

## 4) Proxy model and per-session behavior

Proxy inputs come from environment (`src/utils/config.ts`):

- `PROXY_HOST`
- `PROXY_PORT`
- `PROXY_USERNAME`
- `PROXY_PASSWORD`

`src/services/context-pool.ts` applies proxy at context launch (`launchOptions({ proxy, geoip: !!proxy, ... })`).

Behavior summary:

- proxy is applied when a user context is launched
- because contexts are per `userId`, proxy usage is effectively per session/user context
- no proxy field is accepted in `POST /tabs` request body
- context seed overrides (`preset/locale/timezone/geolocation/viewport`) still work per user context

---

## 5) CLI proxy options and examples

There is no dedicated `camofox` command flag like `--proxy-host`.
CLI proxy configuration is done through environment variables before running commands.

```bash
export PROXY_HOST=proxy.example.com
export PROXY_PORT=8080
export PROXY_USERNAME=myuser
export PROXY_PASSWORD=mypass

camofox open "https://example.com" --user proxied-user
```

Combine proxy with geo preset selection:

```bash
camofox open "https://example.com" --geo japan --user jp-user
```

---

## 6) API examples

Create tab using preset:

```bash
curl -sS -X POST "http://127.0.0.1:9377/tabs" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "geo-user",
    "sessionKey": "default",
    "url": "https://example.com",
    "preset": "singapore"
  }'
```

List all available presets:

```bash
curl -sS "http://127.0.0.1:9377/presets"
```

---

## 7) Notes and caveats

- Unknown preset names return explicit errors with available options.
- If a context for a user already exists, new seed overrides for that user are ignored until context restart.
- For different proxy routes in parallel, use different `userId`s and separate server-level proxy environments/processes.
