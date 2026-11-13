# Zillow Analytics Engineering & BI Portfolio Project

A production-grade, end-to-end Analytics Engineering pipeline and executive BI dashboard built on real estate data. This project demonstrates modern data stack (python, dbt, PBI) best practices, automated data quality quarantining, historical snapshot tracking, CI/CD automation, and clean DAX semantic modeling.

---

## System Architecture & Data Flow

The pipeline ingests raw JSON payloads from API, processes them through a dbt transformation framework with anomaly quarantine rules, automates local Parquet exports via post-hooks, and delivers an interactive custom-themed Power BI dashboard with optimized DAX measures.

```mermaid
graph TD
    classDef python fill:#3776AB,stroke:#fff,stroke-width:2px,color:#fff;
    classDef db fill:#F25022,stroke:#fff,stroke-width:2px,color:#fff;
    classDef dbt fill:#FF694B,stroke:#fff,stroke-width:2px,color:#fff;
    classDef pbi fill:#F2C811,stroke:#fff,stroke-width:2px,color:#111;

    subgraph Extraction ["Data Extraction Layer"]
        A[Zillow API / Scraper] -->|Raw JSON Payloads| B(python data_fetcher.py)
    end

    subgraph Storage ["Storage & DW Layer"]
        B -->|Ingest Raw Data| C[(DuckDB: zillow_dw.duckdb)]
    end

    subgraph Transformation ["Transformation Layer (dbt Core)"]
        C --> D[Staging Models: stg_zillow__listings]
        D --> E[Intermediate & Quarantine: int_listing_snapshots__validated / rejected]
        E --> F[Marts & Snapshots: fct_listing_snapshots & dim_properties]
    end

    subgraph CICD ["CI/CD & Delivery Layer"]
        G[GitHub Actions CI/CD] -->|Automated build & test| F
        F -->|dbt post-hook export| H[(Local Parquet Files: powerbi_exports/)]
    end

    subgraph Reporting ["Reporting Layer"]
        H -->|Direct Folder Connection| I[Power BI Desktop Report]
        I -->|Glass UI & DAX Measures| J[Executive Dashboards: Overview, Price Stalker, Property Finder]
    end

    class B python;
    class C,H db;
    class D,E,F dbt;
    class I,J pbi;

````  
## Data Stack Components
### Extraction: 
Python (data_fetcher.py) for automated API/payload ingestion and incremental local table updates.
### Data Warehouse:
DuckDB (zillow_dw.duckdb) for fast, local analytical processing.
### Transformation & Testing: 
dbt Core (staging, intermediate validation, marts, and schema testing).
### CI/CD Automation: 
GitHub Actions workflow executing automated build, test, and lint cycles.
### Data Delivery: 
Automated dbt post-hooks exporting core analytical tables into optimized local Parquet files (powerbi_exports/).
### BI & Semantic Layer: 
Power BI Desktop connected via local Parquet folder import, featuring a custom SVG layout, custom Zillow theme JSON and optimized measures
