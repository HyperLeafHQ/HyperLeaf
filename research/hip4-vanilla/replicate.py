"""Static call replication from live HIP-4 binary ladders.

Read only. This module does not sign, deploy, or send orders.
A HIP-4 binary pays 1 quote token if the settlement price is above its
strike and 0 otherwise. A vanilla call max(S-K, 0) is not that payoff.

Inside the ladder the call is bounded by two strips of those binaries.
Above the highest strike the remaining linear tail is not priced.
"""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal


@dataclass(frozen=True)
class Quote:
    bid: Decimal | None
    ask: Decimal | None

    @property
    def mid(self) -> Decimal | None:
        if self.bid is None or self.ask is None:
            return None
        return (self.bid + self.ask) / 2


@dataclass(frozen=True)
class Binary:
    outcome_id: int
    perp: str
    expiry: str
    strike: Decimal
    quote_token: str
    twap_seconds: int | None

    @property
    def yes_coin(self) -> str:
        return f"#{self.outcome_id * 10}"


@dataclass(frozen=True)
class Strip:
    """One bucket. Superreplication buys the lower strike. Subreplication buys the upper."""

    low: Decimal
    high: Decimal
    width: Decimal
    lower_coin: str
    upper_coin: str
    lower: Quote
    upper: Quote


@dataclass(frozen=True)
class CallReplica:
    perp: str
    expiry: str
    quote_token: str
    strike: Decimal
    covered_to: Decimal
    strips: list[Strip]
    superrep_bid: Decimal | None
    superrep_ask: Decimal | None
    subrep_bid: Decimal | None
    subrep_ask: Decimal | None
    trapezoid_mid: Decimal | None
    missing_sides: int


def parse_binary(raw: dict) -> Binary | None:
    """template:binaryPrice only. One-strike class:priceBinary rows are not a ladder."""
    if raw.get("name") != "template:binaryPrice":
        return None
    fields: dict[str, str] = {}
    for part in (raw.get("description") or "").split("|"):
        if ":" not in part:
            continue
        key, value = part.split(":", 1)
        fields[key] = value
    if "perp" not in fields or "threshold" not in fields or "time" not in fields:
        return None
    seconds = fields.get("seconds")
    return Binary(
        outcome_id=int(raw["outcome"]),
        perp=fields["perp"],
        expiry=fields["time"],
        strike=Decimal(fields["threshold"]),
        quote_token=raw.get("quoteToken") or "",
        twap_seconds=int(seconds) if seconds else None,
    )


def ladders(outcomes: list[dict]) -> dict[tuple[str, str], list[Binary]]:
    groups: dict[tuple[str, str], list[Binary]] = {}
    for raw in outcomes:
        binary = parse_binary(raw)
        if binary is None:
            continue
        groups.setdefault((binary.perp, binary.expiry), []).append(binary)
    for rows in groups.values():
        rows.sort(key=lambda row: (row.strike, row.outcome_id))
    return groups


def _sum(parts: list[Decimal | None]) -> Decimal | None:
    if any(part is None for part in parts):
        return None
    total = Decimal(0)
    for part in parts:
        total += part  # type: ignore[operator]
    return total


def replicate_call(legs: list[Binary], quotes: dict[str, Quote], strike: Decimal) -> CallReplica:
    """Price a call at a strike that is already on the ladder.

    superrep buys `width` YES at each strike from K up to but not including the top.
    It pays the whole next bucket as soon as the price crosses the lower strike,
    so it is worth at least the call inside the grid and too much by up to one bucket.
    subrep buys YES at the upper end of each bucket. It pays the bucket only after
    the price clears it, so it is worth at most the call inside the grid.
    trapezoid_mid is the average of those two, and only when every side has both a bid and an ask.
    """
    if not legs:
        raise ValueError("empty ladder")
    perp = legs[0].perp
    expiry = legs[0].expiry
    quote_token = legs[0].quote_token
    ordered = sorted(legs, key=lambda row: (row.strike, row.outcome_id))
    if any(row.perp != perp or row.expiry != expiry for row in ordered):
        raise ValueError("legs are not one ladder")
    strikes = [row.strike for row in ordered]
    if strike not in strikes:
        raise ValueError("strike is not on this ladder")
    start = strikes.index(strike)
    strips: list[Strip] = []
    super_bids: list[Decimal | None] = []
    super_asks: list[Decimal | None] = []
    sub_bids: list[Decimal | None] = []
    sub_asks: list[Decimal | None] = []
    trap: list[Decimal | None] = []
    missing = 0
    for index in range(start, len(ordered) - 1):
        low = ordered[index]
        high = ordered[index + 1]
        width = high.strike - low.strike
        lower = quotes.get(low.yes_coin, Quote(None, None))
        upper = quotes.get(high.yes_coin, Quote(None, None))
        strips.append(Strip(low.strike, high.strike, width, low.yes_coin, high.yes_coin, lower, upper))
        if lower.bid is None or lower.ask is None or upper.bid is None or upper.ask is None:
            missing += 1
        super_bids.append(None if lower.bid is None else width * lower.bid)
        super_asks.append(None if lower.ask is None else width * lower.ask)
        sub_bids.append(None if upper.bid is None else width * upper.bid)
        sub_asks.append(None if upper.ask is None else width * upper.ask)
        if lower.mid is None or upper.mid is None:
            trap.append(None)
        else:
            trap.append(width * (lower.mid + upper.mid) / 2)
    return CallReplica(
        perp=perp,
        expiry=expiry,
        quote_token=quote_token,
        strike=strike,
        covered_to=ordered[-1].strike,
        strips=strips,
        superrep_bid=_sum(super_bids),
        superrep_ask=_sum(super_asks),
        subrep_bid=_sum(sub_bids),
        subrep_ask=_sum(sub_asks),
        trapezoid_mid=_sum(trap),
        missing_sides=missing,
    )
