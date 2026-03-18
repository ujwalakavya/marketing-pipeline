{{ config(materialized="view", schema="STAGING") }}
-- ─────────────────────────────────────────────
-- stg_sales.sql
-- PURPOSE: Clean sales data and cast all types
-- WHY: Sales has the most complex typing:
--      booleans, floats, dates, and nullable APR
--      These need to be correct for profit calc
-- ─────────────────────────────────────────────

WITH source AS (
    SELECT * FROM {{ source('raw', 'raw_sales') }}
),
cleaned AS (
    SELECT
        CAST(USER_ID AS INT)                        AS user_id,
        CAST(LOCK_ID AS INT)                        AS lock_id,
        CAST(SALE_ID AS INT)                        AS sale_id,
        -- Parse sale datetime (format: YYYY/MM/DD HH:MM)
        TRY_CAST(SALE_DATETIME AS TIMESTAMP)        AS sale_datetime,
        MAKE                                        AS make,
        MODEL                                       AS model,
        -- Cast booleans from 0/1
        CAST(HAS_TRADE_IN AS BOOLEAN)               AS has_trade_in,
        CAST(IS_FINANCED AS BOOLEAN)                AS is_financed,
        -- APR is nullable — only financed sales have it
        -- TRY_CAST returns NULL instead of error if empty
        TRY_CAST(APR AS FLOAT)                      AS apr,
        CAST(DELIVERY_DISTANCE AS INT)              AS delivery_distance
    FROM source
    WHERE USER_ID IS NOT NULL
      AND SALE_ID IS NOT NULL
)

SELECT * FROM cleaned