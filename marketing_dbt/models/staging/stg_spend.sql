{{ config(materialized="view", schema="STAGING") }}
-- ─────────────────────────────────────────────
-- stg_spend.sql
-- PURPOSE: Clean daily ad spend data
-- WHY: date and spend came in as VARCHAR
--      We need proper DATE and FLOAT types
--      for aggregations and ROI calculations
-- ─────────────────────────────────────────────

WITH source AS (
    SELECT * FROM {{ source('raw', 'raw_spend') }}
),
cleaned AS (
    SELECT
        CAST(CHANNEL_ID AS INT)         AS channel_id,
        -- Cast to DATE for time-based aggregations
        CAST(DATE AS DATE)              AS spend_date,
        -- Cast to FLOAT for math
        CAST(SPEND AS FLOAT)            AS spend
    FROM source
    WHERE SPEND IS NOT NULL
      AND CAST(SPEND AS FLOAT) > 0
)

SELECT * FROM cleaned