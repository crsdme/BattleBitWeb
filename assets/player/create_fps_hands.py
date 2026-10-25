"""Blender 3.6+/4.x: generate blocky FPS arms with a seven-bone rig.
Run the entire file in Blender > Scripting > Text > Open > Run Script.
Output: FPS_Hands.glb beside saved .blend, otherwise on Desktop/home.
Camera convention: +X right, +Z up, -Y forward.
"""

import bpy
import os
from mathutils import Vector

COLLECTION_NAME = "GENERATED_FPS_HANDS"

# Remove only our previous generated collection, not user's objects.
old = bpy.data.collections.get(COLLECTION_NAME)
if old:
    for obj in list(old.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(old)

collection = bpy.data.collections.new(COLLECTION_NAME)
bpy.context.scene.collection.children.link(collection)


def move_to_collection(obj):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    collection.objects.link(obj)


def material(name, color):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.85
    return mat

sleeve_mat = material("FPS_Sleeve_Olive", (0.22, 0.27, 0.18))
glove_mat = material("FPS_Glove_Dark", (0.12, 0.12, 0.11))
cuff_mat = material("FPS_Cuff", (0.17, 0.19, 0.15))

# Positions relative to camera (roughly held-rifle pose).
points = {
    "L": {
        "shoulder": (-0.42, -0.20, -0.24),
        "elbow": (-0.35, -0.49, -0.43),
        "wrist": (-0.19, -0.77, -0.32),
        "knuckles": (-0.17, -0.89, -0.31),
    },
    "R": {
        "shoulder": (0.42, -0.20, -0.24),
        "elbow": (0.34, -0.46, -0.36),
        "wrist": (0.22, -0.65, -0.32),
        "knuckles": (0.20, -0.77, -0.31),
    },
}

arm_data = bpy.data.armatures.new("FPS_Hands_Skeleton")
arm = bpy.data.objects.new("FPS_Hands_Rig", arm_data)
collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")


def bone(name, head, tail, parent=None):
    b = arm_data.edit_bones.new(name)
    b.head = head
    b.tail = tail
    if parent:
        b.parent = arm_data.edit_bones[parent]
        b.use_connect = False
    return b

bone("ArmsRoot", (0, 0, 0), (0, -0.12, 0))
for side, p in points.items():
    bone("UpperArm." + side, p["shoulder"], p["elbow"], "ArmsRoot")
    bone("Forearm." + side, p["elbow"], p["wrist"], "UpperArm." + side)
    bone("Hand." + side, p["wrist"], p["knuckles"], "Forearm." + side)

bpy.ops.object.mode_set(mode="OBJECT")
arm.show_in_front = True
arm.display_type = "WIRE"
arm.select_set(False)

meshes = []


def add_segment(name, head, tail, width, depth, bone_name, mat):
    a, b = Vector(head), Vector(tail)
    center = (a + b) * 0.5
    direction = b - a
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj)
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    obj.dimensions = (width, depth, direction.length)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    # 100% weight on corresponding bone. Each part follows its assigned bone.
    vg = obj.vertex_groups.new(name=bone_name)
    vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    modifier = obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = arm
    obj.parent = arm
    meshes.append(obj)
    return obj


for side, p in points.items():
    add_segment("UpperArmMesh." + side, p["shoulder"], p["elbow"],
                0.17, 0.17, "UpperArm." + side, sleeve_mat)
    add_segment("ForearmMesh." + side, p["elbow"], p["wrist"],
                0.145, 0.145, "Forearm." + side, sleeve_mat)
    add_segment("HandMesh." + side, p["wrist"], p["knuckles"],
                0.135, 0.10, "Hand." + side, glove_mat)

# Export only armature and these meshes.
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
for obj in meshes:
    obj.select_set(True)
bpy.context.view_layer.objects.active = arm

if bpy.data.filepath:
    output_dir = os.path.dirname(bpy.data.filepath)
else:
    desktop = os.path.join(os.path.expanduser("~"), "Desktop")
    output_dir = desktop if os.path.isdir(desktop) else os.path.expanduser("~")

output_path = os.path.join(output_dir, "FPS_Hands.glb")
bpy.ops.export_scene.gltf(
    filepath=output_path,
    export_format="GLB",
    use_selection=True,
    export_skins=True,
)
print("FPS hands exported:", output_path)
print("Bones:", [b.name for b in arm.data.bones])
