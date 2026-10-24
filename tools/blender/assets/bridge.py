"""木桥（3 格宽、跨 2 格河 + 两端搭岸）：石砌桥墩 + 横铺木板 + 两侧扶栏与立柱。
原画：testAssets/新风格美术资源0830/战斗/BG.png 的桥；1 米 = 1 格。桥长沿 Blender Y（导出后 = Godot Z = 逻辑 y），宽沿 X。
"""

WOOD = "#b98552"
WOOD_D = "#8a5c34"
WOOD_L = "#d6a56c"
STONE = "#bdb3a0"
STONE_D = "#9c927f"

LENGTH = 3.0   # 河宽 2 + 两端各 0.5 搭岸
WIDTH = 3.0


def build(k):
    b = "root"
    for y in (-1, 1):
        k.box(b, (0, y * (LENGTH * 0.5 - 0.25), 0.12), (WIDTH + 0.3, 0.5, 0.3), STONE_D, bevel=0.25)
        k.box(b, (0, y * (LENGTH * 0.5 - 0.25), 0.28), (WIDTH + 0.1, 0.42, 0.06), STONE, bevel=0.25)
    k.box(b, (0, 0, 0.2), (WIDTH - 0.2, LENGTH - 0.4, 0.08), WOOD_D, bevel=0.15)
    n = 9
    for i in range(n):
        y = -LENGTH * 0.5 + 0.2 + i * (LENGTH - 0.4) / (n - 1)
        k.box(b, (0.03 * ((i % 3) - 1), y, 0.28), (WIDTH - 0.1, 0.28, 0.07), WOOD if i % 2 else WOOD_L, bevel=0.3)
    for x in (-1, 1):
        for y in (-1.1, 0.0, 1.1):
            k.box(b, (x * (WIDTH * 0.5 - 0.1), y, 0.55), (0.14, 0.14, 0.55), WOOD_D, bevel=0.2)
        k.box(b, (x * (WIDTH * 0.5 - 0.1), 0, 0.8), (0.1, LENGTH - 0.5, 0.1), WOOD, bevel=0.25)
        k.box(b, (x * (WIDTH * 0.5 - 0.1), 0, 0.55), (0.06, LENGTH - 0.6, 0.06), WOOD_D, bevel=0.25)
