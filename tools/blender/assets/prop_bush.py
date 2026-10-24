"""场边点缀·灌木：几团圆绒叶 + 两朵小花。"""

LEAF = "#6cbf5a"
LEAF_D = "#4f9a46"
PETAL = "#ffd0e0"
HEART = "#ffd84d"


def build(k):
    b = "root"
    for x, y, r, c in ((0, 0, 0.42, LEAF), (-0.35, 0.1, 0.3, LEAF_D), (0.35, 0.05, 0.32, LEAF_D), (0.05, -0.25, 0.28, LEAF)):
        k.sphere(b, (x, y, r * 0.8), r, c, scale=(1.0, 1.0, 0.85))
    for x, z in ((-0.12, 0.62), (0.25, 0.5)):
        k.sphere(b, (x, -0.33, z), 0.07, PETAL, scale=(1, 0.5, 1))
        k.sphere(b, (x, -0.36, z), 0.03, HEART)
