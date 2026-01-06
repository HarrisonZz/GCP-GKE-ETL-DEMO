from datetime import datetime, timezone
import json
import os
import uuid
from typing import Optional, List

# --- GCP SDK Import ---
from google.cloud import storage
from google.api_core import exceptions as google_exceptions

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    # GCP 通常不需要顯式指定 Region 來初始化 Client，除非您要新建 Bucket
    # 但建議保留 project_id 以便除錯或特定需求
    gcp_project: Optional[str] = Field(default=None, alias="GCP_PROJECT")
    
    # 變數名稱改為 GCS 相關
    gcs_bucket: str = Field(..., alias="GCS_BUCKET")
    gcs_prefix: str = Field(default="raw", alias="GCS_PREFIX")

    model_config = SettingsConfigDict(
        env_prefix="",  
        case_sensitive=False
    )

try:
    settings = Settings()
except Exception as e:
    raise RuntimeError(f"Configuration error: {e}")

if not settings.gcs_bucket:
    raise RuntimeError("GCS_BUCKET environment variable is required")

# --- Initialize GCS Client ---
# 在 GKE (Workload Identity) 或本地 (GOOGLE_APPLICATION_CREDENTIALS) 
# 這行會自動抓取憑證，不需要像 boto3 那樣傳入 key/secret
try:
    if settings.gcp_project:
        gcs_client = storage.Client(project=settings.gcp_project)
    else:
        gcs_client = storage.Client()
except Exception as e:
    raise RuntimeError(f"Failed to initialize GCS Client: {e}")

# ------------ Request Models (維持不變) ------------

class Metric(BaseModel):
    device_id: str
    ts: datetime
    value: float

class MetricsPayload(BaseModel):
    metrics: List[Metric]

# ------------ App ------------

app = FastAPI(title="ETL Ingest API (GCS Version)", version="0.1.0")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/metrics")
def ingest_metrics(payload: MetricsPayload):
    """
    接收一批 metrics，寫成一個 GCS 檔案（JSON Lines）
    """
    if not payload.metrics:
        raise HTTPException(status_code=400, detail="metrics must not be empty")

    # 取第一筆的日期當 partition key
    now_utc = datetime.now(timezone.utc)
    date_str = now_utc.strftime("%Y-%m-%d")         # YYYY-MM-DD
    time_str = now_utc.strftime("%Y%m%dT%H%M%SZ")   # ISO Compact
    unique_id = uuid.uuid4().hex[:8]

    # GCS Object Name: raw/2025-12-13/metrics-20251213T120000Z-abcdef01.jsonl
    key = f"{settings.gcs_prefix}/{date_str}/metrics-{time_str}-{unique_id}.jsonl"

    # 組 JSONL 內容 (邏輯不變)
    lines = []
    for m in payload.metrics:
        data = m.model_dump(mode='json')
        data['ts'] = m.ts.astimezone(timezone.utc).isoformat()
        lines.append(json.dumps(data, separators=(",", ":"))) 

    body = "\n".join(lines) + "\n"

    try:
        # --- GCS Upload Logic ---
        # 1. 取得 Bucket 物件
        bucket = gcs_client.bucket(settings.gcs_bucket)
        
        # 2. 建立 Blob (檔案) 物件
        blob = bucket.blob(key)
        
        # 3. 上傳字串內容
        # retry 參數 GCS library 預設已經有處理，這裡使用預設即可
        blob.upload_from_string(
            data=body,
            content_type="application/json"  # 或是 application/x-ndjson
        )
        
    except google_exceptions.GoogleAPICallError as e:
        print(f"GCS API Error: {e}")
        raise HTTPException(status_code=502, detail=f"GCS upstream error: {e}")
    except Exception as e:
        print(f"Upload Error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to write to GCS: {e}")

    return {
        "status": "ok",
        "bucket": settings.gcs_bucket,
        "key": key,
        "count": len(payload.metrics),
        "storage": "GCS"
    }