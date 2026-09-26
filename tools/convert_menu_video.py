# Converts the menu video (MP4) to Ogg Theora (.ogv), the format Godot's VideoStreamPlayer plays,
# and saves the first frame as a still (shown instantly and as a fallback if video can't play).
# Usage:
#   blender -b --factory-startup --python tools/convert_menu_video.py -- "path/to/IdleMenu_Animation_FullFrame.mp4"
import bpy, os, sys

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sys.argv[sys.argv.index("--") + 1]
OUT_DIR = os.path.join(PROJECT, "assets", "title")
os.makedirs(OUT_DIR, exist_ok=True)

clip = bpy.data.movieclips.load(SRC)
w, h = clip.size
scene = bpy.context.scene
scene.sequence_editor_create()
ed = scene.sequence_editor
strips = ed.strips if hasattr(ed, "strips") else ed.sequences
strip = strips.new_movie("menu", SRC, 1, 1)
scene.frame_start = 1
scene.frame_end = strip.frame_final_duration
scene.render.fps = int(round(clip.fps))
scene.render.resolution_x = w
scene.render.resolution_y = h
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = "Standard"

# First frame as a PNG still.
scene.render.image_settings.file_format = "PNG"
scene.frame_set(1)
scene.render.filepath = os.path.join(OUT_DIR, "menu_still.png")
bpy.ops.render.render(write_still=True)
print("STILL", scene.render.filepath)

# Whole clip as Ogg Theora.
if hasattr(scene.render.image_settings, "media_type"):
    scene.render.image_settings.media_type = "VIDEO"
scene.render.image_settings.file_format = "FFMPEG"
ff = scene.render.ffmpeg
ff.format = "OGG"
ff.codec = "THEORA"
ff.constant_rate_factor = "NONE"
ff.video_bitrate = 3500
ff.maxrate = 5000
ff.gopsize = 30
ff.audio_codec = "NONE"
scene.render.filepath = os.path.join(OUT_DIR, "menu_video.ogv")
scene.render.use_file_extension = False
bpy.ops.render.render(animation=True)
print("VIDEO", scene.render.filepath, w, h, scene.frame_end, "frames @", scene.render.fps)
