{{ config(materialized="view", schema="STAGING") }}
-- ─────────────────────────────────────────────
-- stg_clicks.sql
-- PURPOSE: Clean click event data
-- WHY: This is your largest table (155K rows)
--      Proper typing enables fast joins and
--      accurate first-touch attribution logic
-- ─────────────────────────────────────────────

WITH source AS (
    SELECT * FROM {{ source('raw', 'raw_clicks') }}
),
cleaned AS (
    SELECT
        -- Cast to TIMESTAMP for date comparisons
        CAST(CLICK_DATETIME AS TIMESTAMP)   AS click_datetime,
        CAST(CHANNEL_ID AS INT)             AS channel_id,
        CAST(USER_ID AS INT)                AS user_id,
        -- Extract date for joining with spend data
        CAST(CLICK_DATETIME AS DATE)        AS click_date
    FROM source
    WHERE CLICK_DATETIME IS NOT NULL
      AND USER_ID IS NOT NULL
      AND CHANNEL_ID IS NOT NULL
)

SELECT * FROM cleaned