# Build stage
FROM node:20-slim AS builder
WORKDIR /app
COPY relay/package*.json ./
RUN npm install
COPY relay/ .
RUN npm run build

# Production stage
FROM node:20-slim
WORKDIR /app
COPY relay/package*.json ./
RUN npm install --omit=dev
COPY --from=builder /app/dist ./dist

# Railway uses the PORT env var for the primary service
EXPOSE 3000
EXPOSE 12346

CMD ["node", "dist/index.js"]
