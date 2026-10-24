"""场边点缀·木栅栏段：2 米长，三根尖头木桩 + 两道横杆；沿场地外缘首尾相接摆放。长度沿 Blender X。"""

WOOD = "#c08a52"
WOOD_D = "#8a5c34"


def build(k):
    b = "root"
    for x in (-0.9, 0.0, 0.9):
        k.box(b, (x, 0, 0.35), (0.16, 0.16, 0.7), WOOD, bevel=0.2)
        k.cyl(b, (x, 0, 0.78), 0.11, 0.0, 0.16, WOOD, rot=(0, 0, 45), seg=4, smooth=False)
    for z in (0.25, 0.52):
        k.box(b, (0, -0.02, z), (2.0, 0.07, 0.1), WOOD_D, bevel=0.25)
