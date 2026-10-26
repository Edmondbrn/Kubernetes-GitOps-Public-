# Download and build packages
FROM python:3.13-slim-trixie AS builder
COPY --from=ghcr.io/astral-sh/uv:0.12.5 /uv /uvx /bin/
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-project --no-dev

# Runtime
FROM python:3.13-slim-trixie


ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Create non root user
RUN groupadd -g 1000 appuser && \
    useradd -u 1000 -g appuser -m -s /bin/sh appuser && \
    mkdir -p /celery/write /user-results/write /var/log/app && \
    chown appuser:appuser /celery/write /user-results/write /var/log/app
    
WORKDIR /app
COPY --from=builder /app/.venv /app/.venv 
COPY --chown=appuser:appuser . .
COPY --chmod=755 start_backend_prod.sh ./start_backend_prod.sh

USER appuser
CMD ["./start_backend_prod.sh"]