from datetime import datetime, timezone
import json
import os
import uuid
from typing import Optional, List

import boto3
from botocore.config import Config
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field, validator

class Settings(BaseModel):
    aws_region: str = Field(default="ap-northeast-1", alias="AWS_REGION")
    s3_bucket: str = Field(..., alias="S3_BUCKET")
    s3_prefix: str = Field(default="raw", alias="S3_PREFIX")

    class Config:
        allow_population_by_field_name = True

def load_settings() -> Settings:
    try:
        return Settings(
            AWS_REGION=os.getenv("AWS_REGION", "ap-northeast-1"),
            S3_BUCKET=os.getenv("S3_BUCKET", ""),
            S3_PREFIX=os.getenv("S3_PREFIX", "raw"),
        )
    except Exception as e:
        raise RuntimeError(f"Invalid settings: {e}")

settings = load_settings()

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

    @validator("ts", pre=True)
    def parse_ts(cls, v):
        # 允許字串 ISO8601
        if isinstance(v, str):
            try:
                return datetime.fromisoformat(v.replace("Z", "+00:00"))
            except Exception as e:
                raise ValueError(f"Invalid timestamp format: {e}")
        return v

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
    first_ts = payload.metrics[0].ts.astimezone(timezone.utc)
    date_str = first_ts.strftime("%Y-%m-%d")
    iso_now = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    unique_id = uuid.uuid4().hex[:8]

    # S3 key: raw/2025-12-13/metrics-20251213T120000Z-abcdef01.jsonl
    key = f"{settings.s3_prefix}/{date_str}/metrics-{iso_now}-{unique_id}.jsonl"

    # 組 JSONL 內容
    lines = []
    for m in payload.metrics:
        # 統一轉成 ISO8601 UTC
        ts_iso = m.ts.astimezone(timezone.utc).isoformat()
        lines.append(
            json.dumps(
                {
                    "device_id": m.device_id,
                    "ts": ts_iso,
                    "value": m.value,
                },
                separators=(",", ":"),
            )
        )
    body = "\n".join(lines) + "\n"

    try:
        s3.put_object(
            Bucket=settings.s3_bucket,
            Key=key,
            Body=body.encode("utf-8"),
            ContentType="application/json",
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to write to S3: {e}")

    return {
        "status": "ok",
        "bucket": settings.s3_bucket,
        "key": key,
        "count": len(payload.metrics),
    }