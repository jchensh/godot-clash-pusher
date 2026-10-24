"""toonkit —— 卡通战斗角色/建筑的程序化建模工具（Blender 5.2，后台运行）。

约定（与 docs/AGENT_BLENDER_GODOT_WORKFLOW.md 一致）：
- 米制，Z 向上，角色正面朝 Blender -Y（glTF 导出后为 +Z，正是 Godot 侧 presenter 的正面）。
- 原点在脚底中心；所有部件合并成一个网格、一个材质，颜色走顶点色（COLOR_0），Godot 侧统一套 toon 着色。
- 每个部件刚性绑定到一根骨骼（权重 1.0，单一影响），保持卡通分块体积；不做软蒙皮。
- 骨骼一律竖直向上（head→tail = +Z，roll 0），关节枢轴放在 head。关键帧的 rot/loc 用**世界轴**书写
  （x=左右轴俯仰、y=前后轴侧倾、z=竖轴转身，单位度），写入时换算到骨骼局部轴。
- 带 tag="team" 的部件放第二个材质槽 M_Team，Godot 侧按阵营染色（塔的旗帜/屋顶）。
- 动作：一个片段一个 Action，循环片段命名 `<Clip>_loop`（Godot 导入识别为循环并去掉后缀）。

用法见 tools/blender/build_asset.py；每个资产一个 tools/blender/assets/<id>.py，暴露 build(k)。
"""
import math
import os

import bmesh
import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

FPS = 30


def rgb(hex_color):
    """'#rrggbb' → 线性空间 RGBA（顶点色以线性存储，glTF COLOR_0 亦为线性）。"""
    h = hex_color.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    return (lin[0], lin[1], lin[2], 1.0)


class Kit:
    """一个资产的构建上下文：部件 → 单网格 + 骨架 + 动作。"""

    def __init__(self, name, on_part=None):
        self.name = name
        self.on_part = on_part   # 直播模式：每加一个部件回调一次（live_build 刷新视口）
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new("Col")
        self.deform = self.bm.verts.layers.deform.verify()
        self.bones = {}          # name -> dict(head, tail, parent)
        self.bone_order = []
        self.clips = []          # [(name, frames, loop, keys)]
        self.tagged = {}         # 部件分组标签（如 team）→ 面集合，供导出拆分
        self.bone("root", (0, 0, 0), 0.25, None, deform=False)

    # ── 骨骼 ───────────────────────────────────────────────
    def bone(self, name, head, length=0.2, parent="root", deform=True):
        h = Vector(head)
        self.bones[name] = {"head": h, "tail": h + Vector((0, 0, length)), "parent": parent, "deform": deform}
        self.bone_order.append(name)
        return name

    def _group(self, bone):
        return self.bone_order.index(bone)

    # ── 部件 ───────────────────────────────────────────────
    def _new(self, before):
        return [v for v in self.bm.verts if v not in before]

    def _finish(self, verts, bone, color, loc, rot, scale, smooth=True, tag=None):
        m = Matrix.LocRotScale(Vector(loc), Euler([math.radians(a) for a in rot]).to_quaternion(),
                               Vector(scale if not isinstance(scale, (int, float)) else (scale,) * 3))
        bmesh.ops.transform(self.bm, matrix=m, verts=verts)
        faces = {f for v in verts for f in v.link_faces}
        c = rgb(color) if isinstance(color, str) else color
        gi = self._group(bone)
        for v in verts:
            v[self.deform].clear()
            v[self.deform][gi] = 1.0
        for f in faces:
            f.smooth = smooth
            for lp in f.loops:
                lp[self.col] = c
        if tag:
            self.tagged.setdefault(tag, set()).update(faces)
            if tag == "team":
                for f in faces:
                    f.material_index = 1
        if self.on_part is not None:
            self.on_part(self)
        return faces

    def sphere(self, bone, loc, radius, color, scale=(1, 1, 1), rot=(0, 0, 0), seg=None, rings=None, tag=None):
        """球/椭球。分段数缺省按「最大半径」自适应（小零件少面，控三角面预算）。"""
        big = radius * (max(scale) if not isinstance(scale, (int, float)) else scale)
        seg = seg or max(8, min(18, int(8 + big * 26)))
        rings = rings or max(5, int(seg * 0.6))
        before = set(self.bm.verts)
        bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=rings, radius=1.0)
        s = Vector(scale) * radius if not isinstance(scale, (int, float)) else Vector((scale,) * 3) * radius
        return self._finish(self._new(before), bone, color, loc, rot, s, tag=tag)

    def cyl(self, bone, loc, r1, r2, depth, color, rot=(0, 0, 0), seg=14, smooth=True, scale=(1, 1, 1), tag=None):
        """圆柱/圆台（沿局部 Z，中心在 loc）。r2=0 为圆锥。"""
        before = set(self.bm.verts)
        bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg,
                              radius1=r1, radius2=max(r2, 0.0), depth=depth)
        return self._finish(self._new(before), bone, color, loc, rot, scale, smooth=smooth, tag=tag)

    def box(self, bone, loc, size, color, rot=(0, 0, 0), bevel=0.25, seg=2, tag=None):
        """圆角盒：size 为全尺寸；bevel 为相对最短边的倒角比例。"""
        before = set(self.bm.verts)
        r = bmesh.ops.create_cube(self.bm, size=1.0)
        bmesh.ops.scale(self.bm, vec=Vector(size), verts=r["verts"])
        if bevel > 0:
            edges = list({e for v in r["verts"] for e in v.link_edges})
            bmesh.ops.bevel(self.bm, geom=r["verts"] + edges, offset=min(size) * bevel * 0.5, segments=seg,
                            affect="EDGES", profile=0.5, clamp_overlap=True)
        return self._finish(self._new(before), bone, color, loc, rot, (1, 1, 1), smooth=bevel > 0, tag=tag)

    def torus(self, bone, loc, major, minor, color, rot=(0, 0, 0), seg=18, ring=8, scale=(1, 1, 1), tag=None):
        verts = []
        grid = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            row = []
            for j in range(ring):
                b = 2 * math.pi * j / ring
                p = Vector(((major + minor * math.cos(b)) * math.cos(a),
                            (major + minor * math.cos(b)) * math.sin(a), minor * math.sin(b)))
                v = self.bm.verts.new(p)
                row.append(v)
                verts.append(v)
            grid.append(row)
        for i in range(seg):
            for j in range(ring):
                a, b = grid[i][j], grid[(i + 1) % seg][j]
                c, d = grid[(i + 1) % seg][(j + 1) % ring], grid[i][(j + 1) % ring]
                self.bm.faces.new((a, b, c, d))
        return self._finish(verts, bone, color, loc, rot, scale, tag=tag)

    def tube(self, bone, points, radius, color, seg=8, tag=None, end_radius=None):
        """沿折线的细管（弓弦、法杖、触角）：每段一个圆柱。"""
        faces = set()
        pts = [Vector(p) for p in points]
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            d = b - a
            rr = radius if end_radius is None else radius + (end_radius - radius) * (i + 0.5) / (len(pts) - 1)
            q = Vector((0, 0, 1)).rotation_difference(d.normalized())
            before = set(self.bm.verts)
            bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg,
                                  radius1=rr, radius2=rr, depth=d.length)
            verts = self._new(before)
            m = Matrix.LocRotScale((a + b) * 0.5, q, Vector((1, 1, 1)))
            bmesh.ops.transform(self.bm, matrix=m, verts=verts)
            faces |= self._finish(verts, bone, color, (0, 0, 0), (0, 0, 0), (1, 1, 1), tag=tag)
        return faces

    def wing(self, bone, root, span, chord, color, side=1, thick=0.04, droop=0.0, rot=(0, 0, 0), tag=None):
        """扁平翅膀（圆角四边形片，带厚度），根部在 root、向 ±X 展开。"""
        before = set(self.bm.verts)
        bmesh.ops.create_cube(self.bm, size=1.0)
        verts = self._new(before)
        bmesh.ops.scale(self.bm, vec=Vector((span, chord, thick)), verts=verts)
        bmesh.ops.translate(self.bm, vec=Vector((side * span * 0.5, 0, 0)), verts=verts)
        for v in verts:   # 末端收窄、下垂
            t = abs(v.co.x) / span
            v.co.y *= 1.0 - 0.45 * t
            v.co.z -= droop * t
        return self._finish(verts, bone, color, root, rot, (1, 1, 1), smooth=False, tag=tag)

    # ── 动作 ───────────────────────────────────────────────
    def clip(self, name, frames, loop):
        keys = {}
        self.clips.append((name, frames, loop, keys))
        return Clip(keys, frames, loop)

    # ── 生成 ───────────────────────────────────────────────
    def build(self, out_glb, out_blend):
        mesh = bpy.data.meshes.new(f"SK_{self.name}")
        self.bm.to_mesh(mesh)
        tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
        self.bm.free()
        mesh_ob = bpy.data.objects.new(f"SK_{self.name}", mesh)
        bpy.context.scene.collection.objects.link(mesh_ob)
        for b in self.bone_order:
            mesh_ob.vertex_groups.new(name=b)
        mat = bpy.data.materials.new(f"M_{self.name}")
        nt = mat.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        attr = nt.nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Col"
        nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.9
        mesh.materials.append(mat)
        if "team" in self.tagged:
            team = bpy.data.materials.new("M_Team")
            tb = next(n for n in team.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            ta = team.node_tree.nodes.new("ShaderNodeVertexColor")
            ta.layer_name = "Col"
            team.node_tree.links.new(ta.outputs["Color"], tb.inputs["Base Color"])
            mesh.materials.append(team)
        mesh.color_attributes.active_color = mesh.color_attributes["Col"]

        if not self.clips:   # 静态资产（塔/废墟/地形件）：只导网格，无骨架
            return self._export_static(mesh_ob, out_glb, out_blend, tris)

        arm = bpy.data.armatures.new(f"RIG_{self.name}")
        arm_ob = bpy.data.objects.new(f"RIG_{self.name}", arm)
        bpy.context.scene.collection.objects.link(arm_ob)
        bpy.context.view_layer.objects.active = arm_ob
        bpy.ops.object.mode_set(mode="EDIT")
        for b in self.bone_order:
            spec = self.bones[b]
            eb = arm.edit_bones.new(b)
            eb.head = spec["head"]
            eb.tail = spec["tail"]
            eb.use_deform = spec["deform"]
        for b in self.bone_order:
            if self.bones[b]["parent"]:
                arm.edit_bones[b].parent = arm.edit_bones[self.bones[b]["parent"]]
        bpy.ops.object.mode_set(mode="OBJECT")
        mesh_ob.parent = arm_ob
        mod = mesh_ob.modifiers.new("Armature", "ARMATURE")
        mod.object = arm_ob

        arm_ob.animation_data_create()
        for pb in arm_ob.pose.bones:
            pb.rotation_mode = "QUATERNION"
        actions = []
        for name, frames, loop, keys in self.clips:
            want = f"{name}_loop" if loop else name
            act = bpy.data.actions.new(want)
            if act.name != want:   # 同名动作残留（直播模式多次构建）会被改名 .001 → 导出名错，必须先清场
                raise RuntimeError(f"action name clash: {act.name} (expected {want})")
            act.use_fake_user = True
            arm_ob.animation_data.action = act
            _apply_keys(arm_ob, keys, frames, loop)
            actions.append(act.name)
        bpy.context.scene.render.fps = FPS
        bpy.context.scene.frame_start = 0
        if actions:
            arm_ob.animation_data.action = bpy.data.actions[actions[0]]

        self._save_blend(out_blend, actions)
        os.makedirs(os.path.dirname(out_glb), exist_ok=True)
        for ob in bpy.context.scene.objects:
            ob.select_set(ob in (mesh_ob, arm_ob))
        kw = dict(filepath=out_glb, use_selection=True, use_active_scene=True, export_format="GLB", export_yup=True,
                  export_apply=True, export_animations=True, export_animation_mode="ACTIONS",
                  export_skins=True, export_def_bones=True, export_influence_nb=4, export_morph=False,
                  export_materials="EXPORT", export_cameras=False, export_lights=False,
                  export_force_sampling=True, export_frame_range=False)
        props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
        if "export_vertex_color" in props:   # 5.2：按名字导出顶点色 → glTF COLOR_0（ACTIVE 在后台模式下不生效）
            kw["export_vertex_color"] = "NAME"
            kw["export_vertex_color_name"] = "Col"
        res = bpy.ops.export_scene.gltf(**kw)
        deform = [b for b in self.bone_order if self.bones[b]["deform"]]
        return {"ok": res == {"FINISHED"} and os.path.exists(out_glb), "glb": out_glb,
                "kb": round(os.path.getsize(out_glb) / 1024, 1) if os.path.exists(out_glb) else 0,
                "tris": tris, "deform_bones": len(deform), "actions": actions,
                "dims": [round(d, 3) for d in mesh_ob.dimensions]}


    def _save_blend(self, out_blend, actions):
        """后台构建：整份保存。直播模式（用户开着的 Blender）：只把本资产场景与动作写出，不改用户当前文件。"""
        os.makedirs(os.path.dirname(out_blend), exist_ok=True)
        if self.on_part is None:
            bpy.ops.wm.save_as_mainfile(filepath=out_blend)
            return
        blocks = {bpy.context.scene} | {bpy.data.actions[a] for a in actions}
        bpy.data.libraries.write(out_blend, blocks, path_remap="RELATIVE_ALL", fake_user=True)

    def _export_static(self, mesh_ob, out_glb, out_blend, tris):
        for vg in list(mesh_ob.vertex_groups):
            mesh_ob.vertex_groups.remove(vg)
        self._save_blend(out_blend, [])
        os.makedirs(os.path.dirname(out_glb), exist_ok=True)
        for ob in bpy.context.scene.objects:
            ob.select_set(ob == mesh_ob)
        res = bpy.ops.export_scene.gltf(filepath=out_glb, use_selection=True, use_active_scene=True, export_format="GLB",
                                        export_yup=True, export_apply=True, export_animations=False,
                                        export_skins=False, export_materials="EXPORT", export_cameras=False,
                                        export_lights=False, export_vertex_color="NAME",
                                        export_vertex_color_name="Col")
        return {"ok": res == {"FINISHED"} and os.path.exists(out_glb), "glb": out_glb,
                "kb": round(os.path.getsize(out_glb) / 1024, 1) if os.path.exists(out_glb) else 0,
                "tris": tris, "deform_bones": 0, "actions": [], "materials": len(mesh_ob.data.materials),
                "dims": [round(d, 3) for d in mesh_ob.dimensions]}


class Clip:
    """一个动作片段的关键帧收集器：key(帧, 骨骼, rot=(x,y,z)度, loc=(x,y,z), scale=s)。"""

    def __init__(self, keys, frames, loop):
        self.keys = keys
        self.frames = frames
        self.loop = loop

    def key(self, frame, bone, rot=None, loc=None, scale=None):
        k = self.keys.setdefault(bone, {}).setdefault(int(frame), {})
        if rot is not None:
            k["rot"] = rot
        if loc is not None:
            k["loc"] = loc
        if scale is not None:
            k["scale"] = scale if isinstance(scale, (tuple, list)) else (scale, scale, scale)
        return self

    def wave(self, bone, channel, axis, amp, period=None, phase=0.0, base=None, samples=8, offset=0.0):
        """正弦循环（呼吸/扇翅/摆动）：在 [0, frames] 采样，首尾闭合。"""
        period = period or self.frames
        for i in range(samples + 1):
            f = self.frames * i / samples
            v = list(base or (0.0, 0.0, 0.0))
            v[axis] += offset + amp * math.sin(2 * math.pi * (f / period) + phase)
            self.key(round(f), bone, **{channel: tuple(v)})
        return self


def _local_rot(rot):
    """世界轴欧拉（度）→ 竖直骨骼局部轴：局部 X=世界 X，局部 Y=世界 Z，局部 Z=世界 -Y。"""
    rx, ry, rz = rot
    return Euler((math.radians(rx), math.radians(rz), math.radians(-ry)), "XZY").to_quaternion()


def _local_loc(loc):
    x, y, z = loc
    return Vector((x, z, -y))


def _apply_keys(arm_ob, keys, frames, loop):
    """把收集到的关键帧写入当前 Action；未出现的骨骼在首尾帧补静止姿态，防止片段间串姿态。"""
    scene = bpy.context.scene
    for pb in arm_ob.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
        pb.scale = Vector((1, 1, 1))
    for pb in arm_ob.pose.bones:
        bk = keys.get(pb.name, {})
        frames_set = sorted(set(bk.keys()) | {0, frames})
        state = {"rot": (0, 0, 0), "loc": (0, 0, 0), "scale": (1, 1, 1)}
        for f in frames_set:
            k = bk.get(f, {})
            if f == frames and loop and f not in bk and 0 in bk:
                k = bk[0]
            for ch in ("rot", "loc", "scale"):
                if ch in k:
                    state[ch] = k[ch]
            scene.frame_set(f)
            pb.rotation_quaternion = _local_rot(state["rot"])
            pb.location = _local_loc(state["loc"])
            sx, sy, sz = state["scale"]
            pb.scale = Vector((sx, sz, sy))
            pb.keyframe_insert("rotation_quaternion", frame=f)
            pb.keyframe_insert("location", frame=f)
            pb.keyframe_insert("scale", frame=f)
