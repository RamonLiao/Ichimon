# Frontend Integration Guide — Ichimon Backend + Move Contracts

> 目標讀者：Kenny（前端）
> Backend：`https://ichimon.fly.dev`
> Network：Sui **testnet**
> 最後更新：2026-04-24（v2 upgrade：propose_moment 拒絕空 title/blob_id，`EEmptyMetadata=106`）

---

## TL;DR

- Backend **只讀鏈 + 驗 QR**，**不替前端簽任何 tx**。
- 所有上鏈操作（mint / check-in / vote / finalize）由前端拿 zkLogin keypair 自簽自送。
- Sui SDK 一律用 **gRPC**（`@mysten/sui/grpc`），JSON-RPC 已 deprecated。
- Bootstrap 第一件事：`GET /api/config` 拿 `pkg_id` + `mint_registry`（含 `initial_shared_version`）。
- 生 TS types：`npx openapi-typescript https://ichimon.fly.dev/docs/json -o src/types/api.d.ts`
- Swagger UI：<https://ichimon.fly.dev/docs>

---

## 0. 責任分工

| 層 | 誰處理 | 備註 |
|---|---|---|
| QR 簽章驗證 | Backend (ed25519) | 前端拿到 `qr_payload` 直接丟 `/verify` |
| Nonce 去重 | Backend (Upstash Redis) | 409 = 已用過 |
| Static metadata（站姐、影片、賽事名） | Backend（mock JSON） | 永遠從 `/api/stations`, `/api/fighter/:id` 讀 |
| 鏈上 state（`total_fans`、moment 票數） | Backend 讀 → 回 JSON | 前端不用自己打 gRPC |
| **Tx 建構 + 簽 + 送** | **前端（zkLogin）** | Backend 完全不碰 |
| 使用者 FanSBT 狀態（level / check_in_count） | 前端直接打 gRPC 讀自己的 object | Backend 不做 per-user 查詢 |

---

## 1. Bootstrap — App 啟動必做

```ts
// 1. 拿鏈上常數
const cfg = await fetch('https://ichimon.fly.dev/api/config').then(r => r.json())
// {
//   network: 'testnet',
//   pkg_id: '0xeea4ccd93c56c0bd785ed6b98edc500f7d49ec7a499a215db9cdf81495dd51ee',  // v2 (upgraded 2026-04-24)
//   mint_registry: {
//     object_id: '0x1ad98a64...',
//     initial_shared_version: 828957603   // ← PTB 必用
//   }
// }

// 2. 建 gRPC client
import { SuiGrpcClient } from '@mysten/sui/grpc'
const sui = new SuiGrpcClient({ baseUrl: 'https://fullnode.testnet.sui.io:443' })
```

**⚠️ `initial_shared_version` 必帶**。PTB 引用 `MintRegistry`（shared object）時要用 `tx.sharedObjectRef({ objectId, initialSharedVersion, mutable: true })`，不是 `tx.object(id)`。

---

## 2. API 總覽（5 支 + 2 健康檢查）

| Method | Path | 用途 |
|---|---|---|
| GET | `/api/config` | 鏈上常數 bootstrap |
| GET | `/api/stations` | 站姐 / 賽事列表 |
| GET | `/api/fighter/:id` | 武尊 profile（目前只有 `takeru`）+ `total_fans` |
| GET | `/api/moments?status=candidate\|finalized\|expired` | 殿堂時刻 |
| POST | `/api/checkin/qr/issue` | 站姐端產 QR（需 `issuer_token`） |
| POST | `/api/checkin/qr/verify` | 用戶端驗 QR |
| GET | `/health` | liveness |
| GET | `/ready` | readiness（Upstash + SUI gRPC 連通） |

Full schema 看 Swagger：<https://ichimon.fly.dev/docs>

---

## 3. Check-in 流程（核心 UX）

```
[站姐裝置]                  [Backend]              [用戶裝置]                  [Sui testnet]
     │                         │                       │                            │
     │  POST /qr/issue         │                       │                            │
     │  { station_id,          │                       │                            │
     │    fighter_id,          │                       │                            │
     │    issuer_token }       │                       │                            │
     ├────────────────────────▶│                       │                            │
     │  { qr_payload, exp }    │                       │                            │
     │◀────────────────────────┤                       │                            │
     │                         │                       │                            │
     │  render QR code         │                       │                            │
     │  (5 min expiry)         │                       │                            │
     │                         │                       │                            │
     │                         │  scan QR ──────────▶  │                            │
     │                         │                       │                            │
     │                         │  POST /qr/verify      │                            │
     │                         │  { qr_payload }       │                            │
     │                         │◀──────────────────────┤                            │
     │                         │  200 { ok, payload }  │                            │
     │                         │  OR 409 NONCE_USED    │                            │
     │                         ├──────────────────────▶│                            │
     │                         │                       │  zkLogin 簽 PTB:           │
     │                         │                       │  record_check_in(          │
     │                         │                       │    &mut FanSBT)            │
     │                         │                       ├───────────────────────────▶│
     │                         │                       │                            │
     │                         │                       │  tx digest ────────────────┤
     │                         │                       │◀───────────────────────────┤
```

### 站姐端（Issue QR）

```ts
const res = await fetch('https://ichimon.fly.dev/api/checkin/qr/issue', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    station_id: 'sta_001',
    fighter_id: 'takeru',
    issuer_token: process.env.VITE_ISSUER_TOKEN, // 站姐專屬 token，Kenny 問我拿
  }),
})
// { qr_payload: 'base64url.sig', exp: 1735689600000 }
```

渲染成 QR code（`qrcode` lib），UI 顯示倒數 5 分鐘。

### 用戶端（Verify + Chain Call）

```ts
// Step 1: 驗 QR（消耗 nonce）
const v = await fetch('https://ichimon.fly.dev/api/checkin/qr/verify', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ qr_payload: scannedPayload }),
})
if (v.status === 409) throw new Error('QR 已使用')
if (v.status === 410) throw new Error('QR 過期')
if (!v.ok) throw new Error('QR 無效')
const { payload } = await v.json()
// payload = { station_id, fighter_id, nonce, iat, exp }

// Step 2: 前端自簽 PTB
import { Transaction } from '@mysten/sui/transactions'
const tx = new Transaction()
tx.moveCall({
  target: `${cfg.pkg_id}::fan_sbt::record_check_in`,
  arguments: [tx.object(userFanSbtId)], // 用戶的 FanSBT（owned object）
})

// Step 3: zkLogin 送出（用 dapp-kit 或 zkLogin flow）
const result = await signAndExecute({ transaction: tx })
```

**錯誤碼對照**：
| HTTP | code | 意義 | UX |
|---|---|---|---|
| 400 | `MALFORMED_QR` | payload 壞掉 | 重新掃 |
| 401 | `INVALID_SIGNATURE` | QR 簽章錯 / key rotation | 重新掃 |
| 401 | `UNAUTHORIZED` | issuer_token 錯（站姐端） | 檢查 token |
| 409 | `NONCE_USED` | QR 已用過 | 提示「已報到」 |
| 410 | `EXPIRED` | QR 過期（>5min） | 請站姐重新產 |

---

## 4. Mint FanSBT（第一次進場）

用戶還沒有 FanSBT → 先 mint 再 check-in。

```ts
const tx = new Transaction()
tx.moveCall({
  target: `${cfg.pkg_id}::fan_sbt::mint_fan_card`,
  arguments: [
    tx.sharedObjectRef({
      objectId: cfg.mint_registry.object_id,
      initialSharedVersion: cfg.mint_registry.initial_shared_version,
      mutable: true,
    }),
    tx.pure.id('takeru'), // fighter_id，目前只支援 takeru
  ],
})
await signAndExecute({ transaction: tx })
```

**冪等性**：同一地址第二次 mint 會 abort（`EAlreadyMinted=1`）。前端先查自己 owned objects 過濾 type 確認。

---

## 5. 升 Lv.2 觸發條件

```
check_in_count >= 3  AND  content_count >= 1  →  自動升 Lv.2
```

- `content_count` 初始值 = 1（mint 時送），所以實務上 **3 次 check-in 就升**。
- `record_check_in` 會自動檢查條件並升級，前端不用特別叫升級函式。
- 如果條件滿足但升級沒觸發（理論上不會），fallback：呼叫 `fan_sbt::upgrade_to_station(&mut FanSBT)`（idempotent）。

升 Lv.3（官方認證）需要 `AdminCap`，前端用不到。

---

## 6. Memorial Moment（殿堂時刻）投票

### 列表

```ts
const { moments } = await fetch('https://ichimon.fly.dev/api/moments?status=candidate').then(r => r.json())
```

回傳結構：
```ts
type Moment = {
  moment_id: string          // '0x...' on-chain ID, 或 'PLACEHOLDER_xxx' (mock)
  title: string
  description: string
  video_url: string
  thumbnail_url: string
  status: 0 | 1 | 2          // 0=candidate, 1=finalized, 2=expired
  total_guardians: number
  total_points: number
  preservation_until: number // ms timestamp
  top_guardians: Array<{
    fan_sbt_id: string
    rank: number              // 1-based, 首次投票鎖定
    tier: 0 | 1 | 2 | 3       // badge tier
    points_contributed: number
  }>
}
```

> ⚠️ `top_guardians` 目前是 stub，testnet 有真實 moment 後 backend 會補 DF traversal。現在顯示 fallback UI。

### 投票（Lv.2+ 才能）

```ts
const tx = new Transaction()
tx.moveCall({
  target: `${cfg.pkg_id}::memorial_hall::vote_moment`,
  arguments: [
    tx.object(momentId),        // shared
    tx.object(userFanSbtId),    // 用戶自己的 FanSBT
    tx.pure.u64(points),        // 要花的 points
    tx.object('0x6'),           // Clock
  ],
})
```

投票會扣 FanSBT 的 points。同一人重複投票會累加 `points_contributed`，但 `rank` 鎖死於**首次投票**時的 `total_guardians + 1`。

### Mint Guardian Badge（moment finalized 後）

```ts
const tx = new Transaction()
tx.moveCall({
  target: `${cfg.pkg_id}::memorial_hall::mint_guardian_badge`,
  arguments: [
    tx.object(momentId),
    tx.object(userFanSbtId),
    tx.object('0x6'),
  ],
})
```

- Badge 掛在 FanSBT 當 dynamic field，重複 mint 自然 abort。
- Tier 依 rank 決定（0/1/2/3）。

---

## 7. 讀用戶 FanSBT 狀態（前端直打 gRPC）

Backend 不做 per-user 查詢，前端自己用 gRPC 讀。

```ts
import { SuiGrpcClient } from '@mysten/sui/grpc'
const sui = new SuiGrpcClient({ baseUrl: 'https://fullnode.testnet.sui.io:443' })

// 列出用戶 FanSBT（filter type）
const owned = await sui.core.getOwnedObjects({
  owner: userAddress,
  filter: { StructType: `${cfg.pkg_id}::fan_sbt::FanSBT` },
  include: { content: true },
})

const fanSbt = owned.data[0]
// fanSbt.content 有：level, check_in_count, content_count, points, fighter_id ...
```

**進階 filter（多條件 / 歷史 query）** → 用 `SuiGraphQLClient`（`@mysten/sui/graphql`），不要回去用 JSON-RPC `SuiClient`。

---

## 8. zkLogin 注意事項

- Ephemeral keypair 每次 session 要重產，有 TTL。
- JWT proof 從 prover service 拿，backend 不幫忙。
- 用 `@mysten/dapp-kit` 的 `useSignAndExecuteTransaction` hook，內建 zkLogin 支援（設定 provider 時帶 zkLogin config）。
- Gas：testnet 從 faucet 拿 SUI，前端要 handle「用戶沒 gas」的 UX（引導 faucet or sponsor）。

---

## 9. CORS & 環境變數

Backend `ALLOWED_ORIGINS` 目前設 `http://localhost:5173`（Vite default）。

Kenny 實際部署 URL 敲定後告訴我，我更新 Fly secret：
```bash
fly secrets set ALLOWED_ORIGINS=http://localhost:5173,https://ichimon-frontend.vercel.app -a ichimon
```

前端 `.env`：
```
VITE_API_BASE=https://ichimon.fly.dev
VITE_SUI_NETWORK=testnet
VITE_SUI_GRPC_URL=https://fullnode.testnet.sui.io:443
VITE_ISSUER_TOKEN=<問我拿，站姐端才需要>
```

---

## 10. 除錯工具

- **Swagger**：<https://ichimon.fly.dev/docs> — 直接試 API
- **Ready check**：`curl https://ichimon.fly.dev/ready` — 確認 backend + Upstash + Sui gRPC 都通
- **Explorer (v2)**：<https://testnet.suivision.xyz/package/0xeea4ccd93c56c0bd785ed6b98edc500f7d49ec7a499a215db9cdf81495dd51ee>
- **Upgrade tx**：<https://testnet.suivision.xyz/txblock/85oV8XTDPg9Z4WVrHGgXRsz3MBE7MioKx14Skp8Fkxox>
- **Original package (v1)**：<https://testnet.suivision.xyz/package/0x267e74605140e3d467c740be1a7d5cb43814b1776d79fd517ece9ef2ded1dd61>

---

## 11. 已知限制（testnet demo 夠用，mainnet 前要補）

- `top_guardians` DF traversal 是 stub（回空陣列）
- Moment metadata 是 mock JSON，不是鏈上讀
- `total_fans` 從 MintRegistry size 讀，gRPC response shape 還沒在有 mint 的情況下驗證過
- Scale-to-0 冷啟動首次 request 可能 200~800ms 延遲 → 前端加 loading state

---

## 12. 聯絡

有問題直接 ping Ramon。Backend 改動會推 `main` 自動 deploy，前端不用管 versioning。

關鍵 reference 檔案（repo 內）：
- `backend/src/routes/*.ts` — handler 原始碼
- `backend/src/schemas/*.ts` — TypeBox schema
- `deployments/testnet.json` — 鏈上 ID 清單
- `docs/architecture/mvp-spec.md` — 完整規格
- `docs/superpowers/specs/2026-04-23-backend-api-design.md` — API 設計文件
