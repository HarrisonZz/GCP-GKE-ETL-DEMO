#!/bin/bash

# --- 設定變數 ---
CONTAINER_NAME="ingest-api-container"
IMAGE_NAME="ingest-api:v1"

CLIENT_CONTAINER_NAME="fake-client-container"
CLIENT_IMAGE="fake-client:latest"

HOST_PORT="8000"  # 為了避開 Jenkins (8080)，我們改用 8081
CONTAINER_PORT="8000" # FastAPI 預設 Port

# --- 1. 清理舊容器 (如果有) ---
if [ "$(docker ps -aq -f name=^/${CONTAINER_NAME}$)" ]; then
    echo "♻️  發現舊容器，正在移除..."
    docker rm -f $CONTAINER_NAME
fi

# --- 2. 從 Terraform 獲取變數 ---
# 為了避免每次都跑 terraform 指令太慢，您也可以選擇把這些值寫死在 .env 裡
# 但這裡我們依照您的需求，動態去抓取
echo "🔍 正在讀取 Terraform Output..."
TF_DIR="./infra/stacks/eks" # ⚠️ 請確認這是您 terraform 檔案所在的資料夾路徑，如果在當前目錄則改為 "."

if [ ! -d "$TF_DIR" ]; then
    echo "❌ 錯誤：找不到 Terraform 目錄 ($TF_DIR)"
    exit 1
fi

# 使用 pushd/popd 切換目錄去執行 terraform 指令
pushd $TF_DIR > /dev/null
AWS_ACCESS_KEY_ID=$(terraform output -raw ingest_api_iam_access_key_id)
AWS_SECRET_ACCESS_KEY=$(terraform output -raw ingest_api_iam_access_key)
S3_BUCKET=$(terraform output -raw data_bucket_name)
popd > /dev/null

# 檢查是否有抓到值
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$S3_BUCKET" ]; then
    echo "❌ 錯誤：無法從 Terraform 讀取到必要的變數，請確認 terraform apply 是否已執行。"
    exit 1
fi

# --- 3. 啟動容器 ---
echo "🚀 正在啟動 Ingest API..."
docker run -d \
  -p ${HOST_PORT}:${CONTAINER_PORT} \
  -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
  -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
  -e AWS_DEFAULT_REGION="ap-northeast-1" \
  -e S3_BUCKET="$S3_BUCKET" \
  --name $CONTAINER_NAME \
  $IMAGE_NAME

# --- 4. 驗證 ---
echo "✅ 容器已啟動！"
echo "🌐 API 位址: http://localhost:${HOST_PORT}"
echo "-----------------------------------"
echo "正在檢查 logs (前 5 行)..."
sleep 2 # 等待容器初始化
docker logs $CONTAINER_NAME | head -n 5

# --- 4. 等待 API 就緒 ---
echo "⏳ 等待 API 啟動中 (5秒)..."
sleep 3

# 簡單檢查一下 API 是否活著
if curl -s "http://localhost:${HOST_PORT}/health" > /dev/null; then
    echo "✅ API 已上線！"
else
    echo "⚠️  警告：API 似乎還沒準備好，或者是 Health Check 路徑不對。繼續嘗試啟動 Client..."
    # 這裡不 exit，讓它繼續跑跑看
fi

echo "🌊 正在啟動 Fake Client 發送流量..."
echo "🎯 目標 API: http://host.docker.internal:${HOST_PORT}/metrics"

# 這裡不加 -d，直接跑在前台讓你看到 log (如果想背景跑就加 -d)
docker run \
  --name $CLIENT_CONTAINER_NAME \
  -e API_URL="http://host.docker.internal:${HOST_PORT}/metrics" \
  $CLIENT_IMAGE