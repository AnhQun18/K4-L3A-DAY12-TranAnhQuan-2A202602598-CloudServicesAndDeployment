# ═══════════════════════════════════════════════════════════════════
# CP2 — Multi-stage Dockerfile (production-ready)
# ═══════════════════════════════════════════════════════════════════

# ── Stage 1: builder — cài đặt thư viện ──────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

# Copy requirements trước để tận dụng Docker layer cache:
# sửa code không phải cài lại thư viện
COPY requirements.txt .

RUN pip install --upgrade pip \
    && pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: runtime — image nhỏ gọn, không mang theo compiler ───
FROM python:3.11-slim AS runtime

# Tạo user thường (non-root) — ai thoát khỏi app không thành root host
RUN groupadd --system appgroup \
    && useradd --system --gid appgroup --no-create-home appuser

WORKDIR /app

# Copy thư viện đã build từ stage builder
COPY --from=builder /install /usr/local

# Copy source code SAU pip install để cache layer thư viện không bị vỡ
COPY utils ./utils
COPY app ./app

# Đổi chủ sở hữu cho user thường
RUN chown -R appuser:appgroup /app

USER appuser

# Cloud tự gán cổng qua biến môi trường PORT
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:${PORT:-8000}/health')" || exit 1

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
