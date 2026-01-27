# Workload Identity 設計文檔

## 概述

本文檔說明了 GKE 叢集中 Workload Identity 的架構設計，包括各個元件的 Service Account 配置和權限管理。

## 架構設計

### 1. GKE 叢集層級

- **Workload Identity 已啟用**: `workload_pool = "${project_id}.svc.id.goog"`
- **Node Service Account**: 專用於 GKE 節點的基本運作權限

### 2. 應用程式層級 Workload Identity

#### 2.1 FastAPI (Ingest API)
- **GCP SA**: `ingest-api-sa`
- **K8s SA**: `ingest-api-ksa` (namespace: `default`)
- **權限**:
  - `roles/storage.objectCreator` - 創建 GCS 物件
  - `roles/logging.logWriter` - 寫入 Cloud Logging

#### 2.2 ETL Cleaning Job
- **GCP SA**: `etl-cleaning-sa`
- **K8s SA**: `etl-cleaning-job-ksa` (namespace: `default`)
- **權限**:
  - `roles/storage.objectUser` - 存取 GCS 物件
  - `roles/logging.logWriter` - 寫入 Cloud Logging

#### 2.3 External Secrets Operator
- **GCP SA**: `external-secrets-gsa`
- **K8s SA**: `external-secrets-sa` (namespace: `external-secrets`)
- **權限**:
  - `roles/secretmanager.secretAccessor` - 存取 Secret Manager
  - `roles/secretmanager.viewer` - 查看 Secret Manager

#### 2.4 Monitoring 元件
- **GCP SA**: `monitoring-secrets-gsa`
- **K8s SA**: `monitoring-secrets-sa` (namespace: `monitoring`)
- **權限**:
  - `roles/secretmanager.secretAccessor` - 存取 Secret Manager
  - `roles/monitoring.viewer` - 查看監控數據

## 模組依賴關係

```
compute/gke (GKE 叢集)
├── fastapi_identity (Workload Identity)
├── etl_identity (Workload Identity)
└── compute/addons
    ├── k8s_addons (Kubernetes Add-ons)
    ├── external_secrets_identity (Workload Identity)
    └── monitoring_identity (Workload Identity)
```

## 使用方式

### 在 Kubernetes 中使用 Workload Identity

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  serviceAccountName: ingest-api-ksa  # 使用對應的 K8s SA
  containers:
  - name: my-app
    image: gcr.io/my-project/my-app
```

### 在 External Secrets 中使用

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: gcp-secret-store
  namespace: external-secrets
spec:
  provider:
    gcpsm:
      projectID: your-project-id
      auth:
        workloadIdentity:
          clusterLocation: asia-east1
          clusterName: etl-demo-cluster
          serviceAccountRef:
            name: external-secrets-sa  # 使用對應的 K8s SA
            namespace: external-secrets
```

## 安全性考量

1. **最小權限原則**: 每個 Service Account 只被授予必要的權限
2. **命名空間隔離**: 不同功能的 Service Account 分布在不同的命名空間
3. **權限分離**: 應用程式和系統元件使用不同的 Service Account

## 部署順序

1. 部署 GKE 叢集 (`compute/gke`)
2. 部署基礎 Workload Identity (`fastapi_identity`, `etl_identity`)
3. 部署 Kubernetes Add-ons (`compute/addons`)
4. 部署 Add-ons 專用的 Workload Identity (`external_secrets_identity`, `monitoring_identity`)

## 故障排除

### 常見問題

1. **Workload Identity 綁定失敗**
   - 檢查 GKE 叢集是否啟用 Workload Identity
   - 確認 K8s SA 的 annotation 格式正確

2. **權限不足**
   - 驗證 GCP SA 的 IAM 角色設定
   - 檢查 Workload Identity 綁定是否正確建立

3. **依賴關係錯誤**
   - 確保 GKE 叢集完全建立後再部署 Workload Identity
   - 檢查 Terraform state 的依賴關係

### 驗證命令

```bash
# 檢查 Workload Identity 綁定
gcloud iam service-accounts get-iam-policy ingest-api-sa@your-project.iam.gserviceaccount.com

# 檢查 K8s SA annotation
kubectl get serviceaccount ingest-api-ksa -o yaml

# 測試權限
kubectl run test-pod --image=google/cloud-sdk:latest --serviceaccount=ingest-api-ksa --restart=Never -- gcloud auth list
```
