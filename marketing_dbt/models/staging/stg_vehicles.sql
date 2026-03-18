{{ config(materialized="view", schema="STAGING") }}
-- ─────────────────────────────────────────────
-- stg_vehicles.sql
-- PURPOSE: Clean vehicle data, cast avg_margin to float
-- WHY: avg_margin came in as VARCHAR from RAW
--      We need it as a number for profit calculations
-- ─────────────────────────────────────────────

WITH source AS (
    SELECT * FROM {{ source('raw', 'raw_vehicles') }}

),
cleaned AS (
    SELECT
        MAKE                            AS make,
        MODEL                           AS model,
        BODYSTYLE                       AS bodystyle,
        -- Cast margin to float for math operations
        CAST(AVG_MARGIN AS FLOAT)       AS avg_margin
    FROM source
    -- Remove any records missing key fields
    WHERE MAKE IS NOT NULL
      AND MODEL IS NOT NULL
)

SELECT * FROM cleaned