import duckdb
import logging
from datetime import datetime, timezone
import os
from dataclasses import dataclass
from google.cloud import bigquery # 需要 pip install google-cloud-bigquery

# 設定 Logging
logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

@dataclass
class ETLConfig:
    gcs_bucket: str          # 來源 Bucket (GCS)
    project_id: str          # GCP Project ID
    dataset_id: str          # BigQuery Dataset
    table_id: str            # BigQuery Table
    process_date: str
    memory_limit: str = "512MB"
    threads: int = 2
    temp_dir: str = "/tmp/duckdb_spill"

class DuckDBToBigQueryPipeline:
    def __init__(self, config: ETLConfig):
        self.config = config
        
        # 1. 初始化 DuckDB
        self.con = duckdb.connect(config={
            'memory_limit': config.memory_limit,
            'threads': config.threads,
            'temp_directory': config.temp_dir
        })
        
        # 2. 初始化 BigQuery Client (GKE 會自動抓權限，不用塞 Key)
        self.bq_client = bigquery.Client(project=config.project_id)
        
        self._setup_gcs_auth()

    def _ensure_temp_dir(self):
        os.makedirs(self.config.temp_dir, exist_ok=True)

    def _setup_gcs_auth(self):
        """
        DuckDB 讀取 GCS 需要 httpfs 擴充。
        在 GKE 內，通常不需要額外設定 Key，或者使用 HMAC Key 兼容 S3 協議。
        這裡示範最簡單的：讓 DuckDB 知道我們要讀遠端檔案。
        """
        try:
            self.con.execute("INSTALL httpfs; LOAD httpfs;")
            # 若在 GKE 且有 Workload Identity，DuckDB 0.10+ 可嘗試直接讀
            # 但最穩的方式是讓 Python 下載 -> DuckDB 讀 -> 上傳，
            # 或者設定 GCS HMAC Key (視同 S3)。
            # 這裡假設環境變數有 GCS HMAC KEY (最通用的跨雲做法)
            if os.getenv("GCP_ACCESS_KEY_ID"):
                self.con.execute(f"""
                    SET s3_region='auto';
                    SET s3_endpoint='storage.googleapis.com';
                    SET s3_access_key_id='{os.getenv('GCP_ACCESS_KEY_ID')}';
                    SET s3_secret_access_key='{os.getenv('GCP_SECRET_ACCESS_KEY')}';
                """)
        except Exception as e:
            logger.error(f"Failed to setup DuckDB GCS extension: {e}")
            raise

    def run(self):
        logger.info(f"🚀 Starting ETL: GCS -> DuckDB -> BigQuery for date: {self.config.process_date}")
        
        # 1. 定義路徑
        input_path = f"s3://{self.config.gcs_bucket}/raw/{self.config.process_date}/*.jsonl" # DuckDB 用 s3 protocol 讀 GCS
        local_staging_file = f"{self.config.temp_dir}/agg_data.parquet"

        # 2. Extract & Transform (DuckDB)
        # 這裡我們將結果寫入「本地暫存檔」，而不是直接寫回 Cloud Storage
        query = f"""
        COPY (
            SELECT 
                device_id,
                '{self.config.process_date}'::DATE AS date,
                COUNT(*) AS count,
                ROUND(AVG(value), 2) AS avg_val, -- BigQuery 欄位名避免用 avg 關鍵字
                MIN(value) AS min_val,
                MAX(value) AS max_val,
                now() AS processed_at
            FROM read_json_auto('{input_path}', format='newline_delimited')
            WHERE value >= 0 
            GROUP BY device_id
            ORDER BY device_id ASC
        ) TO '{local_staging_file}' (FORMAT 'PARQUET', CODEC 'SNAPPY');
        """

        try:
            # Step A: DuckDB 運算並落地
            logger.info("⏳ [Step 1/2] DuckDB Processing & Staging...")
            self.con.execute(query)
            logger.info(f"✅ Staging completed: {local_staging_file}")

            # Step B: Load to BigQuery
            logger.info("⏳ [Step 2/2] Loading to BigQuery...")
            self._load_parquet_to_bq(local_staging_file)
            
        except Exception as e:
            logger.error(f"❌ ETL Failed: {e}")
            raise
        finally:
            # 清理暫存檔 (DevOps 好習慣)
            if os.path.exists(local_staging_file):
                os.remove(local_staging_file)

    def _load_parquet_to_bq(self, parquet_file: str):
        """
        使用 Google 官方 SDK 將 Parquet 上傳到 BigQuery
        """
        table_ref = f"{self.config.project_id}.{self.config.dataset_id}.{self.config.table_id}"
        
        job_config = bigquery.LoadJobConfig(
            source_format=bigquery.SourceFormat.PARQUET,
            write_disposition=bigquery.WriteDisposition.WRITE_APPEND, # 或是 WRITE_TRUNCATE 覆蓋
        )

        with open(parquet_file, "rb") as source_file:
            job = self.bq_client.load_table_from_file(
                source_file,
                table_ref,
                job_config=job_config
            )

        job.result()  # 等待 Job 完成
        
        # 驗證筆數
        table = self.bq_client.get_table(table_ref)
        logger.info(f"✅ Loaded {job.output_rows} rows to {table_ref}. Total rows: {table.num_rows}")

# --- Entry Point ---
if __name__ == "__main__":
    # 環境變數模擬 (實戰中由 Kubernetes ConfigMap/Secret 注入)
    config = ETLConfig(
        gcs_bucket=os.getenv("GCS_BUCKET", "my-raw-data-bucket"),
        project_id=os.getenv("GCP_PROJECT_ID", "my-gcp-project"),
        dataset_id=os.getenv("BQ_DATASET", "data_platform"),
        table_id=os.getenv("BQ_TABLE", "device_metrics"),
        process_date=os.getenv("PROCESS_DATE", datetime.now(timezone.utc).strftime("%Y-%m-%d")),
        memory_limit=os.getenv("DUCKDB_MEMORY_LIMIT", "512MB")
    )
    
    pipeline = DuckDBToBigQueryPipeline(config)
    pipeline.run()