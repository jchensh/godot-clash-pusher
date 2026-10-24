"""锤锤莱姆（mini_pekka_body）：绿色史莱姆戴紫色尖刺头盔，右手大锤、左手小圆盾；攻击是过顶砸锤。
原画：testAssets/新风格美术资源0830/动作/锤锤莱姆/锤锤莱姆.png；头盔背面为补全设计。
"""
import slimes

GREEN = "#7cd36a"
GREEN_D = "#58a94c"
HELM = "#8f5fb8"
HELM_D = "#6a4290"
SPIKE = "#d9cfe6"
IRON = "#7d858e"
WOOD = "#8b5a2b"


def build(k):
    k.bone("body", (0, 0, 0.05), 0.4)
    k.bone("hammer", (-0.45, -0.08, 0.3), 0.15, "body")
    k.bone("shield", (0.45, -0.08, 0.3), 0.15, "body")
    slimes.blob(k, 0.4, GREEN, GREEN_D, height=0.85, face_z=0.3)
    # 紫色尖刺头盔：圆顶 + 帽檐 + 一圈尖刺
    k.sphere("body", (0, 0.02, 0.45), 0.36, HELM, scale=(1.12, 1.08, 0.62))
    k.torus("body", (0, 0.02, 0.4), 0.38, 0.04, HELM_D, seg=18, ring=5, scale=(1.05, 1.0, 1.0))
    for x, y in ((0, 0.0), (0.2, 0.05), (-0.2, 0.05), (0.1, 0.25), (-0.1, 0.25), (0.0, -0.2)):
        k.cyl("body", (x, y, 0.7), 0.05, 0.0, 0.14, SPIKE, seg=5, smooth=False)
    # 大锤（右）
    k.tube("hammer", [(-0.46, -0.1, 0.15), (-0.46, -0.1, 0.8)], 0.03, WOOD)
    k.box("hammer", (-0.46, -0.1, 0.86), (0.26, 0.17, 0.17), IRON, bevel=0.25)
    # 小圆盾（左）
    k.cyl("shield", (0.46, -0.13, 0.32), 0.18, 0.18, 0.05, WOOD, rot=(90, 0, 25), seg=14)
    k.torus("shield", (0.46, -0.13, 0.32), 0.17, 0.02, IRON, rot=(90, 0, 25), seg=16, ring=4)
    k.sphere("shield", (0.45, -0.165, 0.32), 0.045, IRON)
    slimes.anims(k, weapon="hammer", shield="shield", strike=-110.0)
