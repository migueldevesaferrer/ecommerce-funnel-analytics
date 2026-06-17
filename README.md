# 📘 Proyecto: Customer Journey & SQL Analytics

## 🧠 1. Introducción

Este proyecto forma parte del Máster de Data Science & AI y tiene como objetivo construir un pipeline analítico completo a partir de un dataset RAW de navegación web (*customer journey*).  

El dataset representa sesiones de usuarios en un e‑commerce, incluyendo:

- Navegación por páginas (home → product_page → cart → checkout → confirmation)  
- Items en el carrito  
- Tiempo en página  
- Dispositivo, país y fuente de tráfico  
- Indicador de compra (Purchased)

El proyecto incluye:

- Diseño del modelo de datos  
- Exploratory Data Analysis (EDA)  
- Validación de calidad de datos  
- Construcción del funnel de conversión  
- SQL avanzado  
- Creación de vistas semánticas  
- KPIs reales  
- Insights de negocio  
- Documentación profesional  

---

# 🏗️ 2. Arquitectura del Proyecto

El proyecto sigue una arquitectura analítica estándar:

RAW → CORE → SEMANTIC → ANALYSIS

### ✔ RAW  
Tabla original `customer_journey` sin transformar.

### ✔ CORE  
Limpieza, validación y estandarización (EDA + calidad de datos).

### ✔ SEMANTIC  
Vistas SQL del funnel, conversiones y métricas clave.

### ✔ ANALYSIS  
Consultas avanzadas, KPIs y conclusiones de negocio.

---

# 🧪 3. Exploratory Data Analysis (EDA)

El EDA se divide en bloques:

---

## 🟦 BLOQUE 1 — Exploración General

Incluye:

- Conteo de filas y sesiones  
- Distribución de PageType  
- Distribución de ItemsInCart  
- Distribución de Purchased  
- Tipos de datos  
- Valores nulos  
- Duplicados  

### **Hallazgos**

- No existen nulos en columnas críticas.  
- No existen duplicados exactos.  
- PageType, DeviceType, Country y ReferralSource contienen valores válidos.  
- ItemsInCart está dentro de rangos razonables.  
- Purchased es consistente.

---

## 🟦 BLOQUE 2 — Calidad de Datos

Incluye:

- Nulos  
- Duplicados  
- Valores fuera de rango  
- Categorías inválidas  
- Consistencia lógica  
- Validación del carrito  
- Validación del funnel  
- Validación de Purchased  

---

### 🟩 2.5 Consistencia del carrito (solo hasta checkout)

Se validó que `ItemsInCart` **nunca disminuye** en:

- home  
- product_page  
- cart  
- checkout  

**Resultado:**  
✔ 0 inconsistencias  
✔ El carrito es coherente hasta checkout.

---

### 🟥 2.6 Caso especial: confirmation

Este es el hallazgo más importante del EDA:

> **En todas las sesiones que llegan a confirmation, ItemsInCart = 0.**

Esto genera **1010 inconsistencias checkout → confirmation**, pero:

- No es un comportamiento real del usuario  
- Es una **limitación del dataset sintético**  
- El generador de datos **resetea el carrito a 0 en la última página**

---

### 🟩 2.7 Validación de Purchased

- Purchased = TRUE coincide exactamente con llegar a confirmation  
- No existen sesiones con Purchased = TRUE sin confirmation  
- No existen confirmation sin Purchased = TRUE  

✔ Purchased es totalmente consistente.

---

## 🟦 BLOQUE 3 — Validación RAW → DIM → FACT

Validaciones clave:

### ✔ Claves de negocio  
- Cada SessionID pertenece a un único UserID  
- No hay sesiones vacías  

### ✔ Integridad de dimensiones  
- DeviceType, Country y ReferralSource válidos  
- PageType sigue el catálogo esperado  

### ✔ Integridad del funnel  
- No existen confirmation sin checkout  
- No hay timestamps fuera de orden  

### ✔ Sesiones incompletas  
- Se detectan sesiones de rebote (solo home)  
- Comportamiento normal  

---

# 📊 4. Análisis del Funnel

Se construyó el funnel completo:

1. home  
2. product_page  
3. cart  
4. checkout  
5. confirmation  

### ✔ Conversion rate final  
`confirmation / home = 20.2%`

### ✔ Funnel por dimensiones  
- DeviceType  
- Country  
- ReferralSource  

### ✔ Tiempos entre pasos  
- home → product_page  
- product_page → cart  
- cart → checkout  

---

# 🧱 5. Vistas SQL (Capa SEMANTIC)

Se crearon vistas para análisis rápido:

- `vw_funnel_sesiones` → funnel por sesión  
- `vw_funnel_aggregate` → funnel total  
- `vw_funnel_device` → conversiones por dispositivo  
- `vw_funnel_country` → conversiones por país  
- `vw_funnel_referral` → conversiones por canal  
- `vw_funnel_tiempos` → tiempos entre pasos  

Estas vistas permiten construir dashboards en Power BI o Looker.

---

# 📊 6. KPIs del Funnel (Resultados Reales)

Esta sección resume los **indicadores clave de rendimiento (KPIs)** obtenidos a partir del análisis real del dataset.

---

## ⭐ 6.1 Conversion Rate Final

| Métrica | Valor |
|--------|--------|
| Sesiones totales | **5000** |
| Sesiones que llegan a confirmation | **1010** |
| Conversion Rate Final | **20.2%** |

---

## ⭐ 6.2 Drop-off por paso del funnel

| Paso | Sesiones | % respecto al paso anterior |
|------|----------|-----------------------------|
| home | 5000 | — |
| product_page | 3987 | **79.7%** |
| cart | 1599 | **40.1%** |
| checkout | 1123 | **70.2%** |
| confirmation | 1010 | **89.9%** |

---

## ⭐ 6.3 Conversion Rate por DeviceType

| Device | Sesiones Home | Confirmation | Conversion |
|--------|----------------|--------------|------------|
| desktop | 1666 | 339 | **20.35%** |
| mobile | 1671 | 337 | **20.17%** |
| tablet | 1663 | 334 | **20.08%** |

---

## ⭐ 6.4 Conversion Rate por Country

| País | Sesiones Home | Confirmation | Conversion |
|------|----------------|--------------|------------|
| France | 752 | 170 | **22.60%** |
| USA | 706 | 147 | **20.82%** |
| India | 702 | 145 | **20.65%** |
| UK | 739 | 145 | **19.62%** |
| Canada | 715 | 140 | **19.58%** |
| Australia | 683 | 131 | **19.18%** |
| Germany | 703 | 132 | **18.77%** |

---

## ⭐ 6.5 Conversion Rate por ReferralSource

| Canal | Sesiones Home | Confirmation | Conversion |
|--------|----------------|--------------|------------|
| google | 1280 | 277 | **21.64%** |
| email | 1251 | 251 | **20.06%** |
| direct | 1226 | 243 | **19.82%** |
| social media | 1243 | 239 | **19.22%** |

---

## ⭐ 6.6 Bounce Rate (sesiones solo home)

| Métrica | Valor |
|--------|--------|
| Sesiones solo home | **1013** |
| Bounce Rate | **20.3%** |

---

## ⭐ 6.7 Tiempos medios entre pasos

| Transición | Tiempo medio |
|------------|--------------|
| home → product_page | **97.06 s** |
| product_page → cart | **98.74 s** |
| cart → checkout | **96.61 s** |

---

# 🟩 7. Hallazgos Clave

- El funnel es coherente hasta checkout  
- Purchased es consistente  
- ItemsInCart se resetea a 0 en confirmation (limitación del dataset)  
- El mayor drop-off está en product_page → cart  
- Francia es el país con mejor conversión  
- Google es el canal con mejor conversión  
- Bounce Rate ≈ 20%  
- Tiempos entre pasos ≈ 100s  

---

# 🧭 8. Conclusiones

- El dataset es sólido y consistente en casi todos los aspectos.  
- La única anomalía detectada está documentada y explicada.  
- El funnel se puede analizar con total fiabilidad.  
- Purchased es una métrica fiable.  
- Las vistas semánticas permiten análisis avanzados.  
- El proyecto cumple todos los requisitos del máster.  

---

# 🚀 9. Próximos pasos

- Construcción de dashboard en Power BI  
- Análisis de cohortes  
- Segmentación de usuarios  
- Modelos predictivos de conversión  
