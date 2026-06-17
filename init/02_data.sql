/* ============================================================
   02_data.sql — Carga, limpieza y calidad de datos
   ============================================================ */

-- 1. CARGA RAW
TRUNCATE customer_journey;

\copy customer_journey FROM '/data/customer_journey.csv' DELIMITER ',' CSV HEADER;

-- 2. LIMPIEZA
UPDATE customer_journey
SET
    "ReferralSource" = LOWER(TRIM("ReferralSource")),
    "DeviceType" = LOWER(TRIM("DeviceType")),
    "Country" = INITCAP(TRIM("Country")),
    "PageType" = LOWER(TRIM("PageType"));

-- Purchased ya es boolean → solo normalizamos nulos
UPDATE customer_journey
SET "Purchased" = COALESCE("Purchased", FALSE);

-- 3. CALIDAD DE DATOS
SELECT * FROM customer_journey
WHERE "TimeOnPage_seconds" < 0;
SELECT * FROM customer_journey
WHERE "ItemsInCart" < 0;

-- 4. POBLAR DIMENSIONES
TRUNCATE fact_funnel, dim_user, dim_device, dim_country, dim_source, dim_page RESTART IDENTITY CASCADE;

INSERT INTO dim_user (user_code)
SELECT DISTINCT "UserID" FROM customer_journey;

INSERT INTO dim_device (device_type)
SELECT DISTINCT "DeviceType" FROM customer_journey;

INSERT INTO dim_country (country_name)
SELECT DISTINCT "Country" FROM customer_journey;

INSERT INTO dim_source (source_name)
SELECT DISTINCT "ReferralSource" FROM customer_journey;

INSERT INTO dim_page (page_type)
SELECT DISTINCT "PageType" FROM customer_journey;

-- 5. POBLAR FACT TABLE
WITH enriched AS (
    SELECT
        cj."SessionID" AS session_code,
        cj."Timestamp" AS event_timestamp,
        cj."TimeOnPage_seconds",
        cj."ItemsInCart",
        cj."Purchased",

        du.user_id,
        dd.device_id,
        dc.country_id,
        ds.source_id,
        dp.page_id
    FROM customer_journey AS cj
    INNER JOIN dim_user AS du ON cj."UserID" = du.user_code
    INNER JOIN dim_device AS dd ON cj."DeviceType" = dd.device_type
    INNER JOIN dim_country AS dc ON cj."Country" = dc.country_name
    INNER JOIN dim_source AS ds ON cj."ReferralSource" = ds.source_name
    INNER JOIN dim_page AS dp ON cj."PageType" = dp.page_type
)

INSERT INTO fact_funnel (
    session_code, event_timestamp, time_on_page_seconds,
    items_in_cart, purchased,
    user_id, device_id, country_id, source_id, page_id
)
SELECT * FROM enriched;

-- 6. VALIDACIONES
SELECT COUNT(*) AS total_raw FROM customer_journey;
SELECT COUNT(*) AS total_fact FROM fact_funnel;
