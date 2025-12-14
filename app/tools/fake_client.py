import random
import time
from datetime import datetime, timezone
from typing import List
import os
import requests
from faker import Faker
fake = Faker()

fake = Faker()
API_URL = os.getenv("API_URL", "http://localhost:8000/metrics")

DEVICE_IDS: List[str] = [f"dev-{i:03d}" for i in range(1, 51)]  # dev-001 ~ dev-050


def gen_metric():

    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    
    status = random.choice(["ok", "ok", "ok", "warn", "error"])

    return {
        "device_id": random.choice(DEVICE_IDS),
        "ts": now,
        "value": round(random.uniform(-50, 200), 2),
        "location": fake.city(),
        "status": status,
    }


def send_batch(batch_size: int = 20):
    metrics = [gen_metric() for _ in range(batch_size)]
    payload = {"metrics": metrics}
    resp = requests.post(API_URL, json=payload, timeout=5)
    resp.raise_for_status()
    print("Sent batch:", batch_size, "status:", resp.status_code, "resp:", resp.json())


def main():
    # 一共送 10 批，每批 20 筆，共 200 筆
    for i in range(10):
        send_batch(batch_size=20)
        # 間隔 1 秒，模擬時間序列
        time.sleep(1)


if __name__ == "__main__":
    main()
