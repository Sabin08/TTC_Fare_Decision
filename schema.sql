DROP TABLE IF EXISTS ttc_fare_tap;
 
CREATE TABLE ttc_fare_tap (
    tap_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    media_token  TEXT         NOT NULL,
    media_type   TEXT         NOT NULL
                 CHECK (media_type IN ('CREDIT', 'DEBIT', 'PRESTO_CARD', 'PRESTO_TICKET')),
    tap_ts       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    location     TEXT
);
 
CREATE INDEX idx_ttc_fare_tap_media_ts
    ON ttc_fare_tap (media_token, tap_ts);
