FROM node:20.20.2-alpine3.22 AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund

FROM node:20.20.2-alpine3.22 AS test
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY src ./src
COPY test ./test
RUN npm test && npm run lint

FROM node:20.20.2-alpine3.22 AS runtime
ARG APP_VERSION=dev
ARG GIT_SHA=local
LABEL org.opencontainers.image.title="shopapi" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.source="https://github.com/BryanLhomme/Rendu-Cours-Docker"
ENV NODE_ENV=production \
    APP_VERSION=${APP_VERSION}
WORKDIR /app
COPY --from=deps --chown=node:node /app/node_modules ./node_modules
COPY --from=test --chown=node:node /app/package.json ./
COPY --chown=node:node src ./src
# hadolint ignore=DL3066
USER node
EXPOSE 3000
HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=3 \
  CMD ["wget", "-q", "--spider", "http://127.0.0.1:3000/health"]
CMD ["node", "src/server.js"]
