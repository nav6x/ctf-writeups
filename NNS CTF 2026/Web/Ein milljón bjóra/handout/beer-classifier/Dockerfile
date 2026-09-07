FROM ghcr.io/astral-sh/uv:python3.12-trixie-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-dev

RUN git clone https://github.com/huggingface/nanoVLM.git /opt/nanovlm \
    && git -C /opt/nanovlm checkout 4e0c0961846135c2217f95e54cb4c2d66eb55e42 \
    && cp -r /opt/nanovlm/models /opt/nanovlm/data /opt/nanovlm/utils /app/ \
    && rm -rf /opt/nanovlm

ENV HF_HOME=/app/.cache
COPY download.py ./
RUN uv run python download.py

COPY app.py ./
ENV HF_HUB_OFFLINE=1
EXPOSE 8000
CMD ["uv", "run", "uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
