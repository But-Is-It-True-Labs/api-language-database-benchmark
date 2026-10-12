FROM python:3.13-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install \
    --no-cache-dir \
    -r requirements.txt

COPY main.py .

RUN useradd \
    --system \
    --no-create-home \
    benchmark \
    && chown -R benchmark:benchmark /app

USER benchmark

EXPOSE 8080

ENTRYPOINT ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "1", "--no-access-log"]
