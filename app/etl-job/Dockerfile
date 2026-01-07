# 1. 使用官方 Python Slim 版本 (體積小，適合純 Script 執行)
FROM python:3.11-slim

# 設定環境變數
# PYTHONDONTWRITEBYTECODE: 不要在容器內產生 .pyc 檔
# PYTHONUNBUFFERED: 讓 Log 直接輸出到 stdout，這對 K8s Logging 很重要
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# 2. 安全性最佳實踐：建立非 root 使用者
# 避免使用 root 權限執行程式
RUN useradd -m -u 1000 appuser

WORKDIR /app

# 3. 安裝依賴 (利用 Layer Cache)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4. 切換到非 root 使用者
USER appuser

# 5. 複製程式碼
# 注意權限歸屬要改為 appuser
COPY --chown=appuser:appuser . .

# 6. 啟動指令
CMD ["python", "main.py"]