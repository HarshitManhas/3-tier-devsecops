# syntax=docker/dockerfile:1
# ── Stage 1: Dependencies ────────────────────────────────────────
FROM node:20-alpine AS deps
WORKDIR /app

# Install only production dependencies
COPY package.json package-lock.json* ./
RUN npm install --legacy-peer-deps --ignore-scripts && \
    npm cache clean --force

# ── Stage 2: Production Image ────────────────────────────────────
FROM node:20-alpine AS production

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser  -S nodeapp -u 1001 -G nodejs

WORKDIR /app

# Copy deps from stage 1
COPY --from=deps --chown=nodeapp:nodejs /app/node_modules ./node_modules

# Copy application source
COPY --chown=nodeapp:nodejs . .

# Remove dev files
RUN rm -f .env .env.* && \
    rm -rf tests coverage .git

# Security hardening
USER nodeapp
EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget -qO- http://localhost:5000/health || exit 1

CMD ["node", "app.js"]
