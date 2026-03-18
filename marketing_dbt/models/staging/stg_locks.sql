{{ config(materialized="view", schema="STAGING") }}
-- ─────────────────────────────────────────────
-- stg_locks.sql
-- PURPOSE: Clean lock event data
-- WHY: A lock = user started purchase process
--      We need typed IDs and timestamps to
--      join locks back to the first click
-- ─────────────────────────────────────────────

WITH source AS (
    SELECT * FROM {{ source('raw', 'raw_locks') }}
),
cleaned AS (
    SELECT
        CAST(LOCK_ID AS INT)                    AS lock_id,
        CAST(USER_ID AS INT)                    AS user_id,
        CAST(LOCK_DATETIME AS TIMESTAMP)        AS lock_datetime
    FROM source
    WHERE LOCK_ID IS NOT NULL
      AND USER_ID IS NOT NULL
)

SELECT * FROM cleaned