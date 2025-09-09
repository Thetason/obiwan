# Obiwan AI Servers – Reproducible Deployment

This document hardens the runtime for CREPE, SPICE, and Formant servers using Docker and version‑pinned Python. Prefer Docker for reproducibility.

## Option A — Docker (recommended)

Prereqs: Docker Desktop 4.x

Commands:
- Build & run: `docker compose up -d --build`
- Check: `curl http://localhost:5002/health` and `http://localhost:5003/health`
- Logs: `docker logs -f obiwan_crepe` / `obiwan_spice` / `obiwan_formant`
- Stop: `docker compose down`

Notes:
- CREPE image warms weights during build; SPICE image warms TF‑Hub during build. Internet is required at build time.
- Health endpoints return `status: healthy|degraded` with a cached self‑test result.

## Option B — Local Python (fallback)

Prereqs: Python 3.10/3.11 recommended.

```bash
python3 -m venv venv && source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
./start_all_servers.sh
```

Troubleshooting:
- macOS SSL cert errors: run “Install Certificates.command” for your Python or `pip install certifi`.
- SPICE cold start: first run downloads TF‑Hub; set `TFHUB_CACHE_DIR` to persist cache.

## Ports
- CREPE: 5002
- SPICE: 5003
- Formant: 5004

