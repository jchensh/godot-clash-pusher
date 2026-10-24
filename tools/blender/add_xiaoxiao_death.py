"""给已验收的小小（Codex 手工资产）补 Death 片段并重新导出 GLB；不改动原有 Idle/Walk/Attack 与网格。

  blender -b assets/models/xiaoxiao/source/xiaoxiao_animated.blend --python-exit-code 1 -P tools/blender/add_xiaoxiao_death.py

骨骼与 toonkit 同约定（竖直、roll 0），关键帧用世界轴书写。只导出 RIG_Xiaoxiao + SK_Xiaoxiao。
"""
import json
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import toonkit  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
GLB = os.path.join(ROOT, "assets", "models", "xiaoxiao", "xiaoxiao_animated.glb")


def main():
    rig = bpy.data.objects["RIG_Xiaoxiao"]
    mesh = bpy.data.objects["SK_Xiaoxiao"]
    old = bpy.data.actions.get("Death")
    if old is not None:
        bpy.data.actions.remove(old)
    keys = {}
    clip = toonkit.Clip(keys, 18, False)
    clip.key(0, "body", rot=(0, 0, 0), loc=(0, 0, 0))
    clip.key(5, "body", rot=(-10, 0, 0), loc=(0, 0.05, 0.12))
    clip.key(18, "body", rot=(-8, 78, 0), loc=(0.55, 0, -0.75))
    for side, sgn in (("L", 1), ("R", -1)):
        clip.key(0, f"upper_arm.{side}", rot=(0, 0, 0))
        clip.key(5, f"upper_arm.{side}", rot=(-35, 0, 0))
        clip.key(18, f"upper_arm.{side}", rot=(25, sgn * 30, 0))
        clip.key(18, f"leg.{side}", rot=(0, 40, 0), loc=(0.35, 0, 0.05))
    clip.key(0, "sprout", rot=(0, 0, 0)).key(8, "sprout", rot=(-25, 0, 0)).key(18, "sprout", rot=(35, 20, 0))
    act = bpy.data.actions.new("Death")
    act.use_fake_user = True
    rig.animation_data.action = act
    toonkit._apply_keys(rig, keys, 18, False)
    rig.animation_data.action = bpy.data.actions["Idle_loop"]
    bpy.ops.wm.save_mainfile()

    color = mesh.data.color_attributes.active_color.name if mesh.data.color_attributes.active_color else ""
    for ob in bpy.context.scene.objects:
        ob.select_set(ob in (rig, mesh))
    kw = dict(filepath=GLB, use_selection=True, use_active_scene=True, export_format="GLB", export_yup=True,
              export_apply=True, export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
              export_def_bones=True, export_influence_nb=4, export_morph=False, export_materials="EXPORT",
              export_cameras=False, export_lights=False, export_force_sampling=True, export_frame_range=False)
    if color:
        kw["export_vertex_color"] = "NAME"
        kw["export_vertex_color_name"] = color
    res = bpy.ops.export_scene.gltf(**kw)
    print("@@JSON@@" + json.dumps({"ok": res == {"FINISHED"}, "color": color,
                                   "actions": sorted(a.name for a in bpy.data.actions)}), flush=True)


main()
