# Grok bot — frontend copy

This file is for the **frontend** bot (hyperleaf.finance, landing, this preview). Not for Solidity. Not for testnet deploy.

`L` / `C1` / `C2` / `Kind` / `Native` / `ve-NFT` are **GitHub and contracts only**. If a user sees those strings, the frontend is wrong.

## What the protocol does

HyperLeaf is infrastructure. It is responsible for:

1. **Ingress** — lock a transferable receipt (or an address-keyed position), message it, mint one Leaf ticker per listing.
2. **Availability** — bridge starts closed; caps; pause; health; listing isolation. A halt on hxSQUID must not touch hNEST.
3. **Yield split** — extra staking income (not the inner receipt) → WHYPE. 99% to holders, 1% protocol. No lock/unlock fee.

It is **not** a market maker, not a DEX, not an AMM, not a lending pool.

## What the protocol does not do

Do not write, imply, or let a tooltip say any of these:

- HyperLeaf guarantees someone will buy the ticker
- HyperLeaf guarantees exit at NAV
- HyperLeaf guarantees a book, spread, or Core spot listing
- “Liquid” means the protocol pays 1:1
- A discount to NAV is a HyperLeaf depeg

A discount on a **sell-only** ticker is a **liquidity price**, unless `docs/SOLVENCY.md` backing is gone. Then it is insolvency, and you say that.

**One line that must survive every rewrite:**

> HyperLeaf 只做基建、可用性和收益分配。不保证市场上有人买，不保证能按账面价卖掉。

English:

> HyperLeaf provides infrastructure, availability, and yield split. It does not guarantee a buyer, a book, or exit at NAV.

## Exit copy (use these, not L/C1/C2)

| GitHub | User-facing badge | How-to-exit (detail) |
| ------ | ----------------- | -------------------- |
| L | 烧掉就能拿回 | 烧掉 Leaf，马上拿回原来那份收据。想变现货，自己去官方解押。 |
| C1 | 只能卖掉 | 协议不赎回。想出去，在 HyperEVM 卖掉。低于账面价是有人接盘的价格，不是底仓没了。 |
| C2 | 烧掉后等几天 | 烧掉 Leaf，等窗口，再去源链领。金库不会因为排队而亏净值。 |
| hNEST | 按窗口取出 | 按 Nest 自己的窗口拿回 NEST，不是随时 1:1。 |
| blocked / parked | 暂不做 | Do not offer a deposit. Say why in one sentence from ROADMAP. |

Filters, nav, cards, toasts: the left column never appears. “同一套 L 适配器” is also forbidden.

## Redeem is a burn. There is no cancel.

Protocol exit **burns the Leaf first**. This is intentional (no half-state, no “undo queue” that still looks like a Leaf).

Do **not** ship Cancel / 撤销赎回 / “I changed my mind”. That button does not exist in the contracts.

| If they already… | What is true | UI |
| ---------------- | ------------ | -- |
| Burned an instant-receipt ticker | Leaf is gone. Receipt is in flight or already back on source. | Confirm copy before send: 烧掉之后不能撤回。 |
| Burned a queued ticker (C2 / hNEST `requestWithdraw`) | Leaf is gone **and** they do not have the inner yet. Ticket waits `eta`. | 排队中不能取消。到期去源链领取。期间既没有 Leaf，也还没有收据。 |
| Want Leaf again after they hold the receipt | That is a **new wrap**. New LZ fee. New mint. | Label it 再次存入 / wrap again. Never 取消赎回 or 恢复铸造. |
| Hold a sell-only ticker | There is no protocol redeem to cancel. | Only 卖掉. |

`abortCredit` is owner/guardian after halt — not a user cancel. Do not surface it.

**Copy that must sit on every redeem confirm:**

> 赎回会烧掉这份 Leaf，不能取消。想再拿 Leaf，要拿回收据之后重新存入。

English:

> Redeem burns this Leaf. It cannot be cancelled. To hold a Leaf again, wrap the receipt in a new deposit.

Add the same line to the queued-state screen, or users will think they can abort the wait.

## Claim HYPE is not on every ticker

Only show 领取 HYPE when `listings/catalog.json` `yield.toHype` is a real extra token (QUID, residual HYPE). Empty `toHype` means the staking reward is **inside the receipt rate**.

| Ticker | UI |
| ------ | -- |
| hxSQUID | 领取 WHYPE. Does not burn the Leaf. |
| hcbETH, hgSOON, hsWBERA, Morpho shares | **No claim button.** Copy: 质押收益在收据汇率里。赎回同一份即带走。没有 HYPE 可领。协议抽不到这笔。 |

Do not invent “偶发空投” for cbETH. Coinbase cbETH is ETH PoS in the rate, nothing else in the common case.

If you show a disabled claim, the reason must be that sentence — not “暂无收益 / coming soon”.

## Risk labels (required on the surface)

Show these where a holder can deposit or even just browse tickers. Do not bury them in GitHub.

| When | Label |
| ---- | ----- |
| Always | 合约未经外部审计。架构由人定，实现由 AI 写。 |
| Always | 不保证市场上有人买，不保证能按账面价卖掉。 |
| Always | 跨链你付 LayerZero。送达不是协议能保证的即时到账。 |
| Caps / pause live | 有上限，可暂停。 |
| Sell-only ticker | 可以长期低于账面价。那是流动性价格，除非底仓没了。 |
| Instant-receipt ticker | 赎回的是收据，不是现货。官方解押要你自己去点。 |
| Window ticker (hNEST, queued) | 取出跟官方窗口走，不是随时 1:1。烧掉即进入队列，不能取消。 |
| Redeem confirm (every listing that burns) | 赎回会烧掉这份 Leaf，不能取消。 |
| Airdrops / points | 记在金库地址上，要等收获。不是随时可领的 HYPE。 |
| Every listing | 底层协议可以改规则。HyperLeaf 不替它们偿付。 |

Do not say audited. Do not say auto-compound NAV while `recordCompound` is disabled (`PRODUCT_COPY_YIELD.md`).

## Words that are not synonyms (user language)

| 你看到的 | 意思 | 不是 |
| ------- | ---- | ---- |
| 有底仓 | 供给背后真有能拿回来的东西 | 今天就能按账面价退出 |
| 能赎回 | 烧掉之后有一条回家的路 | 盘口一定很深 |
| 有人买 | HyperEVM 上有人出价 | 协议保证 1:1 |
| 一张票 | 同一个 ticker 是同一种债权 | 每条资产退出方式都一样 |

`Backed` / `Redeemable` / `Liquid` / `Fungible` stay in README. Do not put those four English words on the product.

## Source of listing facts

Order and “never wrap”: `docs/ROADMAP.md`, `listings/catalog.json`.
Why a ticker may exist: `docs/SOLVENCY.md`.
Yield wording: `docs/PRODUCT_COPY_YIELD.md`, `docs/HYPE_YIELD.md`.

If GitHub and the UI disagree on an exit, GitHub wins and the UI is a bug.
