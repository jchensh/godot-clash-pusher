"""场边点缀·树：棕色树干 + 三团叠起的圆冠（卡通蘑菇云状），约 2.4 米高。只放在场地外圈，不影响逻辑。"""

TRUNK = "#8a5c34"
LEAF = "#6cbf5a"
LEAF_D = "#4f9a46"
LEAF_L = "#8fd673"


def build(k):
    b = "root"
    k.cyl(b, (0, 0, 0.5), 0.16, 0.12, 1.0, TRUNK, seg=10)
    k.sphere(b, (0, 0, 1.45), 0.72, LEAF, scale=(1.0, 1.0, 0.85))
    k.sphere(b, (-0.38, 0.1, 1.25), 0.45, LEAF_D)
    k.sphere(b, (0.4, -0.05, 1.3), 0.42, LEAF_D)
    k.sphere(b, (0.05, -0.2, 1.9), 0.42, LEAF_L)
