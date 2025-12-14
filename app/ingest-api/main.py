from datetime import datetime, timezone
import json
import os
import uuid
from typing import Optional, List

import boto3
from botocore.config import Config
from fastapi import FastAPI, HTTPException
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    aws_region: str = Field(default="ap-northeast-1", alias="AWS_REGION")
    s3_bucket: str = Field(..., alias="S3_BUCKET")
    s3_prefix: str = Field(default="raw", alias="S3_PREFIX")

    model_config = SettingsConfigDict(
        env_prefix="",  
        case_sensitive=False # 允許 aws_region 對應 AWS_REGION
    )

    class Config:
        allow_population_by_field_name = True

try:
    settings = Settings()
except Exception as e:
    # 這裡可以捕捉 "missing environment variable" 的錯誤
    raise RuntimeError(f"Configuration error: {e}")

if not settings.s3_bucket:
    raise RuntimeError("S3_BUCKET environment variable is required")

# boto3 client（在 EKS 上建議配 IRSA，這裡先用預設 credential 機制）
s3 = boto3.client(
    "s3",
    region_name=settings.aws_region,
    config=Config(retries={"max_attempts": 3, "mode": "standard"}),
)

# ------------ Request Models ------------

class Metric(BaseModel):
    device_id: str
    ts: datetime
    value: float

class MetricsPayload(BaseModel):
    metrics: List[Metric]

# ------------ App ------------

app = FastAPI(title="ETL Ingest API", version="0.1.0")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/metrics")
def ingest_metrics(payload: MetricsPayload):
    """
    接收一批 metrics，寫成一個 S3 檔案（JSON Lines）
    """
    if not payload.metrics:
        raise HTTPException(status_code=400, detail="metrics must not be empty")

    # 取第一筆的日期當 partition key（簡化版）
    now_utc = datetime.now(timezone.utc)
    date_str = now_utc.strftime("%Y-%m-%d")         # YYYY-MM-DD
    time_str = now_utc.strftime("%Y%m%dT%H%M%SZ")   # ISO Compact
    unique_id = uuid.uuid4().hex[:8]

    # S3 key: raw/2025-12-13/metrics-20251213T120000Z-abcdef01.jsonl
    key = f"{settings.s3_prefix}/{date_str}/metrics-{time_str}-{unique_id}.jsonl"

    # 組 JSONL 內容
    lines = []
    for m in payload.metrics:
        # 統一轉成 ISO8601 UTC
        data = m.model_dump(mode='json')
        data['ts'] = m.ts.astimezone(timezone.utc).isoformat()
        lines.append(json.dumps(data, separators=(",", ":"))) # Compact JSON

    body = "\n".join(lines) + "\n"

    try:
        s3.put_object(
            Bucket=settings.s3_bucket,
            Key=key,
            Body=body.encode("utf-8"),
            ContentType="application/json",
        )
    except Exception as e:
        print(f"S3 Upload Error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to write to S3: {e}")

    return {
        "status": "ok",
        "bucket": settings.s3_bucket,
        "key": key,
        "count": len(payload.metrics),
    }