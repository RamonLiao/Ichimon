# MON Fan Dojo Backend API — Design Spec

**Status:** Approved (2026-04-23)
**Owner:** Ramon
**Integrator:** Kenny (frontend)
**Related:** `docs/architecture/mvp-spec.md`, `deployments/testnet.json`

## 0. Goal

Provide 5 HTTP APIs supporting the Fan Dojo MVP demo:
read-only views for stations / moments / fighter, and QR-based check-in authorization
with ed25519 signing + nonce replay protection. Backend does NOT submit on-chain txs;
the frontend (zkLogin) signs and submits `record_check_in` etc.

Testnet already deployed:
- `PKG_ID = 0x267e74605140e3d467c740be1a7d5cb43814b1776d79fd517ece9ef2ded1dd61`
- `MINT_REGISTRY_ID = 0x1ad98a64f0066c7656e6d439f630e50dd268cb0c9904a77aefee00633b19f6d3`

## 1. Project Structure

Standalone `backend/` directory (not monorepo — frontend integration simpler).

```
backend/
├── src/
│   ├── server.ts                # Fastify bootstrap + swagger
│   ├── env.ts                   # zod-validated env loader
│   ├── errors.ts                # AppError class + Fastify error handler
│   ├── routes/
│   │   ├── stations.ts
│   │   ├── moments.ts
│   │   ├── fighter.ts
│   │   └── qr.ts
│   ├── services/
│   │   ├── sui.ts               # SuiGrpcClient wrapper + cache
│   │   ├── mock.ts              # read mock JSON seed
│   │   ├── qr-signer.ts         # ed25519 sign/verify, key rotation
│   │   └── nonce-store.ts       # Upstash Redis wrapper
│   ├── schemas/                 # TypeBox schemas
│   └── mock-data/
│       ├── stations.json
│       ├── moments.json
│       ├── fighter-takeru.json
│       └── videos.json
├── scripts/
│   └── generate-qr-key.ts
├── test/
│   ├── unit/
│   ├── integration/
│   ├── monkey/
│   └── fixtures/
├── Dockerfile
├── fly.toml
├── .env.example
├── package.json
└── tsconfig.json
```

**Principles:** services/ = pure functions, single responsibility. routes/ = HTTP binding + schema only.

## 2. API Contracts

All routes defined with **TypeBox** schemas → Fastify validates input → `@fastify/swagger` auto-generates OpenAPI JSON at `/docs/json`. Frontend (Kenny) generates TS types via `openapi-typescript`.

### 2.1 `GET /api/stations`
Mock JSON only (static metadata).
```ts
Response: {
  stations: Array<{
    station_id: string
    event_name: string
    event_date: string      // ISO
    venue: string
    hostesses: Array<{ id, name, avatar_url, bio }>
  }>
}
```

### 2.2 `GET /api/moments`
Hybrid: metadata from mock JSON, dynamic fields (`status`, `total_guardians`, `total_points`, `top_guardians`) from chain when `DATA_SOURCE=chain`.
```ts
Query: { status?: 'candidate' | 'finalized' | 'expired' }
Response: {
  moments: Array<{
    moment_id: string       // SUI object ID
    title: string
    description: string
    video_url: string       // Walrus blob URL
    thumbnail_url: string
    status: 0 | 1 | 2
    total_guardians: number
    total_points: number
    preservation_until: number
    top_guardians: Array<{    // top 10 only
      fan_sbt_id: string
      rank: number
      tier: 0 | 1 | 2 | 3
      points_contributed: number
    }>
  }>
}
```

### 2.3 `GET /api/fighter/:id` (demo only supports `takeru`)
```ts
Response: {
  fighter_id: string
  name: string
  profile: { bio, career_record, championships, image_url }
  events: Station[]
  videos: Array<{ id, title, url, thumbnail }>
  total_fans?: number       // MintRegistry size (chain)
}
```

### 2.4 `POST /api/checkin/qr/issue` (hostess backend)
```ts
Request: {
  station_id: string
  fighter_id: string
  issuer_token: string      // env whitelist
}
Response: {
  qr_payload: string        // base64url(header).base64url(body).base64url(sig)
  exp: number               // unix ms
}
```

### 2.5 `POST /api/checkin/qr/verify` (fan app)
```ts
Request: { qr_payload: string }
Response 200: {
  ok: true
  payload: { station_id, fighter_id, nonce, iat, exp }
}
Response 4xx: { error: { code, message } }
```

### 2.6 Error Format
```ts
{ error: { code: string, message: string, details?: any } }
```

| Code | HTTP | Meaning |
|---|---|---|
| `VALIDATION_ERROR` | 400 | body/query invalid |
| `MALFORMED_QR` | 400 | QR payload unparseable |
| `INVALID_SIGNATURE` | 401 | ed25519 verify failed / unknown kid |
| `UNAUTHORIZED` | 401 | bad issuer_token |
| `NOT_FOUND` | 404 | fighter_id / moment_id not found |
| `NONCE_USED` | 409 | QR already consumed |
| `EXPIRED` | 410 | QR past exp |
| `CHAIN_TIMEOUT` | 503 | gRPC 5s timeout |
| `CHAIN_ERROR` | 503 | gRPC other error |
| `INTERNAL_ERROR` | 500 | uncaught |

## 3. QR Signing + Nonce

### 3.1 Payload Structure
```
qr_payload = base64url(header) + "." + base64url(body) + "." + base64url(sig)
header = { "alg": "ed25519", "kid": "v1" }
body   = { station_id, fighter_id, nonce, iat, exp }
         nonce = 16 random bytes (base64url, 22 chars)
sig    = ed25519_sign(current_key, base64url(header) + "." + base64url(body))
```

Hand-rolled, not JWT lib (ed25519 + JWT header confusion avoided).

### 3.2 Key Rotation
Env:
- `QR_KEY_CURRENT = "v2:<base64 privkey 32B>"` (sign new)
- `QR_KEY_PREVIOUS = "v1:<base64>"` (verify old, optional)

Rotation flow:
1. Generate new keypair (v2)
2. Set `QR_KEY_PREVIOUS = old_v1`, `QR_KEY_CURRENT = new_v2`
3. Deploy
4. Wait > QR_EXPIRY_MS (5 min) for old QRs to expire
5. Unset `QR_KEY_PREVIOUS`

### 3.3 Verify Flow
```
1. Parse qr_payload structure      → fail: MALFORMED_QR (400)
2. Look up pubkey by header.kid    → fail: INVALID_SIGNATURE (401)
3. ed25519_verify(sig)             → fail: INVALID_SIGNATURE (401)
4. now > body.exp                  → fail: EXPIRED (410)
5. Redis SET nonce:{nonce} 1 NX EX 300
   → false: NONCE_USED (409)
   → true: continue
6. Return { ok: true, payload: body }
```

**Atomicity:** step 5 uses `SET NX EX` (atomic in Redis) — prevents race condition when two requests submit the same nonce concurrently.

### 3.4 Issue Flow
1. Validate `issuer_token` against env whitelist (`ISSUER_TOKENS` comma-separated)
2. `nonce = crypto.randomBytes(16)`
3. `iat = now`, `exp = now + QR_EXPIRY_MS`
4. Build body + sign with `QR_KEY_CURRENT`
5. Return `qr_payload`, `exp`

### 3.5 Key Generation Script
`scripts/generate-qr-key.ts`:
```
$ npm run gen:qr-key
Public key (hex):  abc123...
Private key (b64): xyz789...
Next: fly secrets set QR_KEY_CURRENT="v1:xyz789..."
```

## 4. SUI Chain Reading — gRPC

**Critical:** JSON-RPC is deprecated and being decommissioned. Use gRPC by default.

### 4.1 Client
```ts
import { SuiGrpcClient } from '@mysten/sui/grpc'
const grpc = new SuiGrpcClient({
  network: 'testnet',
  baseUrl: env.SUI_GRPC_URL,  // https://fullnode.testnet.sui.io:443
})
```

GraphQL (`SuiGraphQLClient` from `@mysten/sui/graphql`) reserved for advanced event/tx filter queries if needed.

### 4.2 Reads

| API Field | Service | Method |
|---|---|---|
| Moment object (status, vote_count) | `ledgerService` | `getObject({ objectId, readMask: { paths: ['*'] }})` |
| `guardians` Table dynamic fields | `stateService` | `listDynamicFields({ parent: table_id })` |
| Batch dynamic field values | `ledgerService` | `batchGetObjects` |
| MintRegistry size | `ledgerService` | `getObject(MINT_REGISTRY_ID)` → `minted.size` |

### 4.3 BCS Decoding
Use `@mysten/codegen` to generate BCS struct types from Move ABI:
```
npx mysten-codegen --package 0x267e74... --out src/contracts
```
Then `FanSBT.parse(obj.contents.value)` for type-safe access. Shared codegen output with frontend possible.

### 4.4 Performance / Reliability
- `node-cache` in-memory, TTL 10s on moment reads
- `multiGetObjects` batch size 50 for dynamic fields
- `top_guardians` truncated to rank ≤ 10
- 5s gRPC timeout → on failure return 503 + stale cache if available
- `DATA_SOURCE=mock` env toggles off all chain reads (uses `src/mock-data/*.json`)

### 4.5 Env
```
SUI_GRPC_URL     = "https://fullnode.testnet.sui.io:443"
SUI_GRAPHQL_URL  = "https://sui-testnet.mystenlabs.com/graphql"  # optional
PKG_ID           = "0x267e..."
MINT_REGISTRY_ID = "0x1ad9..."
```

## 5. Error Handling & Observability

### 5.1 AppError Class
```ts
class AppError extends Error {
  constructor(
    public code: string,
    public httpStatus: number,
    message: string,
    public details?: unknown
  ) { super(message) }
}
```

Fastify `setErrorHandler` maps: AppError → `{ error: { code, message, details }}`; Fastify validation errors → 400 `VALIDATION_ERROR`; uncaught → 500 `INTERNAL_ERROR` (no stack in production).

### 5.2 Logging (pino)
Fastify's built-in pino with:
- `redact: ['req.headers.authorization', 'req.body.issuer_token']`
- Structured per-request fields: `reqId`, `method`, `url`, `statusCode`, `responseTime`
- Custom log points: QR verify result (no nonce body — avoid replay inference), gRPC latency + cache hits, Upstash fallback warnings

### 5.3 Health Checks
- `GET /health` → `{ ok, uptime, version }` (always 200)
- `GET /ready` → checks Upstash + gRPC connectivity, 503 on failure
- Fly.io uses `/ready` for http_service.checks

### 5.4 Rate Limiting (`@fastify/rate-limit`)
- `/qr/verify`: 30 req/min per IP (prevents nonce brute-force)
- `/qr/issue`: 60 req/min per issuer_token
- Read APIs: unlimited

### 5.5 CORS
`@fastify/cors`, whitelist from `ALLOWED_ORIGINS` env (comma-separated).

## 6. Env / Secrets

### 6.1 Schema (zod, fail-fast on boot)
```ts
NODE_ENV: 'development' | 'production' | 'test'
PORT: number = 3000
LOG_LEVEL: 'debug'|'info'|'warn'|'error' = 'info'

DATA_SOURCE: 'chain' | 'mock' = 'chain'

SUI_GRPC_URL: url = 'https://fullnode.testnet.sui.io:443'
SUI_GRAPHQL_URL: url (optional)
PKG_ID: string (required)
MINT_REGISTRY_ID: string (required)

QR_KEY_CURRENT: string (required, format "v<N>:<base64>")
QR_KEY_PREVIOUS: string (optional)
QR_EXPIRY_MS: number = 300000

ISSUER_TOKENS: string (required, comma-separated)

UPSTASH_REDIS_REST_URL: url (required)
UPSTASH_REDIS_REST_TOKEN: string (required)

ALLOWED_ORIGINS: string (required, comma-separated)
```

### 6.2 File Strategy
- `.env.example` — committed, empty values + comments
- `.env.local` — gitignored, local dev
- `.env.test` — gitignored, CI/test
- Production → Fly secrets only (no file)

### 6.3 Fly Secrets Commands
```bash
fly secrets set QR_KEY_CURRENT="v1:..." UPSTASH_REDIS_REST_URL="..." \
  UPSTASH_REDIS_REST_TOKEN="..." ISSUER_TOKENS="demo-1,demo-2" \
  PKG_ID="0x267e..." MINT_REGISTRY_ID="0x1ad9..."

# Rotation
fly secrets set QR_KEY_PREVIOUS="v1:old" QR_KEY_CURRENT="v2:new"
# wait 5 min
fly secrets unset QR_KEY_PREVIOUS
```

### 6.4 Boot Checks
1. `envSchema.parse()` crashes on missing/malformed
2. Validate `QR_KEY_CURRENT` decodes to 32B ed25519 privkey
3. Ping Upstash — on failure warn + degraded mode (in-memory fallback acceptable for demo)
4. `getChainIdentifier()` check — on failure warn (read APIs will return 503)

### 6.5 Leak Protection
- `.gitignore`: `.env.*` + `!.env.example`
- Optional pre-commit hook: `gitleaks` scan diff for base64/PRIVATE KEY patterns

## 7. Testing

**Stack:** Vitest + supertest. Fastify `app.inject()` for route tests (no real port).

### 7.1 Layers
**Unit** (`test/unit/`)
- `qr-signer`: sign/verify roundtrip, wrong kid reject, rotation flow, expired reject, tamper reject
- `nonce-store`: first SET → true, second → false, TTL expiry
- `mock-data`: fixtures validate against TypeBox schemas

**Integration** (`test/integration/`)
- All routes: happy path + 4xx/5xx cases
- **E2E QR flow**: issue → verify (200) → verify again (409)
- Chain reads mocked; opt-in real testnet via `CHAIN_E2E=1`

**Monkey** (`test/monkey/`) — per project rule `test.md`
- QR payload 10MB garbage → early reject
- 100 concurrent same-nonce verify → exactly 1 passes
- Upstash timeout simulation → degraded, no crash
- Malformed chain object → 500, no stack leak
- Injection strings in station_id → signed as plain string (no false alarm)
- Clock skew (iat > now) → MALFORMED_QR

### 7.2 Coverage Targets
- Unit: 90%+ on qr-signer / nonce-store (security-critical)
- Routes: 80%+
- Chain layer: mock-based, E2E opt-in

### 7.3 CI (GitHub Actions)
```yaml
- npm ci
- npm run lint
- npm run typecheck     # tsc --noEmit
- npm run test
- npm run build
```
Deploy job separate (manual or main push): `fly deploy --remote-only`.

## 8. Deployment — Fly.io

**Region:** `nrt` (Tokyo). **Tier:** free (shared-cpu-1x, 256MB).

### 8.1 Dockerfile
Multi-stage node:22-alpine build. Mock JSON copied into dist/.

### 8.2 fly.toml
- `auto_stop_machines = true`, `min_machines_running = 0` (scale to 0)
- Health check `/ready` every 30s, 10s grace period
- `force_https = true`

### 8.3 Cold Start Mitigation
Scale-to-0 gives ~3-5s first-request latency. `/ready` grace period 10s. For demo: `fly scale count 1` pin a machine.

### 8.4 URLs
- API: `https://ichimon-api.fly.dev`
- Swagger UI: `https://ichimon-api.fly.dev/docs`
- OpenAPI JSON: `https://ichimon-api.fly.dev/docs/json`
- Health: `https://ichimon-api.fly.dev/health`

### 8.5 Kenny Handover
```
VITE_API_BASE=https://ichimon-api.fly.dev
npx openapi-typescript https://ichimon-api.fly.dev/docs/json -o src/types/api.d.ts
```

## 9. Out of Scope

- Sponsored gas / backend tx submission
- Fighter IDs other than `takeru`
- Sentry/Datadog observability
- OAuth / user accounts (zkLogin on frontend)
- Walrus upload (blobs pre-uploaded, URLs in mock JSON)
- Event indexer (frontend polls APIs on demand)

## 10. Security Posture Summary

| Threat | Mitigation |
|---|---|
| QR screenshot shared to 100 people | Nonce single-use (Redis SET NX EX) |
| Replay after backend restart | Upstash persistent (not in-memory) |
| QR key compromise | Rotation via kid header + QR_KEY_PREVIOUS |
| Forged QR | ed25519 signature, key in Fly secrets only |
| Brute-force nonce guessing | 16B random + rate limit + short TTL |
| Bad issuer token | Whitelist in ISSUER_TOKENS env + rate limit |
| Stack trace leak | Fastify handler strips in production |
| Secret in git | .gitignore + gitleaks (optional) + .env.example template |
| Chain RPC DoS | 5s timeout + cache + 503 fallback (not crash) |
