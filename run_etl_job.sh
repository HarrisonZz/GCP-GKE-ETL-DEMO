#!/bin/bash
set -e # 遇到錯誤立即停止

# --- 1. 設定變數與路徑 ---
# 假設 infra 資料夾在往上兩層的 infra (app/etl/ -> app/ -> root -> infra)
# 您可以根據實際位置調整 "../.."
TF_DIR="./infra/stacks/eks"
IMAGE_NAME="etl-job:v1"
CONTAINER_NAME="etl-job-runner"
# 預設跑今天的日期 (UTC)，也可以透過參數傳入: ./run_etl.sh 2025-12-13
PROCESS_DATE=${1:-$(date -u +%Y-%m-%d)}

echo "🔧 初始化設定..."
echo "   - Terraform 目錄: $TF_DIR"
echo "   - 處理日期: $PROCESS_DATE"

# --- 2. 檢查 Terraform 目錄 ---
if [ ! -d "$TF_DIR" ]; then
    echo "❌ 錯誤：找不到 Terraform 目錄 ($TF_DIR)"
    echo "   請確認路徑設定是否正確。"
    exit 1
fi

# --- 3. 抓取環境變數 (使用 -chdir 技巧) ---
echo "🔍 正在讀取 Terraform Output..."

# 嘗試讀取變數
AWS_ACCESS_KEY_ID=$(terraform -chdir=$TF_DIR output -raw ingest_api_iam_access_key_id 2>/dev/null || echo "")
AWS_SECRET_ACCESS_KEY=$(terraform -chdir=$TF_DIR output -raw ingest_api_iam_access_key 2>/dev/null || echo "")
S3_BUCKET=$(terraform -chdir=$TF_DIR output -raw data_bucket_name 2>/dev/null || echo "")

# --- 4. 關鍵防呆：檢查變數是否有效 ---
# 檢查是否讀取到空值，或讀取到 Terraform 的錯誤訊息 "Warning"
if [ -z "$S3_BUCKET" ] || [[ "$S3_BUCKET" == *"Warning"* ]] || [[ "$S3_BUCKET" == *"No outputs"* ]]; then
    echo "❌ 錯誤：無法正確讀取 Terraform Output！"
    echo "   原因可能是："
    echo "   1. 您還沒有執行 'terraform apply'"
    echo "   2. Terraform State 裡沒有 outputs (請去 infra 目錄執行 terraform output 檢查)"
    echo "   3. 讀取到的值是錯誤訊息"
    exit 1
fi

echo "✅ 成功讀取配置 (Bucket: $S3_BUCKET)"

# --- 5. 建置 Docker Image ---
# echo "🐳 正在建置 Docker Image..."
# docker build -t $IMAGE_NAME .

# --- 6. 執行容器 ---
echo "🚀 啟動 ETL Job..."
docker run --rm \
  -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
  -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
  -e AWS_DEFAULT_REGION="ap-northeast-1" \
  -e S3_BUCKET="$S3_BUCKET" \
  -e PROCESS_DATE="$PROCESS_DATE" \
  -e DUCKDB_MEMORY_LIMIT="512MB" \
  --name $CONTAINER_NAME \
  $IMAGE_NAME

echo "-----------------------------------"
echo "🏁 作業完成！"