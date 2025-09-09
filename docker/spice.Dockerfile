FROM tensorflow/tensorflow:2.14.0

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    TF_CPP_MIN_LOG_LEVEL=2 \
    TFHUB_CACHE_DIR=/root/.cache/tfhub

RUN pip install --no-cache-dir flask==3.0.3 flask-cors==4.0.1 numpy==1.26.4 resampy==0.4.3 tensorflow-hub==0.15.0

WORKDIR /app
COPY spice_server.py /app/spice_server.py

# Pre-warm TF-Hub SPICE model (optional; allowed to fail)
RUN python - <<'PY'
import os
os.makedirs(os.environ.get('TFHUB_CACHE_DIR','/root/.cache/tfhub'), exist_ok=True)
try:
    import tensorflow_hub as hub
    _ = hub.load("https://tfhub.dev/google/spice/2")
    print('SPICE model cached')
except Exception as e:
    print('Warning: SPICE warmup failed:', e)
PY

EXPOSE 5003
CMD ["python", "spice_server.py"]

