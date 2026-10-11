-- Solution: recursive CTE (standard SQL, no extra database objects).
-- For every tap, decide whether it is a paid fare or a free two-hour transfer.

WITH RECURSIVE tap_rank AS (
    -- Number each card's taps, oldest first.
    SELECT
        tap_id,
        media_token,
        tap_ts,
        row_number() OVER (PARTITION BY media_token ORDER BY tap_ts ASC, tap_id) AS tap_no
    FROM ttc_fare_tap
),
decision AS (
    -- Anchor member: the first tap of every card has no history, so it is a fare.
    SELECT
        tap_id,
        media_token,
        tap_ts,
        tap_no,
        'fare'::text AS the_decision,
        tap_ts       AS last_fare_ts
    FROM tap_rank
    WHERE tap_no = 1

    UNION ALL

    -- Recursive member: take the next tap of each card and compare it
    -- with the last time that card PAID (not with the previous tap).
    SELECT
        t.tap_id,
        t.media_token,
        t.tap_ts,
        t.tap_no,
        CASE WHEN t.tap_ts < d.last_fare_ts + INTERVAL '2 hours'
             THEN 'transfer' ELSE 'fare' END,
        CASE WHEN t.tap_ts < d.last_fare_ts + INTERVAL '2 hours'
             THEN d.last_fare_ts ELSE t.tap_ts END
    FROM decision d
    JOIN tap_rank t
      ON  t.media_token = d.media_token
      AND t.tap_no      = d.tap_no + 1
)
SELECT
    tap_id,
    media_token,
    tap_ts,
    tap_no,
    the_decision,
    last_fare_ts
FROM decision
ORDER BY media_token, tap_no;
