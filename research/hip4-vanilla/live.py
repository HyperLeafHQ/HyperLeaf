"""Print a call replica from the public Hyperliquid info API.

No key. No order. Books with one side missing stay one-sided.
"""

from __future__ import annotations

import json
import sys
import urllib.request
from decimal import Decimal
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import replicate

INFO = "https://api.hyperliquid.xyz/info"


def post(body: dict) -> dict:
    req = urllib.request.Request(
        INFO,
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=20) as response:
        return json.load(response)


def quote_from_book(book: dict) -> replicate.Quote:
    bids, asks = book.get("levels") or [[], []]
    bid = Decimal(bids[0]["px"]) if bids else None
    ask = Decimal(asks[0]["px"]) if asks else None
    if bid is not None and ask is not None and bid > ask:
        return replicate.Quote(None, None)
    return replicate.Quote(bid, ask)


def choose(groups: dict, perp: str) -> tuple[tuple[str, str], list[replicate.Binary]]:
    rows = [(key, legs) for key, legs in groups.items() if key[0] == perp and len(legs) >= 2]
    if not rows:
        raise SystemExit(f"no {perp} ladder with two strikes")
    rows.sort(key=lambda item: (-len(item[1]), item[0][1]))
    return rows[0]


def money(value: Decimal | None) -> str:
    if value is None:
        return "—"
    return f"{value:.4f}"


def main() -> None:
    perp = sys.argv[1] if len(sys.argv) > 1 else "BTC"
    meta = post({"type": "outcomeMeta"})
    groups = replicate.ladders(meta["outcomes"])
    key, legs = choose(groups, perp)
    quotes: dict[str, replicate.Quote] = {}
    for leg in legs:
        quotes[leg.yes_coin] = quote_from_book(post({"type": "l2Book", "coin": leg.yes_coin}))
    # Lowest strike uses the whole ladder. A middle strike shows a shorter cover.
    picks = [legs[0].strike]
    if len(legs) > 2:
        picks.append(legs[len(legs) // 2].strike)
    print(f"{key[0]} {key[1]} {legs[0].quote_token}  strikes {len(legs)}  covered only through {legs[-1].strike}")
    print("tail above the top strike is not priced. no perp hedge is included.")
    for strike in picks:
        call = replicate.replicate_call(legs, quotes, strike)
        print(
            f"K={call.strike}  super bid/ask {money(call.superrep_bid)} / {money(call.superrep_ask)}"
            f"  sub bid/ask {money(call.subrep_bid)} / {money(call.subrep_ask)}"
            f"  mid {money(call.trapezoid_mid)}  one-sided buckets {call.missing_sides}/{len(call.strips)}"
        )
        for strip in call.strips:
            print(
                f"  {strip.low}->{strip.high} w={strip.width} {strip.lower_coin}"
                f" {money(strip.lower.bid)}/{money(strip.lower.ask)}"
            )


if __name__ == "__main__":
    main()
