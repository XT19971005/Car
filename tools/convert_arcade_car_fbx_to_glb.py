"""Convert the downloaded Mena FBX car to a self-contained GLB.

Run with Blender in background mode:
  blender.exe --background --python convert_arcade_car_fbx_to_glb.py -- input.fbx output.glb
"""

from __future__ import annotations

import os
import sys

import bpy


def main() -> None:
    try:
        separator = sys.argv.index("--")
    except ValueError as exc:
        raise SystemExit("Missing '-- input.fbx output.glb' arguments") from exc

    args = sys.argv[separator + 1 :]
    if len(args) != 2:
        raise SystemExit("Usage: -- input.fbx output.glb")

    fbx_path = os.path.abspath(args[0])
    glb_path = os.path.abspath(args[1])
    if not os.path.isfile(fbx_path):
        raise SystemExit(f"FBX not found: {fbx_path}")
    os.makedirs(os.path.dirname(glb_path), exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(
        filepath=fbx_path,
        use_image_search=True,
        automatic_bone_orientation=True,
    )

    # The asset is a static car, so remove cameras/lights if the source adds any.
    for obj in list(bpy.context.scene.objects):
        if obj.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(obj, do_unlink=True)

    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0] if bpy.context.selected_objects else None

    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        export_format="GLB",
        export_image_format="AUTO",
        export_materials="EXPORT",
        export_apply=True,
        export_yup=True,
        export_copyright="Mena Assets - ARCADE: Free Racing Car",
    )
    print(f"Wrote GLB: {glb_path}")


if __name__ == "__main__":
    main()
