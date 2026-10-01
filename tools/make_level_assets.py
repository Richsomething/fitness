"""Turns the owner's TrainingLevelCharacters pack into app assets: one image per level, cropped to the
character and scaled to 900 px high (enough for a ~230 pt figure at 3x).

Pose frames for a level go in the pack as levels/NN_name.png plus levels/NN_name@pose2.png and so on;
each becomes level-N, level-N-pose2, ... in Assets › Levels.

The female pack goes in with a prefix: level-N becomes female-level-N.

Usage: python3 make_level_assets.py <pack>/levels <Assets.xcassets/Levels> [prefix]
"""
import json
import os
import re
import sys

from PIL import Image

SRC, OUT = sys.argv[1], sys.argv[2]
PREFIX = sys.argv[3] if len(sys.argv) > 3 else ""
HEIGHT = 900

os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, "Contents.json"), "w") as handle:
    json.dump({"info": {"author": "xcode", "version": 1}}, handle, indent=2)

# One shared crop per level keeps every pose of it in the same frame.
files = sorted(f for f in os.listdir(SRC) if f.endswith(".png"))
for filename in files:
    match = re.match(r"(\d+)_[^@]+(?:@(pose\d+))?\.png", filename)
    if not match:
        continue
    level, pose = int(match.group(1)), match.group(2)
    name = f"{PREFIX}level-{level}" + (f"-{pose}" if pose else "")
    image = Image.open(os.path.join(SRC, filename)).convert("RGBA")
    box = image.getchannel("A").point(lambda v: 255 if v > 4 else 0).getbbox()
    # Same framing for all levels: from the top of the frame down to the soles, with a side margin.
    crop = (max(box[0] - 40, 0), 0, min(box[2] + 40, image.width), min(box[3] + 2, image.height))
    cropped = image.crop(crop)
    scaled = cropped.resize((round(cropped.width * HEIGHT / cropped.height), HEIGHT), Image.LANCZOS)
    folder = os.path.join(OUT, f"{name}.imageset")
    os.makedirs(folder, exist_ok=True)
    scaled.save(os.path.join(folder, f"{name}.png"), optimize=True)
    with open(os.path.join(folder, "Contents.json"), "w") as handle:
        json.dump({"images": [{"filename": f"{name}.png", "idiom": "universal"}],
                   "info": {"author": "xcode", "version": 1}}, handle, indent=2)
    print(name, scaled.size)
