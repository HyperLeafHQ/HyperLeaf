# Grok bot — frontend copy

This file is for the **frontend** bot (hyperleaf.finance, landing, this preview). Not for Solidity. Not for testnet deploy.

`L` / `C1` / `C2` / `Kind` / `Native` / `ve-NFT` are **GitHub and contracts only**. If a user sees those strings, the frontend is wrong.

## What the protocol does

HyperLeaf is infrastructure. It is responsible for:

1. **Ingress** — lock a transferable receipt (or an address-keyed position), message it, mint one Leaf ticker per listing.
2. **Availability** — bridge starts closed; caps; pause; health; listing isolation. A halt on hxSQUID must not touch hNEST.
3. **Yield split** — depends on the listing (`docs/YIELD_OWNERSHIP.md`). Share-price tickers (hcbETH): 99% stays in the receipt, protocol skims 1%. Side-token tickers (hxSQUID): extra income → WHYPE, 99% allocated across `totalSupply`, 1% protocol. Do not show wallet APR = 99% × harvested ÷ supply on Rewarder tickers.

It is **not** a market maker, not a DEX, not an AMM, not a lending pool.

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

挂单确认必须写（整段，不要拆掉）：

> 挂进转让板之后，在成交或取消之前，这份 Leaf 的 HYPE 收益会停止，记在板上（归协议）。没人买可以取消，不另扣费。折价是有人接盘的价格，不是底仓没了。

> 出货有两条路。我们这条：挂单等下一个本来要存入的人来买，操作简单。你也可以自己去 DEX 做**单边 LP**（只放 Leaf、自己定价格），那是给会做深度 DeFi 的人用的，我们不代操作。

> 对比：DEX 单边 LP **没有** HyperLeaf 的 HYPE 收益，但能赚交易手续费。转让板 **没有** HYPE 收益，也 **没有** 交易手续费，成交时还要从你的要价里拿出 **1% 给买方**（接盘奖励，不是协议抽成）。相当于让出 1% 换更简单的撮合。

Copy: 没人出价就不成交。协议不接盘。跨链成交若有 LZ 费，是 LayerZero 收的，不是我们的。ACK 丢了会重试，不会铸新的 Leaf。买方中止要等三天（guardian 可立刻中止）。Not 债务, not 借贷, not 官方收单. Instant-receipt 烧掉就能拿回的票默认不上板。Details: `docs/CLAIM_MARKET.md`.


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
| hcbETH | **No 领取 HYPE for holders.** PoS stays in cbETH. Protocol skims 1% of the rate surplus (sold to HYPE). Copy: 质押收益留在这份收据里，做市和借贷也能拿到。协议从增值里抽 1%。赎回拿回的是金库按份额能付的 cbETH。 |
| hgSOON, hsWBERA, Morpho shares | **No claim button.** Yield-in-the-share: wrap 1 share, unwrap 1 share. Do not copy either hcbETH skim or hxSQUID claim onto them. |

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

Tickers whose yield stays in the share (`hgSOON`, `hsWBERA`, Morpho unless `rateKind`+`toHype`) have **no** HYPE claim in any of the rows above.

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
| Claim board (if it exists) | 转让，不是现货，不是债。没人买就不成交。协议不接盘。挂单期间 HYPE 归协议。 |
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
