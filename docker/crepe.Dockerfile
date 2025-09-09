FROM python:3.10-slim

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    TF_CPP_MIN_LOG_LEVEL=2 \
    TFHUB_CACHE_DIR=/root/.cache/tfhub \
    CREPE_CACHE_DIR=/root/.cache/crepe

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libsndfile1 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt /app/requirements.txt

# Pin versions known-good with Python 3.10
RUN pip install --upgrade pip \
    && pip install \
       flask==3.0.3 flask-cors==4.0.1 numpy==1.26.4 resampy==0.4.3 \
       scipy==1.10.1 crepe==0.0.12

COPY crepe_server.py /app/crepe_server.py

# Pre-warm CREPE weights into cache (optional; allowed to fail without breaking build)
RUN python - <<'PY'
import os, numpy as np
os.makedirs(os.environ.get('CREPE_CACHE_DIR','/root/.cache/crepe'), exist_ok=True)
try:
    import crepe
    _ = crepe.predict(np.zeros(16000, dtype=np.float32), 16000, viterbi=False, verbose=0)
    print('CREPE weights cached')
except Exception as e:
    print('Warning: CREPE warmup failed:', e)
PY

EXPOSE 5002
CMD ["python", "crepe_server.py"]

