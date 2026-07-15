# server/docker — verifier 镜像的构建材料

- `godot-linux.zip` — Godot 4.6.3-stable linux x86_64 官方 zip（**~70MB，不入 git**）。
  `Dockerfile.verifier` 构建时 COPY 进镜像。缺失时下载（走代理）：

  ```bash
  cd server/docker
  HTTPS_PROXY=http://127.0.0.1:7897 curl -sL -o godot-linux.zip \
    "https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_linux.x86_64.zip"
  ```

- `verifier-entrypoint.sh` — 容器启动脚本：把 compose 只读挂载的仓库（`/repo`）中
  重放所需最小集拷到可写 `/work/project` + 预热 Godot 缓存 → 启动 verifier。
  代码/配置更新不用重建镜像，`docker compose restart verifier` 即可。
