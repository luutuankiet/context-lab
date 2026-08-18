# Documentation

Every page here is written for a maintainer six months from now who opened
exactly this file from a search result and has nothing else loaded.

This index is generated. Run `scripts/gen-docs-index.sh` after adding or
renaming a page; `--check` fails if it is stale.

<!-- BEGIN GENERATED INDEX -- edit the pages, not this block -->

## Where things live

One page per area of the system. Read before going looking for where
something is implemented.

| page | covers | verified |
|---|---|---|
| [Checkout](architecture/checkout.md) | where an order becomes a payment, and which file owns each step | 2020-01-01 |

## Traps

Failure modes that produce no error message, indexed by the symptom you
would observe. Read before debugging behaviour that is wrong but not
crashing.

| symptom | page | area | verified |
|---|---|---|---|
| my cart is empty after I refresh the page and I never removed anything | [CART_EMPTIES_ON_REFRESH](traps/CART_EMPTIES_ON_REFRESH.md) | checkout | 2020-01-01 |

## Reference

Simply true, and expensive to re-derive.

| page | summary | verified |
|---|---|---|
| [Currency codes](reference/currency-codes.md) | the six codes the payment provider accepts, and the two it silently drops | 2020-01-01 |

## Decisions

Why the repo is the way it is. A merged decision is immutable -- supersede
it with a new one rather than editing it.

- [One currency per order](adr/0001-one-currency-per-order.md)

<!-- END GENERATED INDEX -->
