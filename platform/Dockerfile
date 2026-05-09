FROM python:3.11-slim

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends docker.io curl \
    && pip install --no-cache-dir fastapi uvicorn \
    && rm -rf /var/lib/apt/lists/*

CMD ["uvicorn", "platform.api:app", "--host", "0.0.0.0", "--port", "8000"]
