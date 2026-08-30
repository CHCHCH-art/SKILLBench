FROM node:20-slim
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
COPY registration.json ./
COPY dashboard.html ./
COPY public ./public
COPY .well-known ./.well-known
RUN npm run build
ENV PORT=3000
CMD ["node", "dist/server.js"]
