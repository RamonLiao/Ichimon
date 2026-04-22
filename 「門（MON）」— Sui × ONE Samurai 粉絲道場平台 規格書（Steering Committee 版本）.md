# 「門（MON）」— Sui × ONE Samurai 粉絲道場平台 規格書（Steering Committee 版本）
## 1. 專案簡介
「門（MON）」是建構在 Sui 區塊鏈上的格鬥粉絲道場平台，以「每位 ONE 選手是一個門」為核心概念，讓日本與全球粉絲可以以「門徒」身分長期追隨選手與賽事。[^1]
本產品作為 ONE Championship × Sui 在日本市場的長期策略性資產，目標是補足現有賽事與明星之上，缺乏「日本式歸屬結構」的缺口，成為日本粉絲經濟與選手經營的基礎層。[^2][^1]

本規格書針對 Steering Committee 說明：
- 商業與市場背景
- 明確痛點與解決方案
- MVP 功能規格與技術選型（為何必須使用 Sui）
- 法規與風險控管設計
- 未來展望與擴張路線
- 研究與設計依據
## 2. 背景與市場脈絡
### 2.1 ONE 在日本的擴張計畫
ONE Championship 正以「ONE Samurai」為品牌，啟動為期 5 年、共 60 場的日本長期賽事計畫，首場賽事將於 2026 年 4 月 29 日在東京有明 Arena 舉行。[^3][^2][^4]
ONE 與日本串流平台 U‑NEXT 達成合作，賽事內容將在其超過 1200 萬訂閱用戶的基礎上進行獨家播出，顯示集團對日本市場的重視與長期投入。[^4]

然而，相較於 RIZIN 等本土品牌深耕十年以上的「道場—選手—粉絲」垂直結構，ONE 在日本仍缺乏在地社群與歸屬關係，粉絲多半僅在重大賽事或話題對戰時短期聚集。[^5][^1]
### 2.2 Sui × ONE 的既有合作基礎
Sui 自 2024 年起成為 ONE Championship 的官方區塊鏈合作夥伴，已落地的合作包含：Web3 遊戲 ONE Fight Arena、zkLogin 讓粉絲以 Web2 帳號無錢包登入、Walrus 去中心化儲存選手媒體內容、以及 Seal 做內容存取控制等。[^6][^7][^8][^1]

Sui 網路以物件導向模型、高吞吐量與低延遲見長，非常適合作為遊戲化互動與高頻 NFT／數位物件操作的平台，並在粉絲與遊戲應用上已證明可支撐大量使用者。[^9][^10][^11]
### 2.3 日本法規與粉絲經濟環境
日本對體育賭博、線上博彩與高價值獎品有嚴格規範，包含：
- 2025 年相關體育博弈法案遭否決，目前民間體育博彩仍屬嚴格限制領域。[^12][^13]
- 刑法對未授權賭博行為有明確刑事責任，政府可封鎖違規網站與服務。[^13]
- 《景品表示法》對促銷活動中的獎品價值設有上限，避免不當誘引消費。[^14]

此外，日本政府與金融廳正推進對加密資產與代幣的再分類與加強監理，可能將部分 crypto 從支付手段轉為類證券監理，增加投資型代幣產品的合規成本。[^15][^16]

在此環境下，ONE 如要在日本以 Web3 方式經營粉絲，需要一套 **避開投機性代幣與賭博結構、以身份與體驗為核心** 的設計框架。MON 即是基於此前提提出的方案。[^1]
## 3. 核心商業痛點與目標
### 3.1 核心痛點
1. **缺乏日本式的「一門」歸屬結構**  
   ONE 雖有頂級賽事與明星選手，但日本粉絲目前缺乏類似傳統道場／相撲部屋那種「我是某門弟子」的長期身份與社群，難以累積深度忠誠度。[^5][^1]

2. **粉絲資料與觸點分散在外部平台**  
   U‑NEXT 等串流與社群平台掌握大部分觀眾數據，ONE 在日本實際掌握的第一方粉絲資產有限，難以做跨賽事、跨城市的精準運營與再行銷。[^4][^1]

3. **傳統粉絲活動模式難以兼顧合規與創新**  
   預測遊戲、抽獎活動若涉及付費參與與高價獎勵，容易踩到賭博與獎品法規紅線；若完全不做，又無法放大 Web3 粉絲經濟的優勢。[^12][^14][^13][^1]

4. **選手與粉絲間缺乏可持續的日常互動**  
   現有互動多集中在賽前宣傳與賽後短期話題，欠缺日常節奏（訓練、生活、文化）的內容與參與機制，難以形成「跟著門一起生活」的感受。[^17][^1]
### 3.2 MON 的目標
- 建立以「門」為單位的粉絲道場結構，讓粉絲以「門徒」身份長期跟隨選手。  
- 為 ONE 日本與全球總部建立 **可攜帶、可驗證的粉絲身份與行為資料層**。  
- 在不觸碰賭博與投資型代幣的前提下，提供高互動、高留存的榮譽與體驗型獎勵機制。  
- 以 Sui 作為長期技術基礎，使所有粉絲資產（門徒證、徽章、歷史紀錄）在 ONE 離場後仍能留在鏈上，成為長久社群資產。[^10][^1]
## 4. 解決方案概覽：MON 平台設計
### 4.1 核心概念
- **每位 ONE 選手是一個「門」**（MonGate），粉絲不是僅僅追蹤帳號，而是正式「入門」成為門下弟子。  
- **門徒證（MonPass）** 是粉絲的鏈上身份證明，記錄其修行歷程、參與紀錄與榮譽，不可轉讓，以歸屬感優先而非投機。  
- **門番（Monban）** 是每個門的 AI 守門人，負責日常互動、任務設計與社群維護，其身份與部分行為寫在鏈上，以確保可持續性與透明度。[^1]
### 4.2 高階架構
1. **使用者層**：粉絲透過 Web / App 介面以 zkLogin 登入，選擇或掃描指定「門」後入門並取得門徒證。  
2. **應用層**：
   - 任務系統（Quests & Honor XP）
   - 門番 AI 互動介面
   - 內容解鎖與社群功能（聊天室／公告）
3. **鏈上層（Sui）**：
   - MonGate / MonPass / Quest / Badge 等物件  
   - 與 Walrus / Seal 整合做內容存取控制  
4. **營運／分析層**：
   - ONE 與合作夥伴的營運後台（活動設定、數據面板）  
   - 內部 BI 工具串接，觀察門與粉絲行為指標
## 5. MVP 功能規格
### 5.1 粉絲入門與門徒證（MonGate & MonPass）
**5.1.1 功能說明**
- 粉絲以 Google / Apple / X 等帳號透過 Sui zkLogin 登入。[^7][^18]
- 粉絲選擇要入門的選手（例如 Rodtang / 武尊），系統在 Sui 上為其鑄造一個 **MonPass**：
  - 不可轉讓（Soulbound），避免被視為投資商品並加強歸屬感。[^1]
  - 內含門名、入門日期、稱號、等級、累計 XP 與徽章列表等欄位。

**5.1.2 主要需求**
- 支援多門並行：同一粉絲可擁有多張 MonPass（不同門），但每門至少一張。  
- 入門邏輯可設定：開放入門、需邀請碼、需達成特定任務等（寫入 MonGate 規則物件）。  
- MonPass 在鏈上可被其他應用驗證，用於票務、預售、贊助活動等未來場景。[^10]

**5.1.3 非功能需求**
- 入門／鑄造門徒證的 UX 需在 10 秒內完成，gas 由平台補貼，不向粉絲收費。  
- zkLogin 與交易簽名流程需簡化，盡量保持 Web2 體感。[^7]
### 5.2 任務與榮譽系統（Quests & Honor XP）
**5.2.1 功能說明**
- 為每個門設定可重複或一次性的任務（Quest），例如：
  - 賽前「技術猜測」問答（非賭博，只有榮譽獎勵）。
  - 賽事當日掃描現場 QR，取得觀賽證明徽章（PoW）。
- 完成任務後，粉絲獲得 XP 與特定門內徽章，MonPass 狀態在鏈上更新。[^1]

**5.2.2 合規設計**
- 所有任務均 **免費參加**，不收取額外參賽費用，獎勵不為現金或可交易代幣，避免被認定為賭博或投資行為。[^12][^14][^13][^1]
- 獎勵內容包含：
  - 門內稱號升級與展示權。  
  - 解鎖專屬內容或實體體驗抽選資格。  
  - 非高價的實體贈品，符合獎品價值上限規範。[^14]

**5.2.3 鏈上資料結構（概要）**
- `MonGate` object：門的基本資料與規則。  
- `MonPass` object：門徒證；持有者、XP、rank、badges。  
- `Quest` object：任務設定；類型、期間、gate_id、獎勵 XP 與徽章 ID。  
- `Badge` object：可單獨展示的榮譽或成就，可設為不可轉讓或可在門內互贈。[^9][^10]
### 5.3 內容解鎖與 Walrus / Seal 整合
**5.3.1 功能說明**
- 利用 Walrus 儲存選手專屬影片、訓練紀錄、賽後談話等內容；透過 Seal 根據 MonPass 狀態判斷是否有觀看權限。[^8][^19][^1]
- 範例：只有達到某一 XP 門檻或持有特定 PoW 徽章的門徒，才能觀看賽後 locker room 訪談。  

**5.3.2 需求**
- 內容 URL 不直接暴露，需透過 Seal gate 以避免未授權分享。  
- 權限判斷與內容讀取需在使用者體感 1–2 秒內完成。
### 5.4 門番（Monban）AI 守門人 v0
**5.4.1 功能說明（MVP）**
- 每個門對應一個門番 persona，根據選手公開訪談、比賽風格與語錄設計對話風格（例如 Rodtang 守門人偏直率、幽默）。[^1]
- 粉絲在門頁面可與門番對話，門番可：
  - 解釋門規與任務。  
  - 根據粉絲目前 XP／徽章推薦下一步行動。  
  - 在粉絲完成指定互動後觸發鏈上交易（例如授予「師父認可」徽章）。

**5.4.2 技術與治理要求**
- 門番的身份（public key、所屬門）以 `Monban` object 形式寫在鏈上，後續所有由門番觸發的獎勵交易皆可追溯來源。  
- AI 模型本身可先在 off-chain 執行，但需保留與 on-chain 行為的 log 映射，為未來接入更完整的 Agentic Web 基礎設施預留空間。[^10][^20][^1]
### 5.5 營運後台（Admin Console）
**5.5.1 功能說明（MVP 級）**
- 提供 ONE 日本團隊與全球營運團隊：
  - 建立／管理各門（MonGate）。  
  - 設定任務（Quest）與獎勵規則。  
  - 查看門與門徒基本指標（入門人數、DAU、任務完成率）。

**5.5.2 技術需求**
- 後台以 Web2 技術實作，但所有會影響粉絲權益的設定（例如任務是否還開放、獎勵數量）需同步寫入或更新對應的 Sui object，避免「前後台不一致」。[^9][^10]
## 6. 法規與風險管理
### 6.1 日本法規遵循原則
1. **不做賭博或博弈服務**：不設計任何付費預測或賭注池，不提供現金或可交易代幣獎勵，活動僅以榮譽點數與體驗型獎勵為主。[^12][^13][^1]
2. **門徒證非投資商品**：MonPass 為不可轉讓的身份憑證，不承諾收益，也不代表選手未來收入權益，避免被視為證券或投資性權利。[^15][^16][^1]
3. **獎品價值控管**：如提供實體贈品，需符合日本景品表示法的價值限制，並由法務審查活動設計。[^14]
4. **個資與隱私**：
   - 可識別個人資料（姓名、Email 等）儲存在合規的 off-chain 系統，鏈上僅存 pseudonymous ID 與行為記錄。  
   - 遵守 APPI，就資料使用目的、第三方提供與跨境傳輸提供透明說明與同意機制。[^21][^15]
### 6.2 風險與緩解
- **技術風險**：Sui 生態仍在快速演進，需確保基礎組件（錢包、Walrus、Seal、Agent 基礎設施）均有長期維護；可透過與 Mysten Labs 簽署支援協議與共同路線圖降低風險。[^10][^20]
- **營運風險**：若門僅靠少數明星撐起，可能導致其他選手門冷清；需設計跨門任務與平台級活動，平衡流量分配。[^1]
- **法規變動風險**：日本對 crypto 與數位資產規管方向可能持續調整，需與外部法律顧問長期合作，並保留快速調整產品設計的彈性。[^15][^16]
## 7. 為何選用 Sui（而非純 Web2 或其他公鏈）
1. **物件導向模型適合「門」「門徒證」「任務」「徽章」等結構化資產**  
   Sui 的 object‑centric 設計讓每一項資產都有獨立狀態與所有權，更新與查詢都以物件為單位，對應道場與門徒證這種強身份與關係的設計尤為適合。[^9][^10]

2. **高吞吐與低延遲支援高互動粉絲場景**  
   粉絲任務完成、XP 更新與內容解鎖需即時回饋，Sui 的高 TPS 與橫向擴展能力可在高併發情況下維持低交易延遲，避免體驗被「卡交易」破壞。[^10][^22][^23]

3. **zkLogin 與 Web2 友善 UX**  
   對日本一般粉絲而言，傳統加密錢包是巨大阻力；Sui 提供的 zkLogin 允許使用現有 OAuth 帳號創建鏈上身份，保留安全性的同時大幅降低上手門檻。[^7][^18]

4. **與 Walrus、Seal 等工具原生整合**  
   Sui 生態中的 Walrus（儲存）與 Seal（存取控制）為 MON 的 gated content 場景提供一條龍解決方案，不需自行搭建複雜的 Web2/3 混合權限系統。[^8][^19]

5. **與 ONE 既有合作與品牌敘事一致**  
   Sui 已是 ONE 的官方區塊鏈夥伴，雙方在品牌與技術上都已有合作基礎；在此基礎上推出 MON，可強化雙方「把格鬥精神帶入 Web3／Agentic Web」的長期敘事。[^6][^20][^1]
## 8. 未來展望與擴張路線
### 8.1 功能深化
- **道場／Gym Network 整合**：將日本各地道場與健身房納入 MON，讓門徒可以在線下「修行打卡」，形成線上門與線下實體據點的整合網路。  
- **Samurai Arena Experiences**：將 ONE Samurai 場館檔期切分為多個體驗 Pass（後台導覽、選手見面會等），以 Sui 資產形式銷售與分配，提升場館利用率與賽事日收入。  
- **Compliance Studio 模組化**：把合規設計抽象為可重用模組，讓 ONE 行銷團隊能在 MON 上安全設計新玩法並自動評估法規風險。[^1]
### 8.2 商業模式與 KPI
- **收入來源**：
  - 平台級贊助（品牌贊助 MON 平台與特定門）。  
  - 體驗型付費 Pass（場館體驗、線上課程），在合規框架下由 ONE 收取費用。  
  - B2B SaaS：向道場／健身房提供會員管理與成就系統。  
- **核心 KPI**：
  - 入門門徒數與多門持有比例。  
  - 門徒 30/90/180 天留存率。  
  - 任務參與率與內容解鎖次數。  
  - 對票房與 PPV 購買轉換率的提升。[^17][^1]
### 8.3 地域與項目擴展
- 將 MON 模型複製到韓國、泰國等 ONE 核心市場，依各國武術文化調整「門」的細節設定。  
- 擴展到除格鬥以外的 ONE 品牌內容，如格鬥健身課程、青少年培訓與社區賽事。[^2][^24]
## 9. 研究與設計依據說明
MON 的設計與本規格書內容，主要基於以下幾類研究與資料來源：

1. **ONE × Sui 官方資訊與報導**：
   - ONE Samurai 日本長期賽事與 U‑NEXT 串流合作相關新聞與官方新聞稿。[^3][^2][^4]
   - Sui 與 ONE 的合作公告與現有產品（ONE Fight Arena、zkLogin、Walrus、Seal 等）。[^6][^7][^8][^1]

2. **日本格鬥與體育娛樂市場分析**：
   - 關於 RIZIN 與日本格鬥市場的觀察與粉絲行為分析。[^5]
   - 日本體育場館與體育娛樂空間未充分利用的報導與專家訪談。[^17][^25][^26]

3. **日本法規與 Web3 政策動向**：
   - 體育博弈、賭博規制與獎品價值限制的法律實務與評論。[^12][^14][^13]
   - 日本對加密資產與代幣分類的最新政策與研究報告。[^21][^15][^16]

4. **Sui 技術與生態研究**：
   - Sui 物件導向模型、性能與與其他公鏈比較的技術文檔與分析。[^9][^10][^22]
   - Sui 在遊戲、NFT 與 Agentic Web 方向的應用案例與官方部落格。[^11][^23][^6]

5. **內部策略研究文件**：
   - 《ONE Samurai × 門（MON） Sui Hackathon 戰略研究報告》，提供文化洞察、商業假設、合規策略與初步產品構想。[^1]

上述研究確保 MON 方案在文化、商業、技術與法規四個層面均有扎實依據，為後續產品驗證與投資決策提供可信基礎。

---

## References

1. [ONE_Samurai_MON_Strategy.docx]()

2. [ONE Championship Continues Japanese Expansion, ONE Samurai ...](https://cagesidepress.com/2026/02/19/one-championship-continues-japanese-expansion-one-samurai-announced/) - ONE Samurai has been announced by ONE Championship and will feature monthly events hosted in Japan b...

3. [ONE Launches Monthly ONE Samurai Event Series in Japan](https://beyondkick.com/news/breaking-one-launches-monthly-one-samurai-event-series-in-japan-starting-with-their-ppv-in-april/) - ONE Championship announced a new Japan-centered event series on February 18 in Tokyo, unveiling “ONE...

4. [ONE Championship Launches ONE Samurai With Monthly Events In ...](https://www.onefc.com/press-releases/one-championship-launches-one-samurai-with-monthly-events-in-japan/) - The inaugural ONE Samurai event will take place on April 29 at Ariake Arena in Tokyo, Japan. Related...

5. [RIZIN Fighting Federation's Rise in Japan's Combat Sports ...](https://www.linkedin.com/posts/red-lantern-digital-media_redlantern-rlinsights-combatsports-activity-7414221814656192512-6vy1) - Viewers gain free access to 24/7 FAST channels, live events, and premium sports content. FLS employs...

6. [Gaming on Sui - Sui Documentation](https://docs.sui.io/concepts/gaming) - Gaming on Sui leverages blockchain technology to enhance in-game economies, ownership, and interacti...

7. [Sui Features | zkLogin](https://www.sui.io/zklogin) - zkLogin makes engaging with dApps built on Sui as simple as signing in with familiar web credentials...

8. [How Walrus Protocol and Sui Network are changing Web3 - LinkedIn](https://www.linkedin.com/posts/emmanuel-abiodun_with-sui-network-walrus-protocol-seal-activity-7335290142628188161-z4vV) - With Sui Network, Walrus Protocol, Seal, and Nautilus, we've built a unified Web3 stack that no othe...

9. [Exploring Sui's Object-Centric Model and the Move ...](https://www.gate.com/learn/articles/exploring-suis-object-centric-model-and-the-move-programming-language/4497) - This article examines Sui's object-centric data storage model, its implications for transaction proc...

10. [Sui Network: A High-Speed, Object-Centric Blockchain](https://allsparkresearch.com/research/sui-network/) - Its goal is to resolve issues of scalability and efficiency in blockchain ecosystems, focusing on hi...

11. [What Makes Sui Become The Gaming Heaven For Projects?](https://suipiens.com/blog/what-makes-sui-become-the-gaming-heaven-for-projects/) - Discover why Sui has become the ultimate gaming heaven for projects. Experience scalability, dynamic...

12. [Japan's Esports Sector Grapples with Strict Gambling Laws ...](https://www.igamingtoday.com/japans-esports-sector-grapples-with-strict-gambling-laws-and-regulatory-maze/) - Historically, Japan's Premiums Act imposed a JPY100,000 cap on tournament prizes, viewing publisher-...

13. [Gambling Laws and Regulations Report 2026 Japan](https://iclg.com/practice-areas/gambling-laws-and-regulations/japan) - This article explores gambling laws and regulations in Japan, discussing licence restrictions, enfor...

14. [Gaming Law 2025 - Japan - Global Practice Guides](https://practiceguides.chambers.com/practice-guides/gaming-law-2025/japan/trends-and-developments) - If an esports event is regulated by the Amusement Business Act, the prize money for such esports eve...

15. [Reframing Cryptoasset Regulation in Japan: Insights from ...](https://www.nri.com/en/media/column/nri_finsights/20260108.html) - Cryptoasset exchange operators are required to register with the Financial Services Agency (Article ...

16. [Overview of the Draft Report on the Cryptoasset System ...](https://innovationlaw.jp/en/cryptoasset-regulation-wg-report-2025/) - The scope of regulation shall be cryptoassets under the current law (PSA); Stablecoins are excluded....

17. [The Possibilities and Future of Sports Entertainment ...](https://www.nomlog.nomurakougei.co.jp/article/detail/93/?wovn=en) - The key is how to provide experiences that cannot be experienced without going to the venue and the ...

18. [NandyBa/sui-zklogin - GitHub](https://github.com/NandyBa/sui-zklogin) - A simple React app that lets users create a Sui zkLogin address and send a transaction using various...

19. [Things That Work Sui Stack Sui Walrus (storage) 🛡️ Seal ...](https://x.com/SuiNetwork/status/1967659819311173967) - Things That Work └ Sui Stack ├ Sui ├ Walrus (storage) ├ 🛡️ Seal (encryption & access control) ├ 🕸️ N...

20. [Partnerships and ecosystem growth in 2025 - - - - - Sui's ...](https://x.com/ahboyash/status/2003838847696945486) - The Sui tech stack has a unique object-centric model, safety ... high-throughput, low-latency dApps ...

21. [The Japanese Web3 Market in 2024: Government Policies ...](https://www.gate.com/learn/articles/the-japanese-web3-market-in-2024-government-policies-corporate-trends-and-prospects-for-2025/5286) - In February 2024, Japan's Ministry of Economy, Trade, and Industry approved a legal amendment permit...

22. [Comparison](https://docs.sui.io/references/sui-compared) - The key advantage of this approach is low latency; each successful transaction quickly obtains a cer...

23. [How Sui Supports Every Type of Web3 Game](https://blog.sui.io/supporting-every-web3-gaming-type/) - Dynamic NFTs and onchain data updates: Games where NFTs evolve and game progress is stored, allowing...

24. [ONE Championship Offers Exciting 2026 Slate Of Action! - MMA Sucka](https://mmasucka.com/one-championship-offers-exciting-2026-slate-action/) - ONE Championship's return to Tokyo's Ariake Arena follows the historic success of ONE 173, which fea...

25. [Japan Kicks around New Sports Stadium Concepts Amid ...](https://japannews.yomiuri.co.jp/society/general-news/20201224-160087/) - In the case of new sports facilities under construction, the challenges will be how to deal with mai...

26. [Azusa Sekkei Unleashes the Potential of Stadiums and ...](https://jspin.mext.go.jp/en/contents/azusa-sekkei/) - The author will discuss these questions based on the experience of Azusa Sekkei, a Japanese architec...

