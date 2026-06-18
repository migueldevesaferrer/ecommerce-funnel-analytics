/* ============================================================
   04_dimensional_analysis.sql
   Capa: MODEL / FACT + DIM
   Objetivo: Analizar el funnel usando la tabla de hechos y las dimensiones.
   ============================================================ */

-- 1. Sesiones por paso del funnel
WITH funnel AS (
    SELECT
        f.fact_id,
        f.session_code,
        f.event_timestamp,
        f.time_on_page_seconds,
        f.items_in_cart,
        f.purchased,
        du.user_code AS user_id,
        dd.device_type,
        dc.country_name AS country,
        ds.source_name AS referral_source,
        dp.page_type
    FROM fact_funnel AS f
    LEFT JOIN dim_user AS du ON f.user_id = du.user_id
    LEFT JOIN dim_device AS dd ON f.device_id = dd.device_id
    LEFT JOIN dim_country AS dc ON f.country_id = dc.country_id
    LEFT JOIN dim_source AS ds ON f.source_id = ds.source_id
    LEFT JOIN dim_page AS dp ON f.page_id = dp.page_id
)

SELECT
    page_type,
    COUNT(DISTINCT session_code) AS sesiones
FROM funnel
GROUP BY page_type
ORDER BY sesiones DESC;

---------------------------------------------------------------
-- 2. Drop-off entre pasos consecutivos
---------------------------------------------------------------
WITH funnel AS (
    SELECT
        f.session_code,
        dp.page_type
    FROM fact_funnel f
    LEFT JOIN dim_page dp ON f.page_id = dp.page_id
),
session_steps AS (
    SELECT
        session_code,
        MAX(CASE WHEN page_type = 'home' THEN 1 END) AS home,
        MAX(CASE WHEN page_type = 'product_page' THEN 1 END) AS product_page,
        MAX(CASE WHEN page_type = 'cart' THEN 1 END) AS cart,
        MAX(CASE WHEN page_type = 'checkout' THEN 1 END) AS checkout,
        MAX(CASE WHEN page_type = 'confirmation' THEN 1 END) AS confirmation
    FROM funnel
    GROUP BY session_code
)
SELECT
    SUM(home) AS sesiones_home,
    SUM(product_page) AS sesiones_product_page,
    SUM(cart) AS sesiones_cart,
    SUM(checkout) AS sesiones_checkout,
    SUM(confirmation) AS sesiones_confirmation
FROM session_steps;


---------------------------------------------------------------
-- 3. Conversion rate global
---------------------------------------------------------------
WITH funnel AS (
    SELECT
        f.session_code,
        dp.page_type
    FROM fact_funnel f
    LEFT JOIN dim_page dp ON f.page_id = dp.page_id
),
session_steps AS (
    SELECT
        session_code,
        MAX(CASE WHEN page_type = 'home' THEN 1 END) AS home,
        MAX(CASE WHEN page_type = 'confirmation' THEN 1 END) AS confirmation
    FROM funnel
    GROUP BY session_code
)
SELECT
    SUM(confirmation)::float / NULLIF(SUM(home), 0) AS conversion_rate
FROM session_steps;


---------------------------------------------------------------
-- 4. Conversion rate por dispositivo
---------------------------------------------------------------
WITH funnel AS (
    SELECT
        f.session_code,
        dp.page_type,
        dd.device_type
    FROM fact_funnel f
    LEFT JOIN dim_page dp ON f.page_id = dp.page_id
    LEFT JOIN dim_device dd ON f.device_id = dd.device_id
),
session_steps AS (
    SELECT
        session_code,
        device_type,
        MAX(CASE WHEN page_type = 'home' THEN 1 END) AS home,
        MAX(CASE WHEN page_type = 'confirmation' THEN 1 END) AS confirmation
    FROM funnel
    GROUP BY session_code, device_type
)
SELECT
    device_type,
    SUM(home) AS sesiones_home,
    SUM(confirmation) AS sesiones_confirmation,
    SUM(confirmation)::float / NULLIF(SUM(home), 0) AS conversion_rate
	-- ::float fuerza división decimal → correcto.
	-- NULLIF(SUM(home), 0) devuelve NULL si SUM(home) es 0 (evita error).
FROM session_steps
GROUP BY device_type
ORDER BY conversion_rate DESC;


---------------------------------------------------------------
-- 5. Conversion rate por país
---------------------------------------------------------------
WITH funnel AS (
    SELECT
        f.session_code,
        dp.page_type,
        dc.country_name AS country
    FROM fact_funnel f
    LEFT JOIN dim_page dp ON f.page_id = dp.page_id
    LEFT JOIN dim_country dc ON f.country_id = dc.country_id
),
session_steps AS (
    SELECT
        session_code,
        country,
        MAX(CASE WHEN page_type = 'home' THEN 1 END) AS home,
        MAX(CASE WHEN page_type = 'confirmation' THEN 1 END) AS confirmation
    FROM funnel
    GROUP BY session_code, country
)
SELECT
    country,
    SUM(home) AS sesiones_home,
    SUM(confirmation) AS sesiones_confirmation,
    SUM(confirmation)::float / NULLIF(SUM(home), 0) AS conversion_rate
FROM session_steps
GROUP BY country
ORDER BY conversion_rate DESC;


---------------------------------------------------------------
-- 6. Conversion rate por fuente
---------------------------------------------------------------
WITH funnel AS (
    SELECT
        f.session_code,
        dp.page_type,
        ds.source_name AS referral_source
    FROM fact_funnel f
    LEFT JOIN dim_page dp ON f.page_id = dp.page_id
    LEFT JOIN dim_source ds ON f.source_id = ds.source_id
),
session_steps AS (
    SELECT
        session_code,
        referral_source,
        MAX(CASE WHEN page_type = 'home' THEN 1 END) AS home,
        MAX(CASE WHEN page_type = 'confirmation' THEN 1 END) AS confirmation
    FROM funnel
    GROUP BY session_code, referral_source
)
SELECT
    referral_source,
    SUM(home) AS sesiones_home,
    SUM(confirmation) AS sesiones_confirmation,
    SUM(confirmation)::float / NULLIF(SUM(home), 0) AS conversion_rate
FROM session_steps
GROUP BY referral_source
ORDER BY conversion_rate DESC;


---------------------------------------------------------------
-- 7. Tiempo medio entre pasos del funnel
---------------------------------------------------------------
WITH funnel AS (
    SELECT
        f.session_code,
        f.event_timestamp,
        dp.page_type
    FROM fact_funnel f
    LEFT JOIN dim_page dp ON f.page_id = dp.page_id
),
page_times AS (
    SELECT
        session_code,
        MIN(CASE WHEN page_type = 'home' THEN event_timestamp END) AS t_home,
        MIN(CASE WHEN page_type = 'product_page' THEN event_timestamp END) AS t_product,
        MIN(CASE WHEN page_type = 'cart' THEN event_timestamp END) AS t_cart,
        MIN(CASE WHEN page_type = 'checkout' THEN event_timestamp END) AS t_checkout
    FROM funnel
    GROUP BY session_code
)
SELECT
    AVG(EXTRACT(EPOCH FROM (t_product - t_home))) AS avg_home_to_product,
    AVG(EXTRACT(EPOCH FROM (t_cart - t_product))) AS avg_product_to_cart,
    AVG(EXTRACT(EPOCH FROM (t_checkout - t_cart))) AS avg_cart_to_checkout
	-- EXTRACT(EPOCH FROM ) convierte un intervalo en segundos.
	-- AVG(...) calcula el tiempo medio en segundos entre cart a checkout.
FROM page_times;


---------------------------------------------------------------
-- 8. VISTAS FINALES
---------------------------------------------------------------

CREATE OR REPLACE VIEW vw_dimensional_funnel AS
SELECT
    f.fact_id,
    f.session_code,
    f.event_timestamp,
    f.time_on_page_seconds,
    f.items_in_cart,
    f.purchased,
    du.user_code AS user_id,
    dd.device_type,
    dc.country_name AS country,
    ds.source_name AS referral_source,
    dp.page_type
FROM fact_funnel f
LEFT JOIN dim_user du ON f.user_id = du.user_id
LEFT JOIN dim_device dd ON f.device_id = dd.device_id
LEFT JOIN dim_country dc ON f.country_id = dc.country_id
LEFT JOIN dim_source ds ON f.source_id = ds.source_id
LEFT JOIN dim_page dp ON f.page_id = dp.page_id;


CREATE OR REPLACE VIEW vw_dimensional_funnel_sessions AS
WITH session_steps AS (
    SELECT
        session_code,
        MAX(CASE WHEN page_type = 'home' THEN 1 END) AS home,
        MAX(CASE WHEN page_type = 'product_page' THEN 1 END) AS product_page,
        MAX(CASE WHEN page_type = 'cart' THEN 1 END) AS cart,
        MAX(CASE WHEN page_type = 'checkout' THEN 1 END) AS checkout,
        MAX(CASE WHEN page_type = 'confirmation' THEN 1 END) AS confirmation,
        MAX((purchased)::int) AS purchased
    FROM vw_dimensional_funnel
    GROUP BY session_code
)
SELECT *
FROM session_steps;


CREATE OR REPLACE VIEW vw_dimensional_conversion_by_device AS
SELECT
    device_type,
    SUM(CASE WHEN page_type = 'home' THEN 1 ELSE 0 END) AS sesiones_home,
    SUM(CASE WHEN page_type = 'confirmation' THEN 1 ELSE 0 END) AS sesiones_confirmation,
    SUM(CASE WHEN page_type = 'confirmation' THEN 1 ELSE 0 END)::float
        / NULLIF(SUM(CASE WHEN page_type = 'home' THEN 1 ELSE 0 END), 0)
        AS conversion_rate
FROM vw_dimensional_funnel
GROUP BY device_type
ORDER BY conversion_rate DESC;


CREATE OR REPLACE VIEW vw_dimensional_conversion_by_country AS
SELECT
    country,
    SUM(CASE WHEN page_type = 'home' THEN 1 ELSE 0 END) AS sesiones_home,
    SUM(CASE WHEN page_type = 'confirmation' THEN 1 ELSE 0 END) AS sesiones_confirmation,
    SUM(CASE WHEN page_type = 'confirmation' THEN 1 ELSE 0 END)::float
        / NULLIF(SUM(CASE WHEN page_type = 'home' THEN 1 ELSE 0 END), 0)
        AS conversion_rate
FROM vw_dimensional_funnel
GROUP BY country
ORDER BY conversion_rate DESC;


CREATE OR REPLACE VIEW vw_dimensional_conversion_by_source AS
SELECT
    referral_source,
    SUM(CASE WHEN page_type = 'home' THEN 1 ELSE 0 END) AS sesiones_home,
    SUM(CASE WHEN page_type = 'confirmation' THEN 1 ELSE 0 END) AS sesiones_confirmation,
    SUM(CASE WHEN page_type = 'confirmation' THEN 1 ELSE 0 END)::float
        / NULLIF(SUM(CASE WHEN page_type = 'home' THEN 1 ELSE 0 END), 0)
        AS conversion_rate
FROM vw_dimensional_funnel
GROUP BY referral_source
ORDER BY conversion_rate DESC;
