FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.12-slim
WORKDIR /app

RUN mkdir -p /data && \
    useradd --create-home --home-dir /app appuser && \
    chown -R appuser:appuser /app /data

COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY app.py .

ENV GREETING="Hello from the container" \
    DATA_DIR=/data \
    PORT=8000

VOLUME ["/data"]
EXPOSE 8000
USER appuser

CMD ["python", "app.py"]