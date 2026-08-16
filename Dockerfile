FROM node:24-bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        curl \
        ca-certificates \
        socat \
        python3 \
        build-essential \
    && rm -rf /var/lib/apt/lists/*

# 在镜像构建阶段安装 DSH
RUN npm install -g @deepseek-ai/dsh \
    && npm cache clean --force

WORKDIR /workspace

CMD ["dsh", "web"]
