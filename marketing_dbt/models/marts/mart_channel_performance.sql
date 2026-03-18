{{ config(materialized="table", schema="MARTS") }}
WITH clicks AS (
    SELECT * FROM {{ ref('stg_clicks') }}
),
locks AS (
    SELECT * FROM {{ ref('stg_locks') }}
),
sales AS (
    SELECT * FROM {{ ref('stg_sales') }}
),
channels AS (
    SELECT * FROM {{ ref('stg_ad_channels') }}
),
spend AS (
    SELECT * FROM {{ ref('stg_spend') }}
),
vehicles AS (
    SELECT * FROM {{ ref('stg_vehicles') }}
),
first_touch AS (
    SELECT
        user_id,
        MIN(click_datetime) AS first_click_datetime,
        MIN_BY(channel_id, click_datetime) AS first_channel_id
    FROM clicks
    GROUP BY user_id
),
sales_with_channel AS (
    SELECT
        s.sale_id,
        s.user_id,
        s.lock_id,
        s.sale_datetime,
        s.make,
        s.model,
        s.has_trade_in,
        s.is_financed,
        s.apr,
        s.delivery_distance,
        ft.first_channel_id AS attributed_channel_id
    FROM sales s
    LEFT JOIN first_touch ft ON s.user_id = ft.user_id
),
monthly_apr AS (
    SELECT
        DATE_TRUNC('month', sale_datetime) AS sale_month,
        AVG(apr) AS avg_monthly_apr
    FROM sales_with_channel
    WHERE is_financed = TRUE AND apr IS NOT NULL
    GROUP BY 1
),
sales_with_profit AS (
    SELECT
        swc.*,
        v.bodystyle,
        v.avg_margin,
        COALESCE(m.avg_monthly_apr, 0) AS monthly_avg_apr,
        CASE
            WHEN swc.is_financed = FALSE OR swc.apr IS NULL THEN -0.1
            ELSE (swc.apr - m.avg_monthly_apr) / NULLIF(m.avg_monthly_apr, 0)
        END AS apr_modifier,
        v.avg_margin * (1 + CASE
            WHEN swc.is_financed = FALSE OR swc.apr IS NULL THEN -0.1
            ELSE (swc.apr - m.avg_monthly_apr) / NULLIF(m.avg_monthly_apr, 0)
        END) AS modified_value
    FROM sales_with_channel swc
    LEFT JOIN vehicles v ON swc.make = v.make AND swc.model = v.model
    LEFT JOIN monthly_apr m ON DATE_TRUNC('month', swc.sale_datetime) = m.sale_month
),
profit_calc AS (
    SELECT
        *,
        CASE
            WHEN bodystyle IN ('Sedan', 'Hatchback') THEN
                modified_value + 200 - (delivery_distance / 2.0)
                + CASE WHEN has_trade_in THEN 400 ELSE 0 END
            WHEN bodystyle IN ('Coupe', 'SUV') THEN
                modified_value - (0.8 * delivery_distance)
                + CASE WHEN has_trade_in THEN 300 ELSE 0 END
            WHEN bodystyle = 'Truck' THEN
                modified_value - 200 - delivery_distance
                + CASE WHEN has_trade_in THEN 200 ELSE 0 END
            ELSE modified_value
        END AS sale_profit
    FROM sales_with_profit
),
channel_sales AS (
    SELECT
        attributed_channel_id AS channel_id,
        COUNT(*) AS total_sales,
        SUM(sale_profit) AS total_profit
    FROM profit_calc
    GROUP BY attributed_channel_id
),
channel_clicks AS (
    SELECT channel_id, COUNT(*) AS total_clicks
    FROM clicks
    GROUP BY channel_id
),
channel_locks AS (
    SELECT
        ft.first_channel_id AS channel_id,
        COUNT(*) AS total_locks
    FROM locks l
    LEFT JOIN first_touch ft ON l.user_id = ft.user_id
    GROUP BY ft.first_channel_id
),
channel_spend AS (
    SELECT channel_id, SUM(spend) AS total_spend
    FROM spend
    GROUP BY channel_id
),
final AS (
    SELECT
        ch.channel_id,
        ch.channel_name,
        ch.channel_category,
        ch.channel_partner,
        ch.channel_campaign,
        COALESCE(csp.total_spend, 0)  AS total_spend,
        COALESCE(ccl.total_clicks, 0) AS total_clicks,
        COALESCE(clk.total_locks, 0)  AS total_locks,
        COALESCE(csa.total_sales, 0)  AS total_sales,
        COALESCE(csa.total_profit, 0) AS total_profit,
        CASE WHEN COALESCE(ccl.total_clicks, 0) > 0
            THEN ROUND(csp.total_spend / ccl.total_clicks, 2)
            ELSE NULL END AS cpc,
        CASE WHEN COALESCE(csa.total_sales, 0) > 0
            THEN ROUND(csp.total_spend / csa.total_sales, 2)
            ELSE NULL END AS cac,
        CASE WHEN COALESCE(csp.total_spend, 0) > 0
            THEN ROUND(csa.total_profit / csp.total_spend, 2)
            ELSE NULL END AS roi,
        CASE WHEN COALESCE(ccl.total_clicks, 0) > 0
            THEN ROUND(100.0 * csa.total_sales / ccl.total_clicks, 2)
            ELSE NULL END AS click_to_sale_pct
    FROM channels ch
    LEFT JOIN channel_spend  csp ON ch.channel_id = csp.channel_id
    LEFT JOIN channel_clicks ccl ON ch.channel_id = ccl.channel_id
    LEFT JOIN channel_locks  clk ON ch.channel_id = clk.channel_id
    LEFT JOIN channel_sales  csa ON ch.channel_id = csa.channel_id
)
SELECT * FROM final
ORDER BY total_sales DESC
