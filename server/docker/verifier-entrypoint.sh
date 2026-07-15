#!/bin/sh
# KAN-79 verifier 启动：把只读挂载的仓库（/repo）里 pve_verify 需要的最小集拷到
# 可写 /work/project（Godot 首跑要建 res://.godot/ 缓存），预热一次后启动 verifier。
# 最小集 = 工程入口 + 纯脚本 + 配置（assets/sound 不需要：重放不开场景、音频缺失静默跳过）。
set -e

mkdir -p /work/project
for d in logic config tools view ai addons; do
    rm -rf "/work/project/$d"
    cp -r "/repo/$d" "/work/project/$d"
done
cp /repo/project.godot /work/project/project.godot
cp /repo/icon.svg /work/project/icon.svg 2>/dev/null || true

# 预热：headless editor 跑一遍生成 .godot/（global_script_class_cache.cfg 等）——
# class_name 类型注解（Tower 等）的解析依赖它，普通 --quit 不生成。失败不阻塞
# （verifier 对每局重放独立判 error）。HOME 指向可写目录。
HOME=/tmp /usr/local/bin/godot --headless --editor --path /work/project --quit > /dev/null 2>&1 || true
echo "verifier-entrypoint: project staged at /work/project (class cache warmed), starting verifier"

exec /usr/local/bin/verifier
