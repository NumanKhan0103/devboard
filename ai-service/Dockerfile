FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# curl/ca-certificates come from the trusted base distro; no version pin needed.
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

# Run as a non-root user. The DHI base images used by backend/ and frontend/
# do this for us; python:3.12-slim does not, so we do it by hand.
RUN useradd --uid 10001 --create-home --shell /usr/sbin/nologin appuser \
    && chown -R appuser:appuser /app
USER appuser

EXPOSE 3005

HEALTHCHECK --interval=10s --timeout=3s --retries=5 \
    CMD curl -fsS http://localhost:3005/health || exit 1

# `opentelemetry-instrument` is THE zero-code line.
#
# It reads the OTEL_* environment variables (set in k8s/ai-service-deployment.yml
# and the Helm chart), installs every instrumentation package it can find that
# matches an imported library, and then execs gunicorn. Flask and httpx are
# patched before app/main.py is ever imported — which is why that file contains
# no OpenTelemetry code at all.
#
# The same three signals cost ~60 lines of explicit SDK wiring in
# backend/tracing.go. Neither is better; chapter 12 is about the trade-off.
#
# --threads 32, not 8: gthread holds one worker thread for the ENTIRE duration
# of a response, and an SSE stream from a CPU-bound model can run for minutes.
# With 8 threads the 9th concurrent user finds no free slot — at which point
# /health stops answering, kubelet declares the pod dead, and every in-flight
# stream on it dies. A classroom of twenty people clicking "Ask" makes that
# certain, not hypothetical. Threads are cheap here because they are almost
# always blocked on network I/O rather than burning CPU.
CMD ["opentelemetry-instrument", \
     "gunicorn", "--bind", "0.0.0.0:3005", "--workers", "1", "--threads", "32", \
     "--timeout", "600", "--access-logfile", "-", "--error-logfile", "-", "app.main:app"]
