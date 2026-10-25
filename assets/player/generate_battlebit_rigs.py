"""Blender 3.6+/4.x: create two simple blocky rigged GLB models.
Run: blender --background --python generate_battlebit_rigs.py
Or Blender > Scripting > Open > Run Script.
Outputs in directory beside this script (or current .blend folder when pasted).
Does NOT reconstruct Body_29.glb (the provided mesh is collapsed).
"""
import bpy
from pathlib import Path
from mathutils import Vector

OUTPUT = Path(__file__).resolve().parent if '__file__' in globals() else Path(bpy.path.abspath('//'))
OUTPUT.mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1.0)
    m.use_nodes = True
    m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = (*rgb, 1.0)
    return m

cloth = mat('Olive uniform', (0.19, 0.26, 0.19))
vest = mat('Dark tactical vest', (0.12, 0.15, 0.13))
boots = mat('Boots gloves', (0.09, 0.09, 0.08))
skin = mat('Skin', (0.61, 0.43, 0.32))
helmet = mat('Helmet', (0.15, 0.20, 0.15))


def make_rig(name, bone_specs):
    arm_data = bpy.data.armatures.new(name + '_Skeleton')
    arm = bpy.data.objects.new(name + '_Rig', arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for bone_name, head, tail, parent in bone_specs:
        b = arm_data.edit_bones.new(bone_name)
        b.head, b.tail = Vector(head), Vector(tail)
        if parent:
            b.parent = arm_data.edit_bones[parent]
            b.use_connect = False
    bpy.ops.object.mode_set(mode='OBJECT')
    arm.select_set(False)
    arm.show_in_front = True
    return arm


def block(name, center, size, material, rig, bone, point_to=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.name = name
    # Cube dimensions, transformed into the mesh itself for clean exported transforms.
    obj.dimensions = size
    if point_to:
        direction = Vector(point_to[1]) - Vector(point_to[0])
        obj.rotation_euler = direction.to_track_quat('Z', 'Y').to_euler()
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    vg = obj.vertex_groups.new(name=bone)
    vg.add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')
    mod = obj.modifiers.new('Skin', 'ARMATURE')
    mod.object = rig
    obj.parent = rig
    # Parent inverse is identity because model built in armature object coordinates.
    return obj


def segment(name, a, b, width, depth, material, rig, bone):
    mid = (Vector(a) + Vector(b)) * 0.5
    length = (Vector(b) - Vector(a)).length
    return block(name, mid, (width, depth, length), material, rig, bone, (a, b))


def export_rig(rig, filename):
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    for child in rig.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = rig
    path = OUTPUT / filename
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
                              export_yup=True, export_apply=False, export_skins=True)
    print('EXPORTED:', path)
    bpy.ops.object.select_all(action='DESELECT')


# --------------------------------------------------------------
# FULL SOLDIER -- Blender +Z up, faces Blender -Y forward.
# Mesh parts separate but use one Armature and meaningful names.
# --------------------------------------------------------------
full_specs = [
    ('Root', (0,0,0.06), (0,0,0.20), None),
    ('Hips', (0,0,0.90), (0,0,1.04), 'Root'),
    ('Spine', (0,0,1.04), (0,0,1.34), 'Hips'),
    ('Chest', (0,0,1.34), (0,0,1.53), 'Spine'),
    ('Neck', (0,0,1.53), (0,0,1.63), 'Chest'),
    ('Head', (0,0,1.63), (0,0,1.81), 'Neck'),
    ('UpperArm.L', (-0.28,0,1.46), (-0.53,-0.02,1.18), 'Chest'),
    ('Forearm.L', (-0.53,-0.02,1.18), (-0.61,-0.21,1.02), 'UpperArm.L'),
    ('Hand.L', (-0.61,-0.21,1.02), (-0.61,-0.31,0.99), 'Forearm.L'),
    ('UpperArm.R', (0.28,0,1.46), (0.53,-0.02,1.18), 'Chest'),
    ('Forearm.R', (0.53,-0.02,1.18), (0.61,-0.21,1.02), 'UpperArm.R'),
    ('Hand.R', (0.61,-0.21,1.02), (0.61,-0.31,0.99), 'Forearm.R'),
    ('UpperLeg.L', (-0.15,0,0.89), (-0.17,-0.01,0.49), 'Hips'),
    ('LowerLeg.L', (-0.17,-0.01,0.49), (-0.17,-0.02,0.12), 'UpperLeg.L'),
    ('Foot.L', (-0.17,-0.02,0.12), (-0.17,-0.17,0.08), 'LowerLeg.L'),
    ('UpperLeg.R', (0.15,0,0.89), (0.17,-0.01,0.49), 'Hips'),
    ('LowerLeg.R', (0.17,-0.01,0.49), (0.17,-0.02,0.12), 'UpperLeg.R'),
    ('Foot.R', (0.17,-0.02,0.12), (0.17,-0.17,0.08), 'LowerLeg.R'),
]
full = make_rig('Full_Soldier', full_specs)
block('BodyMesh_Hips', (0,0,0.94), (.41,.26,.21), cloth, full, 'Hips')
block('BodyMesh_Torso', (0,0,1.29), (.51,.29,.48), cloth, full, 'Spine')
block('BodyMesh_Vest', (0,-.162,1.31), (.45,.065,.37), vest, full, 'Chest')
block('HeadMesh_Head', (0,0,1.70), (.26,.26,.27), skin, full, 'Head')
block('HeadMesh_Helmet', (0,0,1.83), (.30,.31,.13), helmet, full, 'Head')
for side,s in [('L',-1),('R',1)]:
    x=s
    a=(x*.28,0,1.46); b=(x*.53,-.02,1.18); c=(x*.61,-.21,1.02); d=(x*.61,-.31,.99)
    segment('ArmMesh_Upper_'+side,a,b,.20,.19,cloth,full,'UpperArm.'+side)
    segment('ArmMesh_Forearm_'+side,b,c,.16,.15,cloth,full,'Forearm.'+side)
    segment('ArmMesh_Hand_'+side,c,d,.13,.12,boots,full,'Hand.'+side)
    a=(x*.15,0,.89); b=(x*.17,-.01,.49); c=(x*.17,-.02,.12)
    segment('LegsMesh_Thigh_'+side,a,b,.22,.25,cloth,full,'UpperLeg.'+side)
    segment('LegsMesh_Shin_'+side,b,c,.17,.19,cloth,full,'LowerLeg.'+side)
    block('LegsMesh_Boot_'+side,(x*.17,-.105,.09),(.21,.36,.18),boots,full,'Foot.'+side)
export_rig(full, 'Full_Soldier.glb')

# --------------------------------------------------------------
# FPS HANDS -- origin is at camera; reach out along -Y.
# Only hands/arms; no weapon (weapon is separate asset later).
# --------------------------------------------------------------
fps_specs = [('ArmsRoot',(0,0,0),(0,-.08,0),None)]
for side,s in [('L',-1),('R',1)]:
    shoulder=(s*.32,-.27,-.26)
    elbow=(s*.30,-.50,-.31)
    wrist=(s*.16,-.82,-.28)
    palm=(s*.16,-.91,-.28)
    fps_specs += [
        ('UpperArm.'+side,shoulder,elbow,'ArmsRoot'),
        ('Forearm.'+side,elbow,wrist,'UpperArm.'+side),
        ('Hand.'+side,wrist,palm,'Forearm.'+side),
    ]
fps = make_rig('FPS_Hands', fps_specs)
for side,s in [('L',-1),('R',1)]:
    shoulder=(s*.32,-.27,-.26)
    elbow=(s*.30,-.50,-.31)
    wrist=(s*.16,-.82,-.28)
    palm=(s*.16,-.91,-.28)
    segment('FPS_UpperArm_'+side,shoulder,elbow,.16,.15,cloth,fps,'UpperArm.'+side)
    segment('FPS_Forearm_'+side,elbow,wrist,.14,.13,cloth,fps,'Forearm.'+side)
    segment('FPS_Hand_'+side,wrist,palm,.12,.11,boots,fps,'Hand.'+side)
export_rig(fps, 'FPS_Hands.glb')

print('DONE: Full_Soldier.glb + FPS_Hands.glb')
