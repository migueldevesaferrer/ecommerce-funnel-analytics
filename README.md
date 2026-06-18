# Ecommerce Funnel Analytics

## 1. Introducción

Este proyecto desarrolla un análisis completo del customer journey en un e‑commerce utilizando SQL, PostgreSQL y Docker.  
Incluye:

- Exploratory Data Analysis (EDA)
- Validación de calidad de datos
- Construcción del funnel de conversión
- Creación de vistas semánticas
- Cálculo de KPIs reales
- Documentación técnica del proceso

El objetivo es construir un pipeline analítico sólido y reproducible que permita entender el comportamiento de los usuarios a lo largo del funnel.

---

## 2. Arquitectura del Proyecto

El proyecto sigue una arquitectura analítica estándar:

RAW → CORE → SEMANTIC → ANALYSIS

- RAW: Datos originales sin transformar  
- CORE: Limpieza, validación y estandarización  
- SEMANTIC: Vistas SQL para análisis  
- ANALYSIS: KPIs, métricas y conclusiones  

### 2.1 Estructura del proyecto

```plaintext
ECOMMERCE-FUNNEL-ANALYTICS/
│
├── data/                       # Datos RAW del proyecto (CSV original)
│   └── customer_journey.csv    # Dataset sintético de sesiones de usuario
│
├── init/                       # Scripts SQL que inicializan la base de datos
│   ├── 01_schema.sql           # Creación del esquema y tablas
│   ├── 02_data.sql             # Inserción de datos en las tablas
│   └── 03_eda.sql              # Exploratory Data Analysis (solo queries)
│
├── pgadmin/                    # Configuración opcional para pgAdmin
│   └── servers.json            # Conexión preconfigurada al servidor PostgreSQL
│
├── .gitignore                  # Archivos y carpetas excluidos del repositorio
├── .sqlfluff                   # Configuración del linter SQL (SQLFluff)
├── docker-compose.yml          # Orquestación de PostgreSQL + pgAdmin con Docker
└── README.md                   # Documentación principal del proyecto
```


---

## 3. Cómo ejecutar el proyecto

### 3.1 Requisitos previos

#### 3.1.1 Docker
El entorno se levanta completamente mediante Docker, por lo que es necesario tener instalado:

- Docker Desktop (Windows / macOS)
- Docker Engine + Docker Compose (Linux)

#### 3.1.2 PostgreSQL y pgAdmin (incluidos en Docker)
No es necesario instalarlos manualmente.  
El archivo `docker-compose.yml` crea:

- Un contenedor PostgreSQL
- Un contenedor pgAdmin para administración visual

#### 3.1.3 SQLFluff 4.x (opcional pero recomendado)
El proyecto utiliza SQLFluff para validar y formatear SQL.  
Es importante usar **SQLFluff versión 4.x**, ya que la versión 3.x usa un sistema de configuración distinto.

---

### 3.2 Levantar el entorno con Docker

En la raíz del proyecto:

```docker-compose up -d```


Esto levanta:

- PostgreSQL en localhost:5432  
- pgAdmin en localhost:5050  

---

### 3.3 Crear la base de datos

Entrar al contenedor:

```docker exec -it ecommerce-postgres psql -U postgres```


Crear la base de datos:

```CREATE DATABASE ecommerce_db;```


Salir con \q.

---

### 3.4 Ejecutar los scripts SQL

Ejecutar en este orden:

```bash
psql -U postgres -d ecommerce_db -f init/01_schema.sql
psql -U postgres -d ecommerce_db -f init/02_data.sql
psql -U postgres -d ecommerce_db -f init/eda.sql
```


---

### 3.5 Verificar que todo está correcto

```docker exec -it ecommerce-postgres psql -U postgres -d ecommerce_db```

Ejecutar:

```SELECT COUNT(*) FROM customer_journey;```


---

## 4. Exploratory Data Analysis (EDA)

El EDA incluye:

- Conteo de filas y sesiones  
- Distribución de PageType  
- Distribución de ItemsInCart  
- Validación de Purchased  
- Validación del funnel  
- Detección de inconsistencias  
- Análisis de sesiones incompletas  

### Hallazgos principales

- No existen nulos en columnas críticas  
- No existen duplicados exactos  
- Purchased es consistente  
- ItemsInCart es coherente hasta checkout  
- En confirmation, ItemsInCart siempre es 0 (limitación del dataset sintético)  

---

## 5. Vistas SQL (Capa Semántica)

Se crearon vistas para análisis:

- vw_funnel_sesiones  
- vw_funnel_aggregate  
- vw_funnel_device  
- vw_funnel_country  
- vw_funnel_referral  
- vw_funnel_tiempos  

Estas vistas permiten análisis rápidos y construcción de dashboards.

---

## 6. KPIs del Funnel

### 6.1 Conversion Rate Final

| Métrica | Valor |
|--------|--------|
| Sesiones totales | 5000 |
| Sesiones que llegan a confirmation | 1010 |
| Conversion Rate Final | 20.2% |

---

### 6.2 Drop-off por paso del funnel

| Paso | Sesiones | % respecto al anterior |
|------|----------|------------------------|
| home | 5000 | — |
| product_page | 3987 | 79.7% |
| cart | 1599 | 40.1% |
| checkout | 1123 | 70.2% |
| confirmation | 1010 | 89.9% |

---

### 6.3 Conversion Rate por DeviceType

| Device | Home | Confirmation | Conversion |
|--------|------|--------------|------------|
| desktop | 1666 | 339 | 20.35% |
| mobile | 1671 | 337 | 20.17% |
| tablet | 1663 | 334 | 20.08% |

---

### 6.4 Conversion Rate por Country

| País | Home | Confirmation | Conversion |
|------|------|--------------|------------|
| France | 752 | 170 | 22.60% |
| USA | 706 | 147 | 20.82% |
| India | 702 | 145 | 20.65% |
| UK | 739 | 145 | 19.62% |
| Canada | 715 | 140 | 19.58% |
| Australia | 683 | 131 | 19.18% |
| Germany | 703 | 132 | 18.77% |

---

### 6.5 Conversion Rate por ReferralSource

| Canal | Home | Confirmation | Conversion |
|--------|------|--------------|------------|
| google | 1280 | 277 | 21.64% |
| email | 1251 | 251 | 20.06% |
| direct | 1226 | 243 | 19.82% |
| social media | 1243 | 239 | 19.22% |

---

### 6.6 Bounce Rate

| Métrica | Valor |
|--------|--------|
| Sesiones solo home | 1013 |
| Bounce Rate | 20.3% |

---

### 6.7 Tiempos medios entre pasos

| Transición | Tiempo medio |
|------------|--------------|
| home → product_page | 97.06 s |
| product_page → cart | 98.74 s |
| cart → checkout | 96.61 s |

---

## 7. Conclusiones

- El dataset es consistente en casi todos los aspectos  
- La única anomalía es el reseteo del carrito en confirmation  
- El funnel es estable y permite análisis fiables  
- Las vistas semánticas facilitan la explotación del modelo  
- El proyecto es reproducible y adecuado para evaluación  

---

## 8. Próximos pasos

- Dashboard en Power BI  
- Análisis de cohortes  
- Segmentación de usuarios  
- Modelos predictivos de conversión  
