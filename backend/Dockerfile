FROM node:22-alpine

ENV NODE_ENV=production
WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY src ./src
COPY data ./data

EXPOSE 3000
CMD ["node", "src/server.js"]
