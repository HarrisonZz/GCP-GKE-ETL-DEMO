import os
import sys
import json
import logging
from datetime import datetime, timedelta, timezone
from google.cloud import bigquery
from google.api_core.exceptions import GoogleAPICallError

# ==========================================
# 1. 優化後的 Logging 設定
# ==========================================
class JsonFormatter(logging.Formatter):
    def format(self, record):
        json_log = {
            "severity": record.levelname,
            "message": record.getMessage(),
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "component": "etl-cleaning-job",
        }
        
        # error_details 處理
        if record.exc_info:
            json_log["error_details"] = self.formatException(record.exc_info)

        skip_keys = {
            'args', 'asctime', 'created', 'exc_info', 'exc_text', 'filename',
            'funcName', 'levelname', 'levelno', 'lineno', 'module',
            'msecs', 'message', 'msg', 'name', 'pathname', 'process',
            'processName', 'relativeCreated', 'stack_info', 'thread', 'threadName'
        }
        
        for key, value in record.__dict__.items():
            if key not in skip_keys and key not in json_log:
                json_log[key] = value

        return json.dumps(json_log)

handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JsonFormatter())

# 建議給 Logger 一個名字，避免汙染 root logger，
# 這樣可以過濾掉 google.cloud 套件本身產生的大量 debug log
logger = logging.getLogger("etl_job")
logger.setLevel(logging.INFO)
logger.addHandler(handler)

# ==========================================
# 2. 主程式邏輯
# ==========================================
def run_etl():
    try:
        # 環境變數檢查
        bq_project = os.environ["BQ_PROJECT"]
        bq_dataset = os.environ["BQ_DATASET"]
        target = os.environ["BQ_TARGET_TABLE"]
        ext = os.environ["BQ_EXTERNAL_TABLE"]
        
        # 【修正】從環境變數讀取 ENV，預設為 dev
        env_label = os.getenv("ENV", "dev").lower()
        
        process_date = os.getenv("PROCESS_DATE") or (datetime.now(timezone.utc).date() - timedelta(days=1)).isoformat()
        
        logger.info(f"Starting ETL job", extra={"process_date": process_date, "env": env_label})

        client = bigquery.Client(project=bq_project)

        sql = f"""
        MERGE `{bq_project}.{bq_dataset}.{target}` T
        USING (
          SELECT
            device_id,
            DATE(@dt) AS dt,
            COUNT(1) AS count,
            ROUND(AVG(value), 2) AS avg_val,
            MIN(value) AS min_val,
            MAX(value) AS max_val,
            CURRENT_TIMESTAMP() AS processed_at
          FROM `{bq_project}.{bq_dataset}.{ext}`
          WHERE dt = DATE(@dt) 
            AND value >= 0 
          GROUP BY device_id
        ) S
        ON T.dt = S.dt AND T.device_id = S.device_id
        
        WHEN MATCHED THEN UPDATE SET
          count = S.count,
          avg_val = S.avg_val,
          min_val = S.min_val,
          max_val = S.max_val,
          processed_at = S.processed_at
          
        WHEN NOT MATCHED THEN
          INSERT (device_id, dt, count, avg_val, min_val, max_val, processed_at)
          VALUES (S.device_id, S.dt, S.count, S.avg_val, S.min_val, S.max_val, S.processed_at)
        """

        # 設定 Job Config
        job_config = bigquery.QueryJobConfig(
            query_parameters=[bigquery.ScalarQueryParameter("dt", "DATE", process_date)],
            labels={
                "job_type": "etl_daily", 
                "env": env_label, # 【修正】使用變數
                "component": "etl_cleaner"
            }
        )

        job = client.query(sql, job_config=job_config)
        
        # 等待結果
        result = job.result()
        
        # 取得統計資訊
        total_bytes = job.total_bytes_billed
        
        # 【修正】確保這些資訊會出現在 JSON Log 的頂層或 structuredPayload 中
        logger.info(f"ETL Job Completed successfully", extra={
            "process_date": process_date,
            "bytes_billed": total_bytes,
            "affected_rows": job.num_dml_affected_rows,
            "job_id": job.job_id
        })

    except GoogleAPICallError as e:
        # 這裡的錯誤通常是 SQL 語法錯、權限不足、Quota 不足
        logger.error(f"BigQuery API failed", exc_info=True)
        sys.exit(1)
    except Exception as e:
        # 這裡捕捉其他 Python 錯誤 (如 key error, network timeout)
        logger.error(f"Unexpected error", exc_info=True)
        sys.exit(1)

if __name__ == "__main__":
    run_etl()