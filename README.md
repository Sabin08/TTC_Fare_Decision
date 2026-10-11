# TTC two-hour transfer: fare or free? Solved in SQL

A PostgreSQL project that takes a log of transit fare taps and works out, for every tap, whether the card should be **charged a fare** or given a **free two-hour transfer**.

The data is synthetic. This is a learning project, not the real TTC or PRESTO system.

## The problem

I rode the TTC in Toronto and paid by tapping my credit card. Four taps on one day went like this:

| Tap | Time | What happened |
|---|---|---|
| 1 | 10:00 | Charged about $3 |
| 2 | 10:30 | Free transfer |
| 3 | 11:30 | Free transfer |
| 4 | 13:00 | Charged about $3 again |

The fourth tap surprised me. It was only 90 minutes after the third tap, so I expected it to be free.

It was charged because the two-hour window does not slide. It starts at the last tap that was **paid** and free transfers do not extend it. Tap 4 was three hours after tap 1, so the window had closed.

**Goal:** given a table of taps with no stored outcome, write SQL that labels every tap as `fare` or `transfer`.

## The fare rule

Taken from the TTC's published policy (see Sources):

1. The first tap is charged and a transfer is applied to the card.
2. Any tap less than two hours after that paid tap is free.
3. A tap after the window has closed is charged again, and starts a new window.
4. Direction and route do not matter. Only the card and the time do.

Choices made for this project:

- A tap at exactly 2:00:00 after the paid tap is **charged** (the rule is "less than two hours").
- Each card or device is identified by an opaque `media_token`. The same credit card on plastic and in a phone wallet counts as two different tokens.
- The adult fare is $3.30. The amount is not stored, only the decision.

The correct comparison is against the **last paid tap**. But which tap was last paid is itself a result of the earlier decisions. Each row depends on the answer for the rows before it, and a plain window function cannot read its own earlier output.

## Data model

One table, one row per tap. It stores only what a fare reader knows at tap time.

| Column | Type | Purpose |
|---|---|---|
| `tap_id` | `BIGINT` identity | Primary key |
| `media_token` | `TEXT` | Which card or device tapped |
| `media_type` | `TEXT` | `CREDIT`, `DEBIT`, `PRESTO_CARD` or `PRESTO_TICKET` |
| `tap_ts` | `TIMESTAMPTZ` | When the tap happened |
| `location` | `TEXT` | Station or route (not used by the rule) |

The column names are loosely based on the fields in a rider's PRESTO transaction history. The real back-office schema is not public.

## How the solution works

**Solution, recursive CTE** (`03_solution_recursive_cte.sql`):

1. Number each card's taps from oldest to newest.
2. Start with tap 1 of every card. It is a fare, and its time is saved as `last_fare_ts`.
3. Join to the next tap on the same card (`tap_no + 1`).
4. If the tap is earlier than `last_fare_ts + 2 hours`, it is a transfer and `last_fare_ts` stays the same.
5. Otherwise it is a fare and `last_fare_ts` becomes this tap's time.
6. Repeat until no card has a next tap.

`last_fare_ts` is the memory carried from row to row. Without it the window would slide forward on every free tap.

## Files

| File | What it is |
|---|---|
| `01_schema.sql` | Creates the `ttc_fare_tap` table and its index |
| `02_seed.sql` | Loads 3,053 synthetic taps for 71 cards |
| `03_solution_recursive_cte.sql` | Solution 1 |
| `04_solution_custom_aggregate.sql` | Solution 2 |
| `ttc_fare_decision_flowchart.png` | The flowchart shown above |


PostgreSQL. Tested on version 16.


## Expected results

| Decision | Rows |
|---|---|
| Fare | 1,564 |
| Transfer | 1,489 |
| Total | 3,053 |

The seed data includes hand-made test cards. Expected decisions, in time order:

## Limitations

- **The data is synthetic.** Locations are random, so a card can appear at two distant stations minutes apart. Do not use it for route analysis.
- **No monthly fare cap.** Since 1 September 2026 the TTC stops charging after 47 paid trips in a calendar month. This project does not model that.
- **No card validity.** Every tap is treated as coming from a valid card.
- **TTC only.** Transfers involving GO Transit or other agencies follow different rules.
- **Not how a live system works.** A real fare system decides at the moment of the tap and stores the result. This project deliberately removes the stored result so the logic has to be rebuilt in SQL.
- **Batch, not real time.** The queries replay the whole table. Speed was not a goal.

## Sources

- [TTC: Two-hour transfer](https://ttc.ca/Fares-and-passes/PRESTO-on-the-TTC/Two-hour-transfer)
- [TTC: Fares and passes](https://www.ttc.ca/Fares-and-passes)
- [TTC: Monthly fare capping](https://ttc.ca/farecapping)
