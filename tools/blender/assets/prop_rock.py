"""场边点缀·石块：一大两小的圆角石堆，带一撮苔藓。"""

STONE = "#b7b0a2"
STONE_D = "#958d7f"
MOSS = "#7fbf5c"


def build(k):
    b = "root"
    k.box(b, (0, 0, 0.3), (0.9, 0.75, 0.6), STONE, rot=(0, 0, 18), bevel=0.45, seg=3)
    k.box(b, (0.55, -0.25, 0.16), (0.4, 0.38, 0.32), STONE_D, rot=(8, 0, -20), bevel=0.45, seg=3)
    k.box(b, (-0.5, 0.2, 0.12), (0.32, 0.3, 0.24), STONE_D, rot=(0, 10, 40), bevel=0.45, seg=3)
    k.sphere(b, (0.05, 0.05, 0.6), 0.22, MOSS, scale=(1.3, 1.1, 0.35))
