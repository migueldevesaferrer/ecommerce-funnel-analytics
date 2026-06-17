/* ============================================================
   01_schema.sql
   Capa: SCHEMA (Modelo y estructura)
   Objetivo: Crear todas las tablas RAW, DIM y FACT del proyecto.
   Cumple requisitos del máster:
   - 1 tabla de hechos + 4+ dimensiones
   - PK, FK, UNIQUE, CHECK, NOT NULL
   - Comentarios explicando decisiones
   - Normalización en 3FN
   ============================================================ */

-- ============================================================
-- 1. ELIMINAR TABLAS SI EXISTEN (EJECUCIÓN DESDE CERO)
-- ============================================================
DROP TABLE IF EXISTS fact_funnel CASCADE;
DROP TABLE IF EXISTS dim_user CASCADE;
DROP TABLE IF EXISTS dim_device CASCADE;
DROP TABLE IF EXISTS dim_country CASCADE;
DROP TABLE IF EXISTS dim_source CASCADE;
DROP TABLE IF EXISTS dim_page CASCADE;
DROP TABLE IF EXISTS customer_journey CASCADE;

-- ============================================================
-- 2. TABLA RAW (STAGING)
--    Granularidad: 1 fila por evento de navegación
-- ============================================================
CREATE TABLE customer_journey (
    "SessionID" TEXT,
    "UserID" TEXT,
    "Timestamp" TIMESTAMP,
    "PageType" TEXT,
    "DeviceType" TEXT,
    "Country" TEXT,
    "ReferralSource" TEXT,
    "TimeOnPage_seconds" INT CHECK ("TimeOnPage_seconds" >= 0),
    "ItemsInCart" INT CHECK ("ItemsInCart" >= 0),
    "Purchased" BOOLEAN
);

COMMENT ON TABLE customer_journey IS 'Tabla RAW con los eventos del customer journey. No tiene PK porque es staging.';

-- ============================================================
-- 3. DIMENSIONES
-- ============================================================

-- DIM USER
CREATE TABLE dim_user (
    user_id SERIAL PRIMARY KEY,
    user_code TEXT UNIQUE NOT NULL
);
COMMENT ON TABLE dim_user IS 'Dimensión de usuarios. user_code proviene del CSV.';

-- DIM DEVICE
CREATE TABLE dim_device (
    device_id SERIAL PRIMARY KEY,
    device_type TEXT UNIQUE NOT NULL
);

-- DIM COUNTRY
CREATE TABLE dim_country (
    country_id SERIAL PRIMARY KEY,
    country_name TEXT UNIQUE NOT NULL
);

-- DIM SOURCE
CREATE TABLE dim_source (
    source_id SERIAL PRIMARY KEY,
    source_name TEXT UNIQUE NOT NULL
);

-- DIM PAGE
CREATE TABLE dim_page (
    page_id SERIAL PRIMARY KEY,
    page_type TEXT UNIQUE NOT NULL
);

-- ============================================================
-- 4. TABLA DE HECHOS
--    Granularidad: 1 evento de navegación enriquecido
-- ============================================================
CREATE TABLE fact_funnel (
    fact_id SERIAL PRIMARY KEY,
    session_code TEXT NOT NULL,
    event_timestamp TIMESTAMP NOT NULL,
    time_on_page_seconds INT CHECK (time_on_page_seconds >= 0),
    items_in_cart INT CHECK (items_in_cart >= 0),
    purchased BOOLEAN NOT NULL,

    -- Foreign Keys
    user_id INT REFERENCES dim_user (user_id),
    device_id INT REFERENCES dim_device (device_id),
    country_id INT REFERENCES dim_country (country_id),
    source_id INT REFERENCES dim_source (source_id),
    page_id INT REFERENCES dim_page (page_id)
);

COMMENT ON TABLE fact_funnel IS 'Tabla de hechos del funnel. Relaciona todas las dimensiones.';
