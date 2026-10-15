# GCP GKE ETL Platform Demo

A cloud-native data engineering and platform infrastructure demo built on **Google Kubernetes Engine (GKE)**, **Google Cloud Storage (GCS)**, **BigQuery**, **Terraform**, and **Argo CD**.

> **Project status: Work in progress.** This repository contains infrastructure-as-code, application components, a BigQuery-based ETL implementation, and initial GitOps configurations. It is a learning and portfolio project, not a production-ready platform. Some Kubernetes add-ons and deployment workflows remain incomplete or require end-to-end validation.

## Overview

This project explores how to combine Kubernetes platform engineering with an IoT-style data ingestion and analytics pipeline on Google Cloud. A simulated client produces device metrics, a FastAPI service stores raw events in Google Cloud Storage, and a Python ETL job uses BigQuery SQL to aggregate the data into a curated analytics table.

The infrastructure is organized into reusable Terraform modules and environment-specific stacks. Kubernetes platform add-ons are represented with Helm and Argo CD manifests, while Google Cloud Workload Identity is used in the infrastructure design to avoid long-lived service-account keys for workloads running on GKE.

The goal is to demonstrate the separation of infrastructure provisioning, application delivery, data processing, and operational concerns.

## Architecture

### Data Flow

```text
Simulated IoT Client (Python)
          |
          | HTTP POST /metrics
          v
FastAPI Ingestion Service
          |
          | JSON Lines (.jsonl)
          v
Google Cloud Storage (raw/dt=YYYY-MM-DD/)
          |
          | Hive-partitioned external table
          v
BigQuery: raw_external
          |
          | Date-filtered SQL MERGE
          v
BigQuery: device_metrics_agg
          |
          v
Analytics / Reporting (future integration)
```

The ingestion service groups each HTTP request into a JSONL object and uploads it to a date-partitioned path in GCS. A BigQuery external table exposes the raw objects for querying. The ETL job calculates per-device daily aggregates and writes them to a partitioned, clustered BigQuery table.

### Platform Components

| Layer | Technologies | Purpose |
| --- | --- | --- |
| Infrastructure | Terraform | Define reusable GCP infrastructure modules and dev stacks |
| Compute | GKE | Host containerized workloads and Kubernetes platform components |
| Networking | VPC, VPC-native GKE | Provide cluster networking and Pod/Service secondary IP ranges |
| Image storage | Artifact Registry | Store application container images |
| Ingestion | Python, FastAPI | Accept batches of device metrics through a REST API |
| Raw data | Google Cloud Storage | Store incoming events as JSONL objects |
| Analytics | BigQuery | Query external raw data and maintain aggregated tables |
| Workload access | GKE Workload Identity, IAM | Support Google Cloud API access from Kubernetes workloads |
| GitOps | Argo CD, Helm | Define platform applications declaratively |
| Observability | Prometheus/Grafana, logging manifests | Initial monitoring and logging configurations |

## Application Components

### 1. Simulated Client

The Python fake client generates synthetic device measurements and sends them to the ingestion API, allowing the data path to be exercised without physical IoT devices.

Source: [`app/tools/fake_client.py`](app/tools/fake_client.py)

### 2. Ingestion API

The FastAPI application provides:

- `GET /health` — Basic application health check.
- `POST /metrics` — Accept a batch of records containing `device_id`, `ts`, and `value`.
- GCS upload of newline-delimited JSON under `raw/dt=YYYY-MM-DD/`.
- Authentication through Google Cloud Application Default Credentials; workloads on GKE can use Workload Identity when configured.

The current path partition is based on the server's UTC ingestion date, rather than the timestamps within individual metrics.

Source: [`app/ingest-api/main.py`](app/ingest-api/main.py)

### 3. BigQuery ETL Job

The Python job executes a parameterized, date-filtered **BigQuery `MERGE`** from `raw_external` into `device_metrics_agg`. For each device and processing date, it computes:

- Number of measurements
- Average value
- Minimum and maximum values
- Processing timestamp

It filters out negative metric values and updates existing device/date rows, making reruns suitable for refreshing aggregates for the same date. The job emits structured JSON logs with the job ID, billed bytes, and affected row count.

By default, it processes the previous UTC date. A specific date can be supplied using `PROCESS_DATE`.

**Implementation note:** The current ETL implementation uses the BigQuery Python client and SQL; it does **not** depend on DuckDB for the aggregation step.

Source: [`app/etl-job/main.py`](app/etl-job/main.py)

## Infrastructure as Code

Terraform modules cover:

- **VPC:** Network and subnetwork configuration with secondary IP ranges for GKE Pods and Services.
- **GKE:** A regional cluster, private worker nodes, configurable node autoscaling, dedicated node service account, and Workload Identity configuration.
- **Artifact Registry:** Container image repository.
- **Data platform:** GCS raw-data bucket, BigQuery dataset, external table, aggregated table, and ETL IAM identity.
- **Workload Identity:** Resources for service-account integration.
- **Kubernetes add-ons:** Initial Helm-based installation of Argo CD and External Secrets Operator.

The environment-specific Terraform stacks are located under `infra/stacks/dev/`. The project separates foundational networking, GKE compute, add-ons, data resources, and image registry configuration.

The GCS bucket implementation also distinguishes development and production-oriented deletion behavior, although this repository currently focuses on the development environment.

## BigQuery Data Model

### Raw external table: `raw_external`

Raw JSONL objects are exposed via a BigQuery external table using **Hive-style date partitioning** from the GCS object path. Queries require a partition filter to avoid unnecessarily scanning all stored data.

### Curated table: `device_metrics_agg`

The aggregate table stores `device_id`, `dt`, `count`, `avg_val`, `min_val`, `max_val`, and `processed_at`. It is **partitioned by `dt`** and **clustered by `device_id`**.

The SQL `MERGE` updates or inserts aggregates based on the composite key of date and device ID.

## Kubernetes Platform and GitOps

The repository includes an **Argo CD app-of-apps** root application at [`k8s/argocd/applications/platform-root.yaml`](k8s/argocd/applications/platform-root.yaml), along with initial application manifests for:

- **Apache Airflow:** Helm application definition for workflow orchestration.
- **Prometheus and Grafana:** Monitoring stack configuration based on `kube-prometheus-stack`.
- **Logging:** Initial Helm-based logging application definition.
- **External Secrets Operator:** SecretStore and ExternalSecret configurations for integrating with Google Secret Manager.

**Current limitations:** Some referenced Helm values files are empty or not yet present, and application manifests alone do not confirm successful deployment. Airflow DAG-based ETL scheduling, automated application delivery, and the full observability stack should be treated as ongoing work until validated.

## Development and Local Testing

The repository includes helper scripts to run the ingestion and ETL components locally using Docker:

- [`scripts/run_ingest.sh`](scripts/run_ingest.sh) — Launch the ingestion service and fake client.
- [`scripts/run_etl_job.sh`](scripts/run_etl_job.sh) — Run a BigQuery aggregation job for a specified processing date.
- [`scripts/artifact_upload.sh`](scripts/artifact_upload.sh) — Assist with container artifact publishing.

These scripts expect local configuration in a root-level `.env` file and locally built container images.

Typical configuration variables include:

| Variable | Purpose |
| --- | --- |
| `GCS_BUCKET` | Raw-data GCS bucket |
| `GCS_PREFIX` | Object prefix (defaults to `raw` in the API) |
| `GCP_PROJECT` | Google Cloud project for the ingestion client |
| `BQ_PROJECT` | BigQuery project |
| `BQ_DATASET` | BigQuery dataset |
| `BQ_EXTERNAL_TABLE` | External raw-data table, e.g. `raw_external` |
| `BQ_TARGET_TABLE` | Aggregated output table, e.g. `device_metrics_agg` |
| `PROCESS_DATE` | Optional UTC date to process |
| `GOOGLE_APPLICATION_CREDENTIALS` | Local credential path when not using workload identity |

Do not commit `.env` files or credential JSON files. For workloads running on GKE, prefer Workload Identity over distributing static service-account keys.

> The helper scripts are development utilities rather than a fully automated installation guide. Check their environment, credentials, and Docker image prerequisites before executing them.

## Repository Layout

```text
app/
  ingest-api/       # FastAPI ingestion application
  etl-job/          # BigQuery SQL aggregation job
  tools/            # Synthetic metrics client
infra/
  modules/          # Reusable Terraform modules
  stacks/dev/       # Development infrastructure stacks
  docs/             # Infrastructure design notes
k8s/
  argocd/           # Root and platform applications
  eso/              # External Secrets configuration
  external-dns/     # Initial DNS/secret configuration
  values/           # Helm values for platform components
scripts/            # Local execution and artifact helpers
```

## Implementation Status and Next Steps

**Implemented in source:**

- Terraform modules and development stacks for GCP networking, GKE, Artifact Registry, and the BigQuery/GCS data layer
- FastAPI ingestion service writing JSONL objects to GCS
- Synthetic metrics client
- BigQuery external table and partitioned curated table definitions
- Parameterized BigQuery `MERGE` ETL job with structured logging
- Argo CD root application and initial add-on manifests
- Workload Identity and External Secrets configuration resources

**Ongoing / not yet fully verified:**

- End-to-end deployment and repeatable GKE application lifecycle
- Completion of referenced Airflow Helm values and ETL scheduling DAGs
- Validation of monitoring, logging, and alerting deployments
- Automated CI/CD pipelines for image build, publish, and promotion
- Data quality validation, failure recovery, retries, and operational runbooks
- Load, reliability, security, and cost testing

## Project Scope

This is a **development-stage demonstration of GCP platform engineering and batch data processing**, intended to document architecture experiments and practical implementation progress. It does not claim production-grade high availability, completed Airflow orchestration, or fully automated GitOps releases.

