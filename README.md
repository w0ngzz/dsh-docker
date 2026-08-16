# DSH Docker

用于通过 GitHub Actions 构建一个预装 Node.js 和 `@deepseek-ai/dsh` 的 Docker 镜像，然后在 Windows 或 Linux 上部署 DSH Web。

本仓库的目标是把容易受网络影响的镜像构建、APT 安装和 npm 安装全部交给 GitHub Actions，本地部署机器只负责：

```text
GitHub Actions 构建镜像
        ↓
下载 dsh-local-amd64.tar.gz
        ↓
docker load 导入镜像
        ↓
创建 .env
        ↓
docker compose up -d
        ↓
http://localhost:3080
```

## 项目结构

```text
dsh-docker/
├── Dockerfile
├── docker-compose.yml
├── .env.example
├── .gitignore
├── README.md
└── .github/
    └── workflows/
        └── build-image.yml
```

各文件用途：

* `Dockerfile`：定义 Docker 镜像内容，包括 Node.js、DSH、Git、curl、socat 和编译环境。
* `docker-compose.yml`：定义容器如何运行，包括工作目录挂载、端口映射和 DSH 数据持久化。
* `.env.example`：部署环境变量模板。
* `.env`：每台部署机器自己的配置，不提交 GitHub。
* `.github/workflows/build-image.yml`：GitHub Actions 自动构建 Docker 镜像。

---

# 1. 构建镜像

正常情况下不需要在本地执行：

```bash
docker build
```

镜像统一交给 GitHub Actions 构建。

## 手动触发构建

进入 GitHub 仓库：

```text
Actions
→ Build DSH Docker Image
→ Run workflow
```

等待 Workflow 执行完成。

构建流程会：

1. 根据 `Dockerfile` 构建 `dsh-local:latest`
2. 检查 Node.js
3. 检查 DSH
4. 使用 `docker save` 导出镜像
5. gzip 压缩
6. 生成 SHA256 校验文件
7. 上传为 GitHub Actions Artifact

最终生成：

```text
dsh-local-amd64.tar.gz
dsh-local-amd64.tar.gz.sha256
```

Artifact 名称：

```text
dsh-local-amd64
```

---

# 2. 下载镜像

进入成功的 GitHub Actions 运行记录。

页面底部找到：

```text
Artifacts
└── dsh-local-amd64
```

下载后得到一个 ZIP 文件。

解压后：

```text
dsh-local-amd64.tar.gz
dsh-local-amd64.tar.gz.sha256
```

---

# 3. 导入 Docker 镜像

## Windows PowerShell

```powershell
docker load -i .\dsh-local-amd64.tar.gz
```

## Linux

```bash
docker load -i dsh-local-amd64.tar.gz
```

成功后检查：

```bash
docker image ls
```

应该看到：

```text
REPOSITORY    TAG
dsh-local     latest
```

可以进一步测试：

```bash
docker run --rm dsh-local:latest node --version
```

以及：

```bash
docker run --rm dsh-local:latest dsh --help
```

---

# 4. 创建部署配置

部署时需要：

```text
docker-compose.yml
.env
```

可以从模板复制。

## Windows

```powershell
Copy-Item .env.example .env
```

## Linux

```bash
cp .env.example .env
```

然后修改 `.env`。

---

# 5. Windows 部署

假设工作目录为：

```text
D:\dsh
```

`.env`：

```env
DSH_IMAGE=dsh-local:latest
DSH_CONTAINER_NAME=dsh
DSH_PORT=3080
DSH_WORKSPACE=D:/dsh
```

Windows 路径建议使用：

```text
D:/dsh
```

而不是：

```text
D:\dsh
```

启动：

```powershell
cd D:\dsh

docker compose up -d
```

查看容器：

```powershell
docker compose ps
```

查看日志：

```powershell
docker compose logs -f
```

浏览器访问：

```text
http://localhost:3080
```

容器内部：

```text
/workspace
```

对应宿主机：

```text
D:\dsh
```

因此 DSH 在：

```text
/workspace
```

中创建和修改的文件，会直接反映到：

```text
D:\dsh
```

---

# 6. Linux 部署

假设 Linux 工作目录：

```text
/opt/dsh
```

创建目录：

```bash
sudo mkdir -p /opt/dsh
cd /opt/dsh
```

`.env`：

```env
DSH_IMAGE=dsh-local:latest
DSH_CONTAINER_NAME=dsh
DSH_PORT=3080
DSH_WORKSPACE=/opt/dsh
```

启动：

```bash
docker compose up -d
```

查看状态：

```bash
docker compose ps
```

查看日志：

```bash
docker compose logs -f
```

本机浏览器访问：

```text
http://localhost:3080
```

---

# 7. 远程 Linux 服务器访问

当前 Compose 默认只把 DSH Web 绑定到：

```text
127.0.0.1
```

因此不会直接暴露到局域网或公网。

如果 DSH 部署在远程 Linux 服务器，推荐使用 SSH Tunnel。

例如服务器地址：

```text
192.168.1.100
```

在自己的电脑执行：

```bash
ssh -L 3080:127.0.0.1:3080 username@192.168.1.100
```

保持 SSH 会话运行。

然后本地浏览器访问：

```text
http://localhost:3080
```

网络路径：

```text
本地浏览器
    ↓
localhost:3080
    ↓
SSH Tunnel
    ↓
远程 Linux
127.0.0.1:3080
    ↓
Docker
    ↓
DSH Web
```

---

# 8. 数据持久化

当前 Compose 有两类数据。

## 工作目录

```text
${DSH_WORKSPACE} → /workspace
```

用于保存 DSH 实际操作的项目文件。

例如：

```text
Windows:
D:/dsh

Linux:
/opt/dsh
```

## DSH 配置数据

```text
dsh_home → /root/.dsh
```

这是 Docker Named Volume。

执行：

```bash
docker compose down
```

不会删除这个 Volume。

但：

```bash
docker compose down -v
```

会同时删除：

```text
dsh_home
```

所以如果不准备清空 DSH 数据，不要随意使用 `-v`。

---

# 9. 常用命令

启动：

```bash
docker compose up -d
```

停止：

```bash
docker compose stop
```

重启：

```bash
docker compose restart
```

查看状态：

```bash
docker compose ps
```

实时查看日志：

```bash
docker compose logs -f
```

进入容器：

```bash
docker exec -it dsh bash
```

停止并删除容器：

```bash
docker compose down
```

查看 Node.js：

```bash
docker exec -it dsh node --version
```

查看 DSH：

```bash
docker exec -it dsh dsh --help
```

---

# 10. 更新 DSH

当前 Dockerfile 使用：

```dockerfile
RUN npm install -g @deepseek-ai/dsh
```

因此每次 GitHub Actions 重新构建时，会安装当时 npm 上提供的版本。

更新流程：

```text
GitHub Actions
      ↓
重新 Build
      ↓
下载新的 dsh-local-amd64.tar.gz
      ↓
停止旧容器
      ↓
docker load 新镜像
      ↓
重新启动
```

操作：

```bash
docker compose down
```

然后：

```bash
docker load -i dsh-local-amd64.tar.gz
```

再启动：

```bash
docker compose up -d
```

最后检查：

```bash
docker compose logs -f
```

如果未来需要锁定 DSH 版本，可以修改 Dockerfile：

```dockerfile
RUN npm install -g @deepseek-ai/dsh@<版本号>
```

例如：

```dockerfile
RUN npm install -g @deepseek-ai/dsh@0.1.0-rc.6
```

---

# 11. 修改 Web 端口

默认：

```env
DSH_PORT=3080
```

如果本机 `3080` 被占用，可以修改：

```env
DSH_PORT=3088
```

重新创建容器：

```bash
docker compose up -d
```

然后访问：

```text
http://localhost:3088
```

---

# 12. 换机器部署

切换 Windows、Linux 或其他服务器时：

**Dockerfile 和 docker-compose.yml 都不需要修改。**

只需要修改 `.env`。

Windows：

```env
DSH_IMAGE=dsh-local:latest
DSH_CONTAINER_NAME=dsh
DSH_PORT=3080
DSH_WORKSPACE=D:/dsh
```

Linux：

```env
DSH_IMAGE=dsh-local:latest
DSH_CONTAINER_NAME=dsh
DSH_PORT=3080
DSH_WORKSPACE=/opt/dsh
```

然后：

```bash
docker compose up -d
```

即可。

---

# 13. 第一次部署速查

以后忘记操作流程时，直接看这里。

```text
1. GitHub → Actions
2. 运行 Build DSH Docker Image
3. 下载 dsh-local-amd64 Artifact
4. 解压得到 dsh-local-amd64.tar.gz
5. docker load -i dsh-local-amd64.tar.gz
6. 复制 .env.example 为 .env
7. 修改 DSH_WORKSPACE
8. docker compose up -d
9. docker compose logs -f
10. 浏览器访问 http://localhost:3080
```

---

# 14. 更新 DSH 速查

```text
1. GitHub Actions → Run workflow
2. 下载新的镜像 Artifact
3. docker compose down
4. docker load -i dsh-local-amd64.tar.gz
5. docker compose up -d
6. docker compose logs -f
```

---

# 15. Windows 配置速查

`.env`：

```env
DSH_IMAGE=dsh-local:latest
DSH_CONTAINER_NAME=dsh
DSH_PORT=3080
DSH_WORKSPACE=D:/dsh
```

启动：

```powershell
docker compose up -d
```

浏览器：

```text
http://localhost:3080
```

---

# 16. Linux 配置速查

`.env`：

```env
DSH_IMAGE=dsh-local:latest
DSH_CONTAINER_NAME=dsh
DSH_PORT=3080
DSH_WORKSPACE=/opt/dsh
```

启动：

```bash
docker compose up -d
```

---

# 注意事项

* `.env` 不要提交 GitHub。
* `.env.example` 可以提交，用于记录配置模板。
* 本地部署不需要再次运行 `npm install`。
* 本地部署也不需要运行 `npx @deepseek-ai/dsh`。
* DSH 已经在 GitHub Actions 构建镜像时安装完成。
* `docker compose down` 不会删除 DSH 持久化 Volume。
* `docker compose down -v` 会删除持久化 Volume。
* 当前 GitHub Actions 构建的是 Linux AMD64 镜像。
* 适用于常见 Intel/AMD Windows Docker Desktop 和 x86_64 Linux。
* ARM64 设备需要另外构建 ARM64 镜像。
* 当前 Web 服务默认仅绑定宿主机 `127.0.0.1`，远程服务器推荐通过 SSH Tunnel 访问。

---

# 一句话记忆

```text
Dockerfile
= 镜像里面有什么

GitHub Actions
= 谁负责构建镜像

docker-compose.yml
= 容器怎么运行

.env
= 当前这台机器使用什么路径和端口
```
