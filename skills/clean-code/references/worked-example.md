# Worked example: one policy, two callers

This original Python example illustrates the skill's judgment. It is not taken from the book. The supported input is an order dictionary whose items are a finite list of dictionaries containing integer `unit_price_cents` and `quantity` values.

## Before

```python
def quote_total_cents(order):
    n = 0
    for x in order["items"]:
        n += x["unit_price_cents"] * x["quantity"]
    if n < 10_000:
        n += 500
    return n


def apply_total_cents(order):
    n = 0
    for x in order["items"]:
        n += x["unit_price_cents"] * x["quantity"]
    if n < 10_000:
        n += 500
    order["total_cents"] = n
    return order
```

Two callers independently own the same shipping rule. Changing the threshold or fee requires coordinated edits; local names obscure what is being calculated. One caller is a query; the other intentionally mutates the supplied dictionary and returns that same object.

## After

```python
FREE_SHIPPING_THRESHOLD_CENTS = 10_000
STANDARD_SHIPPING_CENTS = 500


def _order_total_cents(items):
    subtotal_cents = sum(
        item["unit_price_cents"] * item["quantity"] for item in items
    )
    shipping_cents = (
        0 if subtotal_cents >= FREE_SHIPPING_THRESHOLD_CENTS
        else STANDARD_SHIPPING_CENTS
    )
    return subtotal_cents + shipping_cents


def quote_total_cents(order):
    return _order_total_cents(order["items"])


def apply_total_cents(order):
    order["total_cents"] = _order_total_cents(order["items"])
    return order
```

The shared helper owns an actual repeated business policy. The public functions keep their names and signatures, and retain their distinct query/mutation contracts. Constants name the policy and units. The helper computes the result before the mutating caller writes it, preserving the failure behaviour.

An empty order still costs 500 cents in this example, and a 10,000-cent subtotal still ships free. The refactor does not invent a new empty-order rule, validate quantities, change rounding, or rename serialized fields. Those would be separate product decisions.

## Verification

Compare both implementations on empty, one-item, multiple-item, below-threshold, exact-threshold, above-threshold, zero-quantity, and pre-existing-total cases. Assert expected integer totals, equal results, an unchanged quote input, identical mutation, preservation of unrelated data and the items object, and return identity for the mutating caller. On missing/malformed fields, compare failure types and confirm no partial order mutation.

These checks support this example's stated input contract; they do not establish equivalence for arbitrary numeric types, custom mappings, or concurrent mutation. An actual repository needs checks against its own callers and contracts.
