{{ config(materialized="view", schema="STAGING") }}
-- ─────────────────────────────────────────────
-- stg_ad_channels.sql
-- PURPOSE: Clean channel data and parse channel name
--          into category, partner, and campaign
-- WHY: Raw channel name is "Search Engine-Google_Sedan"
--      We need category="Search Engine", partner="Google",
--      campaign="Sedan" as separate columns for analysis
-- ─────────────────────────────────────────────

WITH source AS (
    -- Pull from RAW layer
    -- src function tells dbt exactly which table to read
    select * from {{ source('raw', 'raw_ad_channels') }}
),
parsed AS (
    SELECT
        
        CAST(CHANNEL_ID AS INT) AS channel_id, -- Cast to integer — channel_id came in as VARCHAR
        CHANNEL AS channel_name,-- Keep full channel name for reference

        -- CONCEPT: SPLIT_PART splits a string by a delimiter
        -- 'Search Engine-Google_Sedan' split by '-' part 1
        -- = 'Search Engine'
        SPLIT_PART(CHANNEL, '-', 1) AS channel_category,

        -- Everything after the '-' is 'partner_campaign'
        -- e.g. 'Google_Sedan' or 'AutoFi' (no campaign)
        SPLIT_PART(CHANNEL, '-', 2) AS partner_campaign,

        -- Partner = part before '_' in 'Google_Sedan'
        -- If no '_', the whole thing is the partner
        SPLIT_PART(SPLIT_PART(CHANNEL, '-', 2), '_', 1) AS channel_partner,

        -- Campaign = part after '_' in 'Google_Sedan'
        -- If no '_', campaign = same as partner (no sub-campaign)
        CASE
            WHEN SPLIT_PART(SPLIT_PART(CHANNEL, '-', 2), '_', 2) = ''
            THEN SPLIT_PART(SPLIT_PART(CHANNEL, '-', 2), '_', 1)
            ELSE SPLIT_PART(SPLIT_PART(CHANNEL, '-', 2), '_', 2)
        END AS channel_campaign

    FROM source
)

SELECT * FROM parsed