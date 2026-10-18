import sys
from decimal import Decimal
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import replicate


def q(bid: str, ask: str) -> replicate.Quote:
    return replicate.Quote(Decimal(bid), Decimal(ask))


def test_parse_and_group():
    raw = {
        "outcome": 11424,
        "name": "template:binaryPrice",
        "description": "perp:BTC|priceDescription:ignored|seconds:90|threshold:83774|time:20261019-0800",
        "quoteToken": "USDC",
    }
    binary = replicate.parse_binary(raw)
    assert binary is not None
    assert binary.yes_coin == "#114240"
    assert binary.strike == Decimal("83774")
    assert binary.twap_seconds == 90
    assert replicate.parse_binary({"name": "Recurring", "description": "class:priceBinary|underlying:BTC"}) is None
    groups = replicate.ladders(
        [
            raw,
            {
                "outcome": 11422,
                "name": "template:binaryPrice",
                "description": "perp:BTC|seconds:90|threshold:82615|time:20261019-0800",
                "quoteToken": "USDC",
            },
            {
                "outcome": 1,
                "name": "template:binaryPrice",
                "description": "perp:ETH|seconds:90|threshold:2400|time:20261019-0800",
                "quoteToken": "USDC",
            },
        ]
    )
    assert list(groups) == [("BTC", "20261019-0800"), ("ETH", "20261019-0800")]
    assert [row.strike for row in groups[("BTC", "20261019-0800")]] == [Decimal("82615"), Decimal("83774")]


def test_strip_bounds():
    low = replicate.Binary(1, "BTC", "20261019-0800", Decimal("100"), "USDC", 90)
    high = replicate.Binary(2, "BTC", "20261019-0800", Decimal("110"), "USDC", 90)
    quotes = {"#10": q("0.40", "0.42"), "#20": q("0.20", "0.22")}
    call = replicate.replicate_call([high, low], quotes, Decimal("100"))
    assert call.covered_to == Decimal("110")
    assert call.superrep_bid == Decimal("4.0")
    assert call.superrep_ask == Decimal("4.2")
    assert call.subrep_bid == Decimal("2.0")
    assert call.subrep_ask == Decimal("2.2")
    assert call.trapezoid_mid == Decimal("3.1")
    assert call.missing_sides == 0
    assert call.strips[0].lower_coin == "#10"


def test_missing_side_blocks_the_sum():
    low = replicate.Binary(1, "BTC", "t", Decimal("100"), "USDC", None)
    mid = replicate.Binary(2, "BTC", "t", Decimal("110"), "USDC", None)
    high = replicate.Binary(3, "BTC", "t", Decimal("120"), "USDC", None)
    quotes = {
        "#10": q("0.50", "0.52"),
        "#20": replicate.Quote(Decimal("0.20"), None),
        "#30": q("0.05", "0.07"),
    }
    call = replicate.replicate_call([low, mid, high], quotes, Decimal("100"))
    assert call.superrep_ask is None
    assert call.subrep_ask is None
    assert call.subrep_bid == Decimal("2.5")
    assert call.trapezoid_mid is None
    assert call.missing_sides == 2
    assert call.superrep_bid == Decimal("7.0")  # 10*0.50 + 10*0.20


def test_top_strike_has_no_cover():
    only = replicate.Binary(1, "BTC", "t", Decimal("100"), "USDC", None)
    call = replicate.replicate_call([only], {"#10": q("0.4", "0.5")}, Decimal("100"))
    assert call.strips == []
    assert call.superrep_bid == Decimal(0)
    assert call.trapezoid_mid == Decimal(0)
    assert call.covered_to == Decimal("100")


def test_strike_must_be_on_the_ladder():
    leg = replicate.Binary(1, "BTC", "t", Decimal("100"), "USDC", None)
    try:
        replicate.replicate_call([leg], {}, Decimal("90"))
    except ValueError as exc:
        assert "not on this ladder" in str(exc)
    else:
        raise AssertionError("expected ValueError")


if __name__ == "__main__":
    test_parse_and_group()
    test_strip_bounds()
    test_missing_side_blocks_the_sum()
    test_top_strike_has_no_cover()
    test_strike_must_be_on_the_ladder()
    print("ok")
