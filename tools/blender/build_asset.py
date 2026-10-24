"""构建一个 3D 资产：tools/blender/assets/<id>.py → assets/models/<id>/<id>.glb + source/<id>.blend。

  blender -b --factory-startup --python-exit-code 1 -P tools/blender/build_asset.py -- <id> [--review DIR]

--review：额外用 Workbench 渲染多角度与各动作关键帧 PNG（自检用，不入库）。
输出一行 @@JSON@@{...}：三角面、变形骨数、动作名、尺寸、文件大小。
"""
import importlib.util
import json
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import toonkit  # noqa: E402


def _args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    asset = argv[0]
    review = argv[argv.index("--review") + 1] if "--review" in argv else ""
    return asset, review


def _load(asset):
    path = os.path.join(HERE, "assets", f"{asset}.py")
    spec = importlib.util.spec_from_file_location(f"asset_{asset}", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _clear():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures, bpy.data.actions, bpy.data.cameras,
                 bpy.data.lights):
        for item in list(coll):
            coll.remove(item)


def _review(asset, out_dir, info):
    os.makedirs(out_dir, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "VERTEX"
    shading.show_object_outline = True
    shading.object_outline_color = (0, 0, 0)
    shading.show_shadows = False
    scene.render.resolution_x = 360
    scene.render.resolution_y = 360
    scene.render.film_transparent = False
    scene.world = scene.world or bpy.data.worlds.new("World")
    scene.view_settings.view_transform = "Standard"
    mesh_ob = bpy.data.objects[f"SK_{asset}"]
    arm_ob = bpy.data.objects.get(f"RIG_{asset}")   # 静态资产无骨架
    h = max(info["dims"][2], 0.1)
    w = max(info["dims"][0], info["dims"][1], h)
    cam_data = bpy.data.cameras.new("ReviewCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = w * 1.5
    cam = bpy.data.objects.new("ReviewCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    target = Vector((0, 0, h * 0.5))
    files = []

    def shot(name, yaw_deg, pitch_deg=12.0):
        d = 6.0 * max(w, 1.0)
        yaw, pitch = math.radians(yaw_deg), math.radians(pitch_deg)
        cam.location = target + Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch),
                                        math.sin(pitch))) * d
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out_dir, f"{asset}_{name}.png")
        bpy.ops.render.render(write_still=True)
        files.append(scene.render.filepath)

    if arm_ob is None:
        for name, yaw in (("front", 0), ("q34", -35), ("side", -90), ("back", 180)):
            shot(name, yaw, 30.0)
        return files
    act0 = arm_ob.animation_data.action
    arm_ob.animation_data.action = None
    for pb in arm_ob.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)
    for name, yaw in (("front", 0), ("q34", -35), ("side", -90), ("back", 180)):
        shot(name, yaw)
    for act in bpy.data.actions:
        arm_ob.animation_data.action = act
        lo, hi = act.frame_range
        for i, t in enumerate((0.0, 0.33, 0.66)):
            scene.frame_set(int(lo + (hi - lo) * t))
            shot(f"{act.name}_{i}", -35)
    arm_ob.animation_data.action = act0
    _ = mesh_ob
    return files


def main():
    asset, review = _args()
    _clear()
    kit = toonkit.Kit(asset)
    mod = _load(asset)
    mod.build(kit)
    base = os.path.join(ROOT, "assets", "models", asset)
    info = kit.build(os.path.join(base, f"{asset}.glb"), os.path.join(base, "source", f"{asset}.blend"))
    gdignore = os.path.join(base, "source", ".gdignore")
    if not os.path.exists(gdignore):
        open(gdignore, "w").close()
    if review:
        info["review"] = _review(asset, review, info)
    print("@@JSON@@" + json.dumps(info, ensure_ascii=False), flush=True)


main()
