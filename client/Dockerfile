# syntax=docker/dockerfile:1
# ── Stage 1: Build React App ──────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app

# Cache dependencies separately
COPY package.json package-lock.json* ./
RUN npm install --legacy-peer-deps --ignore-scripts

# Copy source and build
COPY . .
ARG REACT_APP_API_URL=http://localhost:5000
ENV REACT_APP_API_URL=$REACT_APP_API_URL
RUN npm run build

# ── Stage 2: Serve with nginx ──────────────────────────────────────
FROM nginx:1.27-alpine AS production

# Create non-root user
RUN addgroup -g 1001 -S nginx-app && \
    adduser  -S nginx-app -u 1001 -G nginx-app

# Copy build artifacts
COPY --from=builder /app/build /usr/share/nginx/html

# Custom nginx config with security headers + SPA routing
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Fix permissions for non-root nginx
RUN chown -R nginx-app:nginx-app /usr/share/nginx/html && \
    chown -R nginx-app:nginx-app /var/cache/nginx && \
    chown -R nginx-app:nginx-app /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown nginx-app:nginx-app /var/run/nginx.pid

USER nginx-app
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
