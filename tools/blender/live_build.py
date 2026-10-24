"""在用户开着的 Blender 里「直播」构建一个资产（经 Blender MCP 调用），让人看到逐个部件拼出来的过程。

  import sys; sys.path.insert(0, r"<repo>/tools/blender"); import live_build
  live_build.run("princess", delay=0.08)

与 build_asset.py 产出完全相同（.blend + GLB）；区别只是每加一个部件就刷新视口，最后循环播放待机动作。
只清理本工具自己建的对象，不碰场景里其他内容以外的数据（会新建一个空场景承载）。
"""
import importlib
import os
import sys
import time

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import toonkit  # noqa: E402


def _view3d():
    for window in bpy.context.window_manager.windows:
        for area in window.screen.areas:
            if area.type == "VIEW_3D":
                return window, area
    return None, None


def _redraw(delay):
    bpy.ops.wm.redraw_timer(type="DRAW_WIN_SWAP", iterations=1)
    if delay > 0:
        time.sleep(delay)


def _setup_view(height):
    window, area = _view3d()
    if area is None:
        return
    space = area.spaces.active
    space.shading.type = "SOLID"
    space.shading.color_type = "VERTEX"
    space.shading.show_object_outline = True
    space.overlay.show_floor = True
    r3d = space.region_3d
    r3d.view_perspective = "PERSP"
    r3d.view_location = (0, 0, height * 0.5)
    r3d.view_distance = max(height, 1.2) * 2.6
    from mathutils import Euler
    r3d.view_rotation = Euler((1.25, 0.0, -0.55)).to_quaternion()


CLIP_NAMES = ("Idle_loop", "Walk_loop", "Attack", "Death")


def _purge_previous():
    """清掉之前直播构建留下的全部数据（LIVE_* 场景及其对象、SK_/RIG_/M_ 网格骨架材质、动作），
    否则同名动作会被改成 .001、导出会混入上一个资产。只动本工具命名空间内的数据。"""
    for sc in [s for s in bpy.data.scenes if s.name.startswith("LIVE_")]:
        for ob in list(sc.objects):
            bpy.data.objects.remove(ob, do_unlink=True)
    for act in list(bpy.data.actions):
        if act.name.split(".")[0] in CLIP_NAMES:
            bpy.data.actions.remove(act)
    for coll, prefixes in ((bpy.data.meshes, ("SK_", "LIVE_")), (bpy.data.armatures, ("RIG_",)),
                           (bpy.data.materials, ("M_",))):
        for item in list(coll):
            if item.name.startswith(prefixes) and item.users == 0:
                coll.remove(item)


def run(asset, delay=0.08, height=1.6):
    """在新场景 LIVE_<asset> 里构建；返回与 build_asset 相同的信息字典。"""
    _purge_previous()
    scene = bpy.data.scenes.get(f"LIVE_{asset}") or bpy.data.scenes.new(f"LIVE_{asset}")
    bpy.context.window.scene = scene
    for sc in [s for s in bpy.data.scenes if s.name.startswith("LIVE_") and s != scene]:
        bpy.data.scenes.remove(sc)
    _setup_view(height)
    preview_mesh = bpy.data.meshes.new(f"LIVE_{asset}")
    preview = bpy.data.objects.new(f"LIVE_{asset}", preview_mesh)
    scene.collection.objects.link(preview)
    _redraw(0.3)

    def on_part(kit):
        kit.bm.to_mesh(preview_mesh)
        preview_mesh.color_attributes.active_color = preview_mesh.color_attributes.get("Col")
        preview_mesh.update()
        _redraw(delay)

    kit = toonkit.Kit(asset, on_part=on_part)
    spec = importlib.util.spec_from_file_location(f"asset_{asset}", os.path.join(HERE, "assets", f"{asset}.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.build(kit)
    bpy.data.objects.remove(preview, do_unlink=True)
    base = os.path.join(ROOT, "assets", "models", asset)
    info = kit.build(os.path.join(base, f"{asset}.glb"), os.path.join(base, "source", f"{asset}.blend"))
    rig = bpy.data.objects.get(f"RIG_{asset}")
    if rig is not None and info["actions"]:
        idle = next((a for a in info["actions"] if a.startswith("Idle")), info["actions"][0])
        rig.animation_data.action = bpy.data.actions[idle]
        act = bpy.data.actions[idle]
        scene.frame_start, scene.frame_end = int(act.frame_range[0]), int(act.frame_range[1])
        window, area = _view3d()
        if area is not None and not bpy.context.screen.is_animation_playing:
            with bpy.context.temp_override(window=window, area=area):
                bpy.ops.screen.animation_play()
    _redraw(0)
    return info


def play(asset, clip):
    """切换正在展示的资产动作（Idle_loop / Walk_loop / Attack / Death）。"""
    rig = bpy.data.objects.get(f"RIG_{asset}")
    act = bpy.data.actions.get(clip) or bpy.data.actions.get(f"{clip}_loop")
    if rig is None or act is None:
        return {"ok": False}
    rig.animation_data.action = act
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = int(act.frame_range[0]), int(act.frame_range[1])
    scene.frame_set(scene.frame_start)
    return {"ok": True, "clip": act.name}
