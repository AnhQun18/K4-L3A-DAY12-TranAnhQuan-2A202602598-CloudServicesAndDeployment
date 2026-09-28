# Thông Tin Deploy — Checkpoint 5

> Điền file này sau khi deploy xong. `pytest tests/test_cp5.py` đọc file này
> để tìm địa chỉ service của bạn và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị API key vào đây.**
> Repo này công khai — dán khóa vào là mất khóa.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Trần Anh Quân |
| Mã học viên | 2A202602598 |
| Repo | https://github.com/AnhQun18/K4-L3A-DAY12-TranAnhQuan-2A202602598-CloudServicesAndDeployment |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://ai-agent-cloud-production-72a7.up.railway.app |
| Platform | Railway |
| Ngày deploy | 2026-09-28 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | platform tự gán (8080) |
| `AGENT_API_KEY` | ✅ | đặt trong dashboard Railway, không nằm trong repo |
| `REDIS_URL` | ✅ | Redis add-on của Railway (${{Redis.REDIS_URL}}) |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

Thay `<URL>` bằng Public URL ở trên:

```bash
# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i https://ai-agent-cloud-production-72a7.up.railway.app/health

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i https://ai-agent-cloud-production-72a7.up.railway.app/ready

# 3. Không có API key — mong đợi 401
curl -i -X POST https://ai-agent-cloud-production-72a7.up.railway.app/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'

# 4. Có API key — mong đợi 200 kèm câu trả lời
curl -i -X POST https://ai-agent-cloud-production-72a7.up.railway.app/ask \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AGENT_API_KEY" \
  -H "X-User-Id: sv-test" \
  -d '{"question":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST https://ai-agent-cloud-production-72a7.up.railway.app/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" \
    -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'
done; echo
```

## Kết Quả Chạy Thật

Dán output của các lệnh trên vào đây:

```
# 1. GET /health
HTTP/1.1 200 OK
content-length: 57
content-type: application/json
date: Mon, 28 Sep 2026 08:50:35 GMT
server: uvicorn

{"status":"ok","service":"day12-agent","version":"1.0.0"}

# 2. GET /ready
HTTP/1.1 200 OK
content-length: 32
content-type: application/json
date: Mon, 28 Sep 2026 08:50:42 GMT
server: uvicorn

{"status":"ready","redis":true}

# 3. POST /ask (không có API key)
HTTP/1.1 401 Unauthorized
content-length: 39
content-type: application/json
date: Mon, 28 Sep 2026 08:51:22 GMT
server: uvicorn

{"detail":"invalid or missing API key"}

# 4. POST /ask (có API key hợp lệ)
HTTP/1.1 200 OK
content-length: 312
content-type: application/json
date: Mon, 28 Sep 2026 08:51:36 GMT
server: uvicorn

{"answer":"Ngắn gọn: Deploy la gi phụ thuộc vào ba yếu tố — cấu hình qua biến môi trường, health check để orchestrator biết trạng thái, và giới hạn tài nguyên. (Mình đang nhớ 2 lượt trao đổi trước đó.)","user_id":"sv-test","history_length":2,"cost_usd":0.00003465,"tokens":{"in":43,"out":47}}

# 5. POST /ask spam rate limit (15 requests liên tiếp)
HTTP Status Codes:
200 200 200 200 200 200 200 200 429 429 429 429 429 429 429
```

## Ảnh Chụp Màn Hình

Đã lưu ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trang quản lý service và database Redis trên Railway
- `screenshots/health.png` — kết quả gọi `/health` kiểm tra trạng thái dịch vụ
