/* ============================================================
   03_eda.sql — BLOQUE 1: Exploración básica del dataset RAW
   Objetivo:
   - Entender volumen, distribución y estructura del dataset.
   ============================================================ */

-- ============================================================
-- 1. Conteo general de registros RAW
-- ============================================================
SELECT COUNT(*) AS total_eventos_raw
FROM customer_journey;

-- ============================================================
-- 2. Rango de fechas del dataset
-- ============================================================
SELECT
    MIN("Timestamp") AS fecha_minima,
    MAX("Timestamp") AS fecha_maxima
FROM customer_journey;

-- ============================================================
-- 3. Distribución por tipo de página
-- ============================================================
SELECT
    LOWER("PageType") AS page_type,
    COUNT(*) AS total_eventos
FROM customer_journey
GROUP BY LOWER("PageType")
ORDER BY total_eventos DESC;

-- ============================================================
-- 4. Distribución por dispositivo
-- ============================================================
SELECT
    LOWER("DeviceType") AS device_type,
    COUNT(*) AS total_eventos
FROM customer_journey
GROUP BY LOWER("DeviceType")
ORDER BY total_eventos DESC;

-- ============================================================
-- 5. Distribución por país
-- ============================================================
SELECT
    INITCAP("Country") AS country,
    COUNT(*) AS total_eventos
FROM customer_journey
GROUP BY INITCAP("Country")
ORDER BY total_eventos DESC;

-- ============================================================
-- 6. Distribución por fuente de tráfico
-- ============================================================
SELECT
    LOWER("ReferralSource") AS referral_source,
    COUNT(*) AS total_eventos
FROM customer_journey
GROUP BY LOWER("ReferralSource")
ORDER BY total_eventos DESC;

-- ============================================================
-- 7. Distribución de sesiones y usuarios
-- ============================================================
SELECT COUNT(DISTINCT "SessionID") AS sesiones_unicas FROM customer_journey;
SELECT COUNT(DISTINCT "UserID") AS usuarios_unicos FROM customer_journey;

-- ============================================================
-- 8. Distribución de la variable objetivo (Purchased)
-- ============================================================
SELECT
    "Purchased",
    COUNT(*) AS total_eventos
FROM customer_journey
GROUP BY "Purchased"
ORDER BY "Purchased";

/* ============================================================
   03_eda.sql — BLOQUE 2: Calidad de Datos
   Objetivo:
   - Detectar nulos, duplicados, valores fuera de rango y anomalías.
   - Validar consistencia del funnel y del carrito.
   ============================================================ */

-- ============================================================
-- 1. NULOS EN COLUMNAS CRÍTICAS
-- ============================================================
SELECT COUNT(*) AS nulos_sessionid FROM customer_journey
WHERE "SessionID" IS NULL;
SELECT COUNT(*) AS nulos_userid FROM customer_journey
WHERE "UserID" IS NULL;
SELECT COUNT(*) AS nulos_timestamp FROM customer_journey
WHERE "Timestamp" IS NULL;
SELECT COUNT(*) AS nulos_pagetype FROM customer_journey
WHERE "PageType" IS NULL;
SELECT COUNT(*) AS nulos_devicetype FROM customer_journey
WHERE "DeviceType" IS NULL;
SELECT COUNT(*) AS nulos_country FROM customer_journey
WHERE "Country" IS NULL;
SELECT COUNT(*) AS nulos_referralsource FROM customer_journey
WHERE "ReferralSource" IS NULL;
SELECT COUNT(*) AS nulos_timeonpage FROM customer_journey
WHERE "TimeOnPage_seconds" IS NULL;
SELECT COUNT(*) AS nulos_itemsincart FROM customer_journey
WHERE "ItemsInCart" IS NULL;
SELECT COUNT(*) AS nulos_purchased FROM customer_journey
WHERE "Purchased" IS NULL;

-- ============================================================
-- 2. DUPLICADOS
-- ============================================================

-- 2.1 Duplicados exactos de fila
SELECT
    "SessionID",
    "UserID",
    "Timestamp",
    "PageType",
    "DeviceType",
    "Country",
    "ReferralSource",
    "TimeOnPage_seconds",
    "ItemsInCart",
    "Purchased",
    COUNT(*) AS veces
FROM customer_journey
GROUP BY
    "SessionID", "UserID", "Timestamp", "PageType", "DeviceType",
    "Country", "ReferralSource", "TimeOnPage_seconds", "ItemsInCart", "Purchased"
HAVING COUNT(*) > 1;

-- 2.2 Duplicados por SessionID + Timestamp
SELECT
    "SessionID",
    "Timestamp",
    COUNT(*) AS veces
FROM customer_journey
GROUP BY "SessionID", "Timestamp"
HAVING COUNT(*) > 1;

-- 2.3 Duplicados por UserID + Timestamp
SELECT
    "UserID",
    "Timestamp",
    COUNT(*) AS veces
FROM customer_journey
GROUP BY "UserID", "Timestamp"
HAVING COUNT(*) > 1;

-- ============================================================
-- 3. VALORES FUERA DE RANGO
-- ============================================================

SELECT * FROM customer_journey
WHERE "TimeOnPage_seconds" < 0;
SELECT * FROM customer_journey
WHERE "TimeOnPage_seconds" > 3600;
SELECT * FROM customer_journey
WHERE "ItemsInCart" < 0;
SELECT * FROM customer_journey
WHERE "ItemsInCart" > 100;

-- ============================================================
-- 4. FECHAS INCORRECTAS
-- ============================================================

SELECT * FROM customer_journey
WHERE "Timestamp" > NOW();
SELECT * FROM customer_journey
WHERE "Timestamp" < '2010-01-01';

-- ============================================================
-- 5. CATEGORÍAS INVÁLIDAS
-- ============================================================

SELECT DISTINCT "DeviceType"
FROM customer_journey
WHERE LOWER("DeviceType") NOT IN ('mobile', 'desktop', 'tablet');

SELECT DISTINCT "PageType"
FROM customer_journey
WHERE LOWER("PageType") NOT IN ('home', 'product_page', 'cart', 'checkout', 'confirmation');

SELECT DISTINCT "ReferralSource"
FROM customer_journey
WHERE LOWER("ReferralSource") NOT IN ('google', 'social media', 'direct', 'email');

SELECT DISTINCT "Country"
FROM customer_journey
WHERE LENGTH("Country") < 2 OR LENGTH("Country") > 50;

-- ============================================================
-- 6. CONSISTENCIA LÓGICA
-- ============================================================

-- 6.1 Purchased debe ser consistente por SessionID
SELECT
    "SessionID",
    COUNT(DISTINCT "Purchased") AS valores_distintos
FROM customer_journey
GROUP BY "SessionID"
HAVING COUNT(DISTINCT "Purchased") > 1;

-- 6.2 ItemsInCart no debería disminuir en la misma sesión (solo hasta checkout)
WITH carrito AS (
    SELECT
        "SessionID",
        "Timestamp",
        "PageType",
        "ItemsInCart",
        LAG("ItemsInCart") OVER (
            PARTITION BY "SessionID"
            ORDER BY "Timestamp"
        ) AS prev_items
    FROM customer_journey
    WHERE LOWER("PageType") IN ('home', 'product_page', 'cart', 'checkout')
)

SELECT *
FROM carrito
WHERE
    prev_items IS NOT NULL
    AND "ItemsInCart" < prev_items;

-- ============================================================
-- 6.3 Validación especial: confirmation SIEMPRE tiene ItemsInCart = 0
-- ============================================================

SELECT DISTINCT "ItemsInCart"
FROM customer_journey
WHERE LOWER("PageType") = 'confirmation';

-- ============================================================
-- 6.4 Inconsistencias checkout → confirmation (1010 sesiones)
-- ============================================================

WITH pasos AS (
    SELECT
        "SessionID",
        "ItemsInCart",
        LOWER("PageType") AS page_type
    FROM customer_journey
    WHERE LOWER("PageType") IN ('checkout', 'confirmation')
),

pivot AS (
    SELECT
        "SessionID",
        MAX(CASE WHEN page_type = 'checkout' THEN "ItemsInCart" END) AS items_checkout,
        MAX(CASE WHEN page_type = 'confirmation' THEN "ItemsInCart" END) AS items_confirmation
    FROM pasos
    GROUP BY "SessionID"
)

SELECT *
FROM pivot
WHERE
    items_checkout > 0
    AND items_confirmation = 0;

-- ============================================================
-- 6.5 Validación de Purchased = TRUE (coincide con llegar a confirmation)
-- ============================================================

WITH pasos AS (
    SELECT
        "SessionID",
        "ItemsInCart",
        "Purchased",
        LOWER("PageType") AS page_type
    FROM customer_journey
    WHERE LOWER("PageType") IN ('checkout', 'confirmation')
),

pivot AS (
    SELECT
        "SessionID",
        MAX(CASE WHEN page_type = 'checkout' THEN "ItemsInCart" END) AS items_checkout,
        MAX(CASE WHEN page_type = 'confirmation' THEN "ItemsInCart" END) AS items_confirmation,
        MAX(("Purchased")::int) AS purchased
    FROM pasos
    GROUP BY "SessionID"
)

SELECT *
FROM pivot
WHERE purchased = 1;

/* ============================================================
   BLOQUE 3 — VALIDACIÓN RAW → DIM → FACT
   Objetivo:
   - Validar que la tabla RAW es consistente para alimentar
     un modelo dimensional (DIM + FACT).
   - Detectar claves huérfanas, valores fuera de catálogo,
     sesiones incompletas y problemas de integridad lógica.
   ============================================================ */


-- ============================================================
-- 3.1 VALIDACIÓN DE CLAVES DE NEGOCIO
-- ============================================================

-- 3.1.1 SessionID no debe tener duplicados en el nivel FACT
-- (una sesión puede tener múltiples eventos, pero no debe haber
-- sesiones sin eventos o sesiones vacías)
SELECT
    "SessionID",
    COUNT(*) AS eventos
FROM customer_journey
GROUP BY "SessionID"
HAVING COUNT(*) = 0;


-- 3.1.2 UserID no debe ser inconsistente dentro de una sesión
SELECT
    "SessionID",
    COUNT(DISTINCT "UserID") AS usuarios_distintos
FROM customer_journey
GROUP BY "SessionID"
HAVING COUNT(DISTINCT "UserID") > 1;


-- ============================================================
-- 3.2 VALIDACIÓN DE DIMENSIONES (DIM-Device, DIM-Country, DIM-Referral)
-- ============================================================

-- 3.2.1 DeviceType válido
SELECT DISTINCT "DeviceType"
FROM customer_journey
WHERE LOWER("DeviceType") NOT IN ('mobile', 'desktop', 'tablet');

-- 3.2.2 Country válido (longitud razonable)
SELECT DISTINCT "Country"
FROM customer_journey
WHERE LENGTH("Country") < 2 OR LENGTH("Country") > 50;

-- 3.2.3 ReferralSource válido
SELECT DISTINCT "ReferralSource"
FROM customer_journey
WHERE LOWER("ReferralSource") NOT IN ('google', 'social media', 'direct', 'email');


-- ============================================================
-- 3.3 VALIDACIÓN DE LA DIM PageType (catálogo del funnel)
-- ============================================================

-- 3.3.1 PageTypes válidos
SELECT DISTINCT "PageType"
FROM customer_journey
WHERE LOWER("PageType") NOT IN ('home', 'product_page', 'cart', 'checkout', 'confirmation');


-- 3.3.2 Sesiones con PageTypes fuera del orden lógico del funnel
-- (ejemplo: confirmation sin checkout)
WITH pasos AS (
    SELECT
        "SessionID",
        MAX(CASE WHEN LOWER("PageType") = 'checkout' THEN 1 END) AS tiene_checkout,
        MAX(CASE WHEN LOWER("PageType") = 'confirmation' THEN 1 END) AS tiene_confirmation
    FROM customer_journey
    GROUP BY "SessionID"
)

SELECT *
FROM pasos
WHERE
    tiene_confirmation = 1
    AND tiene_checkout IS NULL;


-- ============================================================
-- 3.4 VALIDACIÓN DE INTEGRIDAD TEMPORAL
-- ============================================================

-- 3.4.1 Eventos fuera de orden dentro de una sesión
WITH orden AS (
    SELECT
        "SessionID",
        "Timestamp",
        LAG("Timestamp") OVER (PARTITION BY "SessionID" ORDER BY "Timestamp") AS prev_ts
    FROM customer_journey
)

SELECT *
FROM orden
WHERE
    prev_ts IS NOT NULL
    AND "Timestamp" < prev_ts;


-- ============================================================
-- 3.5 VALIDACIÓN DE LA FACT (Purchased)
-- ============================================================

-- 3.5.1 Purchased debe ser consistente por sesión
SELECT
    "SessionID",
    COUNT(DISTINCT "Purchased") AS valores_distintos
FROM customer_journey
GROUP BY "SessionID"
HAVING COUNT(DISTINCT "Purchased") > 1;


-- 3.5.2 Sesiones marcadas como Purchased pero sin llegar a confirmation
WITH pasos AS (
    SELECT
        "SessionID",
        MAX(CASE WHEN LOWER("PageType") = 'confirmation' THEN 1 END) AS tiene_confirmation,
        MAX(("Purchased")::int) AS purchased
    FROM customer_journey
    GROUP BY "SessionID"
)

SELECT *
FROM pasos
WHERE
    purchased = 1
    AND tiene_confirmation IS NULL;


-- ============================================================
-- 3.6 VALIDACIÓN DE SESIONES INCOMPLETAS
-- ============================================================

-- 3.6.1 Sesiones que solo tienen 1 evento
SELECT
    "SessionID",
    COUNT(*) AS eventos
FROM customer_journey
GROUP BY "SessionID", "PageType"
HAVING COUNT(*) = 1;

-- 3.6.2 Sesiones que nunca pasan de home
WITH pasos AS (
    SELECT
        "SessionID",
        COUNT(*) AS eventos,
        COUNT(CASE WHEN LOWER("PageType") <> 'home' THEN 1 END) AS pasos_no_home
    FROM customer_journey
    GROUP BY "SessionID"
)

SELECT *
FROM pasos
WHERE pasos_no_home = 0;


-- ============================================================
-- 3.7 VALIDACIÓN DE COHERENCIA PARA MODELO DIMENSIONAL
-- ============================================================

-- 3.7.1 Claves de negocio que podrían romper una DIM User
SELECT
    "UserID",
    COUNT(DISTINCT "Country") AS paises_distintos
FROM customer_journey
GROUP BY "UserID"
HAVING COUNT(DISTINCT "Country") > 1;

-- 3.7.2 Claves de negocio que podrían romper una DIM Device
SELECT
    "UserID",
    COUNT(DISTINCT "DeviceType") AS dispositivos_distintos
FROM customer_journey
GROUP BY "UserID"
HAVING COUNT(DISTINCT "DeviceType") > 3;

/* ============================================================
   BLOQUE 4 — ANÁLISIS DEL FUNNEL
   ============================================================ */

-- 4.1 Sesiones que pasan por cada paso del funnel
SELECT
    LOWER("PageType") AS page_type,
    COUNT(DISTINCT "SessionID") AS sesiones
FROM customer_journey
GROUP BY page_type
ORDER BY sesiones DESC;

-- 4.2 Drop-off entre pasos consecutivos
WITH pasos AS (
    SELECT
        "SessionID",
        MAX(CASE WHEN LOWER("PageType") = 'home' THEN 1 END) AS home,
        MAX(CASE WHEN LOWER("PageType") = 'product_page' THEN 1 END) AS product_page,
        MAX(CASE WHEN LOWER("PageType") = 'cart' THEN 1 END) AS cart,
        MAX(CASE WHEN LOWER("PageType") = 'checkout' THEN 1 END) AS checkout,
        MAX(CASE WHEN LOWER("PageType") = 'confirmation' THEN 1 END) AS confirmation
    FROM customer_journey
    GROUP BY "SessionID"
)

SELECT
    SUM(home) AS sesiones_home,
    SUM(product_page) AS sesiones_product_page,
    SUM(cart) AS sesiones_cart,
    SUM(checkout) AS sesiones_checkout,
    SUM(confirmation) AS sesiones_confirmation
FROM pasos;

-- 4.3 Conversion rate final (confirmation / home)
WITH pasos AS (
    SELECT
        "SessionID",
        MAX(CASE WHEN LOWER("PageType") = 'home' THEN 1 END) AS home,
        MAX(CASE WHEN LOWER("PageType") = 'confirmation' THEN 1 END) AS confirmation
    FROM customer_journey
    GROUP BY "SessionID"
)

SELECT SUM(confirmation)::float / SUM(home) AS conversion_rate
FROM pasos;

-- 4.4 Funnel por DeviceType
WITH pasos AS (
    SELECT
        "SessionID",
        "DeviceType",
        MAX(CASE WHEN LOWER("PageType") = 'home' THEN 1 END) AS home,
        MAX(CASE WHEN LOWER("PageType") = 'confirmation' THEN 1 END) AS confirmation
    FROM customer_journey
    GROUP BY "SessionID", "DeviceType"
)

SELECT
    "DeviceType",
    SUM(home) AS sesiones_home,
    SUM(confirmation) AS sesiones_confirmation,
    SUM(confirmation)::float / SUM(home) AS conversion_rate
FROM pasos
GROUP BY "DeviceType"
ORDER BY conversion_rate DESC;

-- 4.5 Tiempo entre pasos (home → product_page → cart → checkout)
WITH tiempos AS (
    SELECT
        "SessionID",
        MIN(CASE WHEN LOWER("PageType") = 'home' THEN "Timestamp" END) AS t_home,
        MIN(CASE WHEN LOWER("PageType") = 'product_page' THEN "Timestamp" END) AS t_product,
        MIN(CASE WHEN LOWER("PageType") = 'cart' THEN "Timestamp" END) AS t_cart,
        MIN(CASE WHEN LOWER("PageType") = 'checkout' THEN "Timestamp" END) AS t_checkout
    FROM customer_journey
    GROUP BY "SessionID"
)

SELECT
    AVG(EXTRACT(EPOCH FROM (t_product - t_home))) AS avg_home_to_product,
    AVG(EXTRACT(EPOCH FROM (t_cart - t_product))) AS avg_product_to_cart,
    AVG(EXTRACT(EPOCH FROM (t_checkout - t_cart))) AS avg_cart_to_checkout
FROM tiempos;

/* ============================================================
   BLOQUE 5 — ANÁLISIS POR DIMENSIONES
   ============================================================ */

-- 5.1 Conversion rate por país
WITH pasos AS (
    SELECT
        "SessionID",
        "Country",
        MAX(CASE WHEN LOWER("PageType") = 'home' THEN 1 END) AS home,
        MAX(CASE WHEN LOWER("PageType") = 'confirmation' THEN 1 END) AS confirmation
    FROM customer_journey
    GROUP BY "SessionID", "Country"
)

SELECT
    "Country",
    SUM(home) AS sesiones_home,
    SUM(confirmation) AS sesiones_confirmation,
    SUM(confirmation)::float / SUM(home) AS conversion_rate
FROM pasos
GROUP BY "Country"
ORDER BY conversion_rate DESC;

-- 5.2 Conversion rate por ReferralSource
WITH pasos AS (
    SELECT
        "SessionID",
        "ReferralSource",
        MAX(CASE WHEN LOWER("PageType") = 'home' THEN 1 END) AS home,
        MAX(CASE WHEN LOWER("PageType") = 'confirmation' THEN 1 END) AS confirmation
    FROM customer_journey
    GROUP BY "SessionID", "ReferralSource"
)

SELECT
    "ReferralSource",
    SUM(home) AS sesiones_home,
    SUM(confirmation) AS sesiones_confirmation,
    SUM(confirmation)::float / SUM(home) AS conversion_rate
FROM pasos
GROUP BY "ReferralSource"
ORDER BY conversion_rate DESC;

-- 5.3 Conversion rate por DeviceType
WITH pasos AS (
    SELECT
        "SessionID",
        "DeviceType",
        MAX(CASE WHEN LOWER("PageType") = 'home' THEN 1 END) AS home,
        MAX(CASE WHEN LOWER("PageType") = 'confirmation' THEN 1 END) AS confirmation
    FROM customer_journey
    GROUP BY "SessionID", "DeviceType"
)

SELECT
    "DeviceType",
    SUM(home) AS sesiones_home,
    SUM(confirmation) AS sesiones_confirmation,
    SUM(confirmation)::float / SUM(home) AS conversion_rate
FROM pasos
GROUP BY "DeviceType"
ORDER BY conversion_rate DESC;


---- VISTAS

CREATE OR REPLACE VIEW vw_funnel_sesiones AS
WITH pasos AS (
    SELECT
        "SessionID",
        MAX(CASE WHEN LOWER("PageType") = 'home' THEN 1 END) AS home,
        MAX(CASE WHEN LOWER("PageType") = 'product_page' THEN 1 END) AS product_page,
        MAX(CASE WHEN LOWER("PageType") = 'cart' THEN 1 END) AS cart,
        MAX(CASE WHEN LOWER("PageType") = 'checkout' THEN 1 END) AS checkout,
        MAX(CASE WHEN LOWER("PageType") = 'confirmation' THEN 1 END) AS confirmation,
        MAX(("Purchased")::int) AS purchased
    FROM customer_journey
    GROUP BY "SessionID"
)

SELECT *
FROM pasos;


CREATE OR REPLACE VIEW vw_funnel_aggregate AS
WITH pasos AS (
    SELECT
        "SessionID",
        MAX(CASE WHEN LOWER("PageType") = 'home' THEN 1 END) AS home,
        MAX(CASE WHEN LOWER("PageType") = 'product_page' THEN 1 END) AS product_page,
        MAX(CASE WHEN LOWER("PageType") = 'cart' THEN 1 END) AS cart,
        MAX(CASE WHEN LOWER("PageType") = 'checkout' THEN 1 END) AS checkout,
        MAX(CASE WHEN LOWER("PageType") = 'confirmation' THEN 1 END) AS confirmation
    FROM customer_journey
    GROUP BY "SessionID"
)

SELECT
    SUM(home) AS sesiones_home,
    SUM(product_page) AS sesiones_product_page,
    SUM(cart) AS sesiones_cart,
    SUM(checkout) AS sesiones_checkout,
    SUM(confirmation) AS sesiones_confirmation,
    SUM(confirmation)::float / SUM(home) AS conversion_rate_final
FROM pasos;


CREATE OR REPLACE VIEW vw_funnel_device AS
WITH pasos AS (
    SELECT
        "SessionID",
        "DeviceType",
        MAX(CASE WHEN LOWER("PageType") = 'home' THEN 1 END) AS home,
        MAX(CASE WHEN LOWER("PageType") = 'confirmation' THEN 1 END) AS confirmation
    FROM customer_journey
    GROUP BY "SessionID", "DeviceType"
)

SELECT
    "DeviceType",
    SUM(home) AS sesiones_home,
    SUM(confirmation) AS sesiones_confirmation,
    SUM(confirmation)::float / SUM(home) AS conversion_rate
FROM pasos
GROUP BY "DeviceType"
ORDER BY conversion_rate DESC;

CREATE OR REPLACE VIEW vw_funnel_country AS
WITH pasos AS (
    SELECT
        "SessionID",
        "Country",
        MAX(CASE WHEN LOWER("PageType") = 'home' THEN 1 END) AS home,
        MAX(CASE WHEN LOWER("PageType") = 'confirmation' THEN 1 END) AS confirmation
    FROM customer_journey
    GROUP BY "SessionID", "Country"
)

SELECT
    "Country",
    SUM(home) AS sesiones_home,
    SUM(confirmation) AS sesiones_confirmation,
    SUM(confirmation)::float / SUM(home) AS conversion_rate
FROM pasos
GROUP BY "Country"
ORDER BY conversion_rate DESC;


CREATE OR REPLACE VIEW vw_funnel_referral AS
WITH pasos AS (
    SELECT
        "SessionID",
        "ReferralSource",
        MAX(CASE WHEN LOWER("PageType") = 'home' THEN 1 END) AS home,
        MAX(CASE WHEN LOWER("PageType") = 'confirmation' THEN 1 END) AS confirmation
    FROM customer_journey
    GROUP BY "SessionID", "ReferralSource"
)

SELECT
    "ReferralSource",
    SUM(home) AS sesiones_home,
    SUM(confirmation) AS sesiones_confirmation,
    SUM(confirmation)::float / SUM(home) AS conversion_rate
FROM pasos
GROUP BY "ReferralSource"
ORDER BY conversion_rate DESC;


CREATE OR REPLACE VIEW vw_funnel_tiempos AS
WITH tiempos AS (
    SELECT
        "SessionID",
        MIN(CASE WHEN LOWER("PageType") = 'home' THEN "Timestamp" END) AS t_home,
        MIN(CASE WHEN LOWER("PageType") = 'product_page' THEN "Timestamp" END) AS t_product,
        MIN(CASE WHEN LOWER("PageType") = 'cart' THEN "Timestamp" END) AS t_cart,
        MIN(CASE WHEN LOWER("PageType") = 'checkout' THEN "Timestamp" END) AS t_checkout
    FROM customer_journey
    GROUP BY "SessionID"
)

SELECT
    "SessionID",
    EXTRACT(EPOCH FROM (t_product - t_home)) AS home_to_product_seconds,
    EXTRACT(EPOCH FROM (t_cart - t_product)) AS product_to_cart_seconds,
    EXTRACT(EPOCH FROM (t_checkout - t_cart)) AS cart_to_checkout_seconds
FROM tiempos;
