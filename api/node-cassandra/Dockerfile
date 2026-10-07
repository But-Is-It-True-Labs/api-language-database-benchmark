FROM node:22-alpine

WORKDIR /app

COPY package.json .

RUN npm install \
    --omit=dev \
    --no-audit \
    --no-fund

COPY server.js .

RUN addgroup -S benchmark \
    && adduser -S benchmark -G benchmark \
    && chown -R benchmark:benchmark /app

USER benchmark

EXPOSE 8080

ENTRYPOINT ["node", "server.js"]
