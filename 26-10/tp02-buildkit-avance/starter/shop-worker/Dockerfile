# syntax=docker/dockerfile:1
FROM python:3.12.16-slim-bookworm AS builder
ARG TARGETARCH
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1
WORKDIR /app
RUN python -m venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH
COPY requirements.txt ./
RUN --mount=type=secret,id=pipconf,target=/etc/pip.conf \
    --mount=type=cache,target=/root/.cache/pip,id=pip-${TARGETARCH} \
    pip install -r requirements.txt

FROM builder AS test
ARG TARGETARCH
COPY requirements-dev.txt ./
RUN --mount=type=secret,id=pipconf,target=/etc/pip.conf \
    --mount=type=cache,target=/root/.cache/pip,id=pip-${TARGETARCH} \
    pip install -r requirements-dev.txt
COPY worker ./worker
COPY tests ./tests
RUN ruff check worker tests && python -m pytest -q

FROM python:3.12.16-slim-bookworm AS runtime
ARG VERSION=dev
ARG GIT_SHA=local
LABEL org.opencontainers.image.title="shop-worker" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.source="https://github.com/BryanLhomme/Rendu-Cours-Docker"
ENV PATH=/opt/venv/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin worker
WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
COPY worker ./worker
USER 10001
EXPOSE 9100
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:9100/metrics', timeout=2)"]
CMD ["python", "-m", "worker.main"]
