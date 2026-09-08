# Grok bot — frontend copy

This file is for the **frontend** bot (hyperleaf.finance, landing, this preview). Not for Solidity. Not for testnet deploy.

`L` / `C1` / `C2` / `Kind` / `Native` / `ve-NFT` are **GitHub and contracts only**. If a user sees those strings, the frontend is wrong.

## Key narrative (landing first screen)

Lead with this, in this order. Do not bury it under wrap mechanics.

1. **What you do:** 用其他链的生息资产，在 HyperEVM 上赚 HYPE。
2. **Where HYPE comes from:** 底层资产自己的代币排放，或源协议已经在分的真实收入。HyperLeaf 把它换成 HYPE。
3. **What we do not do:** 不另发收益、不加积分、不做空投激励。只抽已产生收益的 1%。

Hero ZH:

> 用其他链的生息资产，赚 HYPE。
>
> 把 Base、以太坊、BSC、Avalanche 上已经在生息的收据锁进来，铸成 Leaf。多余的收益打成 HYPE。
>
> HYPE 从哪来：底层资产自己的代币经济排放，或那个协议已经在分的真实收入。HyperLeaf 不额外提供任何收益、积分或激励。

Hero EN:

> Earn HYPE from productive assets on other chains.
> HYPE is those protocols’ own emissions or revenue, converted. HyperLeaf does not add yield, points, or incentives.

Then the “HYPE 从哪来” table. Two ways to receive, not one:

- extra token (QUID, Avantis rewards, GHO) → 换成 HYPE，钱包领取
- rate / share (cbETH, gSOON, sAVAX) → 99% 留在收据，协议抽 1%

Wrap / Leaf / 退出 are the *how*. HYPE from foreign yield is the *why*.

## What the protocol does

HyperLeaf is infrastructure. It is responsible for:

1. **Ingress** — lock a transferable receipt (or an address-keyed position), message it, mint one Leaf ticker per listing.
2. **Availability** — three independent flags, never collapse them:
   - bridge closed ≠ unhealthy
   - paused ≠ insolvent
   - health Degraded = mint stopped, redeem may still work
   A halt on hxSQUID must not touch hNEST. `maxPerDay` is per listing per chain, not one global daily cap.
3. **Yield split** — depends on the listing (`docs/YIELD_OWNERSHIP.md`). Share-price tickers (hcbETH): 99% stays in the receipt, protocol skims 1%. Side-token tickers (hxSQUID): extra income → WHYPE, 99% allocated across `totalSupply`, 1% protocol. Do not show wallet APR = 99% × harvested ÷ supply on Rewarder tickers.

It is **not** a market maker, not a DEX, not an AMM, not a lending pool.

## Yield is never HyperLeaf-made

Landing, ticker cards, vault, and 规则 must say this. All HYPE (or remaining-receipt NAV) comes from:

1. the inner asset’s own token emissions, or
2. that protocol’s real revenue share (staking, fees, safety-module rewards).

HyperLeaf does **not**:

- print extra HYPE as a subsidy
- run points / seasons / quests / airdrop campaigns
- match deposits with protocol-owned yield

Required ZH (landing + 规则 + 金库 intro):

> 所有收益来自资产本身的代币经济排放，或协议已经在分的真实收入。HyperLeaf 不额外提供任何收益、积分或激励。协议只从已经产生的收益里抽 1%。

Required EN:

> Yield is the inner protocol’s own emissions or revenue. HyperLeaf does not add yield, points, or incentives. The 1% take is of realized yield only.

Rate-vault dust (hcbETH, hgSOON, hsAVAX, hJitoSOL — all `retainRateYield`):

Required ZH (规则 / 金库 FAQ，不要放英雄区):

> 协议抽的是已经记账的增值的 1%，按代币最小单位向下取整。金库很小时这一刀经常是 0：灰尘留给持有人，协议不补抽，也不倒扣本金。不要把「抽 1%」理解成金库一有余额我们就在赚钱。

Required EN:

> The 1% is of booked yield, floored to the inner token’s smallest unit. On a small vault that cut is often zero — holders keep the dust, the protocol does not claw it later and does not touch principal. Do not imply the protocol is earning 1% whenever TVL is tiny.

Do not show a protocol APR, “我们已经抽到 X HYPE”, or a yield counter on an empty / dust vault.

Show a “HYPE 从哪来” table with the productive listings (hxSQUID, hAVNT, hcbETH, hgSOON, hsAVAX, hstkwaUSDC, hsETHFI, Morpho, hORDER, BLUAI4Y, and later **hJitoSOL**). Each row: origin + how the user sees it (钱包领取 vs 留在收据). Parked tickers with frozen rewards stay off that table.

When hJitoSOL is on the UI, the HYPE row is:

| 票 | 收益从哪来 | 用户看到 |
| --- | --- | --- |
| hJitoSOL | Jito 质押池：通胀 + 已经进池子的 MEV/TOV，写在 JitoSOL/SOL 汇率里 | 99% 留在收据（赎回的 JitoSOL 更少、代表的 SOL 仍在），协议抽 1% 换成 HYPE |

Do **not** write “HyperLeaf APR”, “我们发 HYPE”, “积分季节”, “存入送分”.

## Why hJitoSOL, not the NCN restaked token

Users will ask why we wrap **JitoSOL** instead of fragSOL / kySOL / ezSOL (Jito restaking VRTs that earn Switchboard SWTCH etc.). This is a **product choice**, not a gap we missed. Say it on the ticker page (ZH + EN). Do not hide NCN.

Required ZH (hJitoSOL 金库 / 规则):

> 我们收的是 JitoSOL 本身：Solana 上最大的流动性质押收据，收益在汇率里，没有额外罚没。
>
> Jito 还有一层 Restaking（NCN）：把 JitoSOL 再存进 Vault，会拿到 **fragSOL / kySOL / ezSOL** 这种凭证，并可能拿到 Switchboard 等网络的额外奖励。那些凭证我们列在观察名单，**这期不做**。原因不是不知道，而是：再质押会把底仓暴露给节点罚没，赎回还要排队，fragSOL 还带 Token-2022 转账钩子。HyperLeaf 这期只把「已经在生息、可即时赎回的 JitoSOL」引进 HyperEVM。想拿 NCN 奖励的人，解开 hJitoSOL 之后可以自己去 Jito Vault 做。

Required EN:

> hJitoSOL wraps JitoSOL — the liquid staking receipt. Staking and MEV already sit in its exchange rate. No extra slashing.
>
> Jito restaking (NCNs) mints a **different** receipt (fragSOL, kySOL, ezSOL) if you deposit JitoSOL into a Vault. Those can earn Switchboard and other NCN rewards. We know they exist; they are on the watchlist, not this listing. Restaking adds operator slashing and an unstake queue. fragSOL also uses Token-2022 transfer hooks. If you want NCN yield, unwrap to JitoSOL and restake on Solana yourself.

Do **not** write: “Jito 没有额外奖励”, “我们不支持 restaking 因为还没做”, “fragSOL 和 JitoSOL 是同一个东西”.

Redeem / wrap for this ticker is **not** an EVM `sendTo`:

Required ZH:

> 赎回 hJitoSOL 必须填 **Solana 地址**（32 字节公钥），不是 EVM 地址。填错会把 JitoSOL 打到没人能用的账户。跨链费是 LayerZero 收的最低标准，HyperLeaf 不从中抽成。赎回拿到的是金库里剩下的 JitoSOL，不是当初那一枚；汇率涨出来的 99% 已经留在收据里。

Required EN:

> Redeem hJitoSOL to a **Solana pubkey**, never an EVM address. A 20-byte address would credit an ATA nobody owns. LZ fees are LayerZero’s floor, not ours. You get remaining JitoSOL, not the original count — 99% of rate yield stayed in the receipt.

No wallet HYPE claim on this ticker. Do not show a Claim HYPE button.

## What the protocol does not do

Do not write, imply, or let a tooltip say any of these:

- HyperLeaf guarantees someone will buy the ticker
- HyperLeaf guarantees exit at NAV
- HyperLeaf guarantees a book, spread, or Core spot listing
- HyperLeaf treasury will buy your Leaf if nobody else does
- A claim-board discount is a loan or a HyperLeaf debt
- “Liquid” means the protocol pays 1:1
- A discount to NAV is a HyperLeaf depeg

A discount on a **sell-only** ticker is a **liquidity price** only while that listing’s health is Normal and the SOLVENCY row still holds. Map health to copy:

| Health (GitHub, never show the enum) | What the user sees on a discount |
| ----------------------------------- | -------------------------------- |
| Normal | 这是有人接盘的价格，不是底仓没了。 |
| Degraded / proof stale | 底仓证明不新鲜或上游异常。折价里可能有风险，不要写成普通流动性折价。 |
| Halted / Insolvent | 不要标「折价买」。说底仓或桥出了问题，暂停买入建议。 |

Face value for any 转让 board is that ticker’s SOLVENCY accounting unit (remaining cbETH, 1:1 xSQUID, ORDER `ledgerPrincipal`, …), never a USD print we invent.


Do **not** ship an AMM as the first HyperEVM “liquidity”. If a secondary board exists, it is **转让这份 Leaf**：想退出的人把 Leaf 挂进托管，下一个本来要存入的人用底仓买走，协议不铸新的 Leaf、不成交对手方。

挂单确认（后两段永远写。第一段按 listing 选）：

**有 Rewarder 的票（hxSQUID 类、以及会摊 WHYPE 的 Closed OFT）：**

> 挂进转让板之后，在成交或取消之前，这份 Leaf 的 HYPE 收益会停止，记在板上（归协议）。没人买可以取消，不另扣费。挂单价格按挂单时锁定，不会跟着账面价值变。折价是有人接盘的价格，不是底仓没了。

**hNEST / 没有 Rewarder 的票：不要写「挂单期间 HYPE 归协议」。改写：**

> 这条没有 HyperLeaf 的 HYPE 领取。挂单只是把票交给托管，没人买可以取消，不另扣费。挂单价格按挂单时锁定，不会跟着账面价值变。折价是有人接盘的价格，不是底仓没了。

然后两段共用：

> 出货有两条路。我们这条：挂单等下一个本来要存入的人来买，操作简单。你也可以自己去 DEX 做**单边 LP**（只放 Leaf、自己定价格），那是给会做深度 DeFi 的人用的，我们不代操作。

> 对比：DEX 单边 LP **没有** HyperLeaf 的 HYPE 收益，但能赚交易手续费。转让板 **没有** 交易手续费，成交时还要从你的要价里拿出 **1% 给买方**（接盘奖励 / buyer incentive，不是协议抽成）。相当于让出 1% 换更简单的撮合。

成交状态（Indexer / UI 必须分开）：

| 链上看到 | 用户看到 |
| -------- | -------- |
| dest `LeafReleased`，源链还是 Escrowed | 票已交给买方，等源链付款。不要写已完成。 |
| 源链 `Paid` | 成交完成。卖方 99%，买方 1%。 |
| `fillLocal` 的 `Filled` | 同链，这一笔已经完成。 |

ACK 丢了：重试，不铸新票。买方中止要等三天。

C1（没有官方赎回）和 hNEST（有窗口、只是提前走）**不要做成同一个「卖出现货」入口**。C1：这是协议里唯一的退出。hNEST：官方窗口仍在，这是提前找人接。

Copy: 没人出价就不成交。协议不接盘、不做市、不保证最低退出价。跨链成交若有 LZ 费，是 LayerZero 收的，不是我们的。ACK 丢了会重试，不会铸新的 Leaf。买方中止要等三天（guardian 可立刻中止）。**中止中 ≠ 已退款**：目的链若已放票，中止会变成付款给卖方。成交看源链 `Paid`，不要看目的链放票。Not 债务, not 借贷, not 官方收单, not DEX. Instant-receipt 烧掉就能拿回的票默认不上板。Details: `docs/CLAIM_MARKET.md`.


**One line that must survive every rewrite:**

> HyperLeaf 只做基建、可用性和收益分配。不保证市场上有人买，不保证能按账面价卖掉。

English:

> HyperLeaf provides infrastructure, availability, and yield split. It does not guarantee a buyer, a book, or exit at NAV.

## Exit copy (use these, not L/C1/C2)

| GitHub | User-facing badge | How-to-exit (detail) |
| ------ | ----------------- | -------------------- |
| L | 烧掉就能拿回 | 烧掉 Leaf，马上拿回原来那份收据。想变现货，自己去官方解押。 |
| C1 | 只能卖掉 | 协议不赎回。可以挂转让板（简单，成交扣 1% 给买方），或自己去 DEX 单边 LP（有交易费、没 HYPE）。低于账面价是有人接盘的价格，不是底仓没了。 |
| C2 | 烧掉后等几天 | 烧掉 Leaf，等窗口，再去源链领。金库不会因为排队而亏净值。 |
| hNEST | 按窗口取出 | 按 Nest 自己的窗口拿回 NEST，大约六个月，不是随时 1:1。也可以把 hNEST 挂到转让板，用折价提前走（成交才走，协议不接盘）。 |
| blocked / parked | 暂不做 | Do not offer a deposit. Say why in one sentence from ROADMAP. |

Filters, nav, cards, toasts: the left column never appears. “同一套 L 适配器” is also forbidden.

## Redeem is a burn. There is no cancel.

Protocol exit **burns the Leaf first**. This is intentional (no half-state, no “undo queue” that still looks like a Leaf).

Do **not** ship Cancel / 撤销赎回 / “I changed my mind”. That button does not exist in the contracts.

| If they already… | What is true | UI |
| ---------------- | ------------ | -- |
| Burned an instant-receipt ticker | Leaf is gone. Receipt is in flight or already back on source. | Confirm copy before send: 烧掉之后不能撤回。 |
| Burned a queued ticker (C2 / hNEST `requestWithdraw`) | Leaf is gone **and** they do not have the inner yet. Ticket waits `eta`. | 排队中不能取消。到期去源链领取。期间既没有 Leaf，也还没有收据。 |
| Want Leaf again after they hold the receipt | That is a **new wrap**. New LZ fee (paid to LayerZero, not us). New mint. | Label it 再次存入 / wrap again. Never 取消赎回 or 恢复铸造. |
| Hold a sell-only ticker | There is no protocol redeem to cancel. | Only 卖掉. |

`abortCredit` is owner/guardian after halt — not a user cancel. Do not surface it.

**Copy that must sit on every redeem confirm:**

> 赎回会烧掉这份 Leaf，不能取消。想再拿 Leaf，要拿回收据之后重新存入。

English:

> Redeem burns this Leaf. It cannot be cancelled. To hold a Leaf again, wrap the receipt in a new deposit.

Add the same line to the queued-state screen, or users will think they can abort the wait.

## Claim HYPE is not on every ticker

Only show 领取 HYPE when `listings/catalog.json` `yield.toHype` is non-empty **and lists a holder-facing token** (QUID, airdrop ERC-20s). `protocolFee` / empty `toHype` = no claim button.

| Ticker | UI |
| ------ | -- |
| hxSQUID | 领取 WHYPE. Does not burn the Leaf. Extra QUID, not the xSQUID. |
| hcbETH | **No 领取 HYPE for holders.** PoS stays in cbETH. Protocol skims 1% of the rate surplus (sold to HYPE). Copy: 质押收益留在这份收据里，做市和借贷也能拿到。协议从增值里抽 1%。存入或赎回会先结算这一刀，新用户不替旧涨幅付钱。赎回拿回的是金库按份额能付的 cbETH。 |
| hgSOON | **Same as hcbETH.** No 领取 HYPE. gSOON/SOON rate stays in the receipt. Protocol skims 1% of surplus. Copy: 赎回拿回的是剩下的 gSOON，不是当初那一枚。永远不要帮用户冷却或 90 天锁。 |
| hsAVAX | **Same as hcbETH.** No 领取 HYPE. Copy: 赎回拿回 sAVAX，不是 AVAX。不要帮用户 requestUnlock。 |
| hstkwaUSDC | Rate 1% like hcbETH **plus** 领取 WHYPE for Umbrella GHO/AAVE after converter notify. Copy: 赎回拿回的是 stk v1 收据，不是 USDC。协议不会帮你 cooldown。 |
| hsWBERA, Morpho shares | **No claim button.** Yield-in-the-share until that listing opts into `rateKind`. Do not copy hcbETH skim onto them until SOLVENCY says so. |

Do not invent “偶发空投” for cbETH. After the 1% skim, 1 hcbETH unwraps slightly less cbETH; that remaining cbETH is worth more ETH. Do not say holders claim HYPE for cbETH PoS.


Who can actually receive that button’s money is **not** “anyone who ever wrapped”. See **Who gets HYPE** below.

## Who gets HYPE (wallet vs transfer vs LP)

This is how `LeafHypeRewarder` actually books. Copy that disagrees is a bug.

HYPE is **not** inside the Leaf. Leaf does **not** rebase. Pending WHYPE is **per address**, settled on every mint / burn / transfer (`LeafOFT._update` → `settle` then `updateDebt`). Already-notified yield stays with the address that held the Leaf at settle time. The token that leaves does **not** carry that yield.

`notify` splits 99% by **current `totalSupply()`**. Every Leaf counts in the denominator: wallets, AMM pairs, lending pools, CEX hot wallets, dead addresses. The 99% slice for an address that never calls `claim` stays in the rewarder as that address’s `accrued`. Uniswap pairs never claim. That is expected, not a depeg.

### State → claim (user language)

| 用户在做什么 | 已经 notify 过的 HYPE | 之后再 notify 的 HYPE | UI |
| ------------ | --------------------- | --------------------- | -- |
| 钱包里拿着 Leaf | 他自己的，随时领，不烧 Leaf | 按当时余额摊 | 显示 领取 HYPE（仅 `toHype` 非空的 ticker） |
| 转给别人 / 链上成交 | **卖方留下**。买方这笔为 0 | 买方从拿到之后才开始摊 | 成交后卖方仍可领已发生的；不要写「收益跟币走」 |
| 加进 AMM 做 LP | 加池那一刻结算给钱包，仍可领 | **摊给交易对合约**，不是 LP 凭证 | **不要**在做市页写「做 LP 也能领 HYPE」 |
| 存进借贷 / 金库 | 存入时结算给钱包 | **摊给那个池子地址** | 同上：仓位凭证领不到 HyperLeaf 这笔 |
| CEX / 桥 / 托管 | 转入时结算给提币地址 | 摊给热钱包 | 不要承诺「充进交易所还能领」 |
| 烧掉赎回 | 烧掉前结算，仍可领已发生的 | 没币了，不再摊 | 领取和赎回是两件事；赎回确认不代替领取 |

hNEST does **not** use this rewarder. Do not put 领取 HYPE on hNEST.

Tickers with `retainRateYield` (`hcbETH`, `hgSOON`, later `hsAVAX`) have **no** holder HYPE claim. Copy must say remaining receipt, not 1:1. `hsWBERA` / Morpho stay 1 share = 1 share until their row opts in.

### Copy that must appear

On every 领取 HYPE surface (wallet / vault / ticker detail):

> 只有 Leaf 还在你钱包里的时候，之后的 HYPE 才算你的。转走、卖掉、拿去做市或借贷，已经发生的归你，后面的归新地址。

English:

> Later HYPE accrues only while the Leaf sits in your wallet. Transfer, sell, LP, or lend: already-notified yield stays with you; future yield follows the new holder address.

On LP / lending / “utility” pages, if you mention this ticker at all:

> 做市和借贷拿的是盘口费或利息，不是 HyperLeaf 这笔 HYPE。那份记在池子地址上，池子不会来领。

Do **not** ship:

- 「只要持有就能领」 without saying **钱包持有**
- 「做成 LP 也能挖 HYPE」
- 「收益跟币走 / 买方吃到卖方没领的」
- 「存进 HyperLend 自动复利 HYPE」
- a claim button bound to an LP token, receipt NFT, or vault share that is not the Leaf

There is **no** gauge, bribe, or Chef stake in this protocol. If product later wants “stake Leaf / vote-lock to earn”, that is a new contract. Until then the UI must not pretend LP is a staking position.

Claim is `msg.sender`’s own `accrued`. A pair or pool cannot be claimed on behalf of LPs. Do not add “claim for the pool”.

## Risk labels (required on the surface)

Show these where a holder can deposit or even just browse tickers. Do not bury them in GitHub.

| When | Label |
| ---- | ----- |
| Always | 合约未经外部审计。架构由人定，实现由 AI 写。 |
| Always | 不保证市场上有人买，不保证能按账面价卖掉。 |
| Always | 跨链费是 LayerZero 收的最低标准，付给 LZ，不是付给 HyperLeaf。协议不从中获利。送达不是即时到账。 |
| Caps / pause live | 有上限，可暂停。 |
| Sell-only ticker | 可以长期低于账面价。那是流动性价格，除非底仓没了。 |
| Claim board (if it exists) | 转让，不是现货，不是债。没人买就不成交。协议不接盘。1% 给买方，不是协议抽成。有 Rewarder 的票：挂单期间 HYPE 归协议。hNEST：不要写这条。跨链成交看源链 Paid，不要看目的链放票。 |
| Instant-receipt ticker | 赎回的是收据，不是现货。官方解押要你自己去点。 |
| Window ticker (hNEST, queued) | 取出跟官方窗口走，不是随时 1:1。烧掉即进入队列，不能取消。 |
| Redeem confirm (every listing that burns) | 赎回会烧掉这份 Leaf，不能取消。 |
| Airdrops / points | 记在金库地址上，要等收获。不是随时可领的 HYPE。 |
| Any ticker with 领取 HYPE | 只有钱包持有才继续摊 HYPE。做 LP、去借贷、放进交易所，后面的归那个地址，通常领不出来。 |
| Every listing | 底层协议可以改规则。HyperLeaf 不替它们偿付。 |

Do not say audited. Do not say auto-compound NAV while `recordCompound` is disabled (`PRODUCT_COPY_YIELD.md`).

## LayerZero fees (not ours)

Any wrap, redeem, or 转让板跨链成交旁都要写：

> 这笔是 LayerZero 收取的跨链费（按对方最低标准），付给 LayerZero，HyperLeaf 不抽成、不加价。

Do not put it under “协议手续费”. The 1% buyer reward on the board is **not** an LZ fee. Converter / harvest hops are keeper-paid, not a user LZ line.

English:

> LayerZero fee, at their minimum. Paid to LayerZero. HyperLeaf does not take it.

## Words that are not synonyms (user language)

| 你看到的 | 意思 | 不是 |
| ------- | ---- | ---- |
| 有底仓 | 供给背后真有能拿回来的东西 | 今天就能按账面价退出 |
| 能赎回 | 烧掉之后有一条回家的路 | 盘口一定很深 |
| 有人买 | HyperEVM 上有人出价 | 协议保证 1:1 |
| 一张票 | 同一个 ticker 是同一种债权 | 每条资产退出方式都一样 |
| 能领 HYPE | 这笔 ticker 会把额外收益打成 WHYPE，且 Leaf 此刻在该钱包 | 做 LP / 借贷 / 放交易所也能领；也不是所有 ticker 都有领取按钮 |

`Backed` / `Redeemable` / `Liquid` / `Fungible` stay in README. Do not put those four English words on the product.

## Source of listing facts

Order and “never wrap”: `docs/ROADMAP.md`, `listings/catalog.json`.
Why a ticker may exist: `docs/SOLVENCY.md`.
Yield wording: `docs/PRODUCT_COPY_YIELD.md`, `docs/HYPE_YIELD.md`.
Who earns HYPE after transfer / LP / lend: this file, **Who gets HYPE**. On-chain: `src/lz/LeafHypeRewarder.sol`, `LeafOFT._update`, `testTransferSettlesSellerKeepsHype`, `testPairShareStaysUnclaimed`. Why LP dilutes APR and what we will **not** ship without a product call: `docs/HYPE_COMPOSABILITY.md`.

If GitHub and the UI disagree on an exit, GitHub wins and the UI is a bug.

**Preview:** do not chase this file with UI edits unless the human asks. Copy here is the source of truth for the frontend bot; the in-sandbox preview is updated only on request.
