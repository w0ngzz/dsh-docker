FROM node:24-bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        curl \
        ca-certificates \
        socat \
    && rm -rf /var/lib/apt/lists/*

# 在 GitHub 构建阶段直接安装 DSH
RUN npm install -g @deepseek-ai/dsh \
    && npm cache clean --force

WORKDIR /workspace

CMD ["dsh", "web"]
