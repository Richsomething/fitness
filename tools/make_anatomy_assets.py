"""Turns the owner's anatomy packs (AnatomyMusclePackNoGlow) into app assets and Swift numbers.

Each figure (female/male, front/back) is a 1024 x 1536 RGBA painting plus muscle overlays in the
same frame. The painting is cropped to its content and each overlay to its own; everything is placed
in BodyFigure's 200 x 500 design space, the crown at y 5, the soles at y 499 and the midline at x 100.
Joint hotspots come from the overlays themselves (the centre of a band of a muscle), so they follow
the painting.

Usage: python3 make_anatomy_assets.py <pack root> <Assets.xcassets/Anatomy> > numbers.txt
"""
import json
import os
import sys

from PIL import Image

ROOT = sys.argv[1]
OUT = sys.argv[2]


class Space:
    """Painting pixels to design units for one figure."""

    def __init__(self, alpha: Image.Image) -> None:
        left, top, right, bottom = alpha.point(lambda v: 255 if v > 20 else 0).getbbox()
        self.scale = (bottom - top) / 494
        self.top = top
        self.center = (left + right) / 2

    def x(self, px: float) -> float:
        return round(100 + (px - self.center) / self.scale, 2)

    def y(self, py: float) -> float:
        return round(5 + (py - self.top) / self.scale, 2)

    def rect(self, box: tuple) -> tuple:
        x0, y0, x1, y1 = box
        return (self.x(x0), self.y(y0), round((x1 - x0) / self.scale, 2), round((y1 - y0) / self.scale, 2))


def write_imageset(name: str, image: Image.Image) -> None:
    folder = os.path.join(OUT, f"{name}.imageset")
    os.makedirs(folder, exist_ok=True)
    image.save(os.path.join(folder, f"{name}.png"), optimize=True)
    contents = {"images": [{"filename": f"{name}.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}
    with open(os.path.join(folder, "Contents.json"), "w") as handle:
        json.dump(contents, handle, indent=2)


def padded(box: tuple, margin: int, size: tuple) -> tuple:
    return (max(box[0] - margin, 0), max(box[1] - margin, 0), min(box[2] + margin, size[0]), min(box[3] + margin, size[1]))


def centroid(alpha: Image.Image, box: tuple):
    """Centre of the opaque pixels of `alpha` inside `box`, in painting pixels."""
    region = alpha.crop(box)
    total = sx = sy = 0
    width, height = region.size
    data = region.load()
    for y in range(0, height, 2):
        for x in range(0, width, 2):
            value = data[x, y]
            if value > 60:
                total += value
                sx += value * x
                sy += value * y
    if total == 0:
        return None
    return (box[0] + sx / total, box[1] + sy / total)


def figure(prefix: str, folder: str):
    base = Image.open(os.path.join(folder, "base.png")).convert("RGBA")
    alpha = base.getchannel("A")
    space = Space(alpha)
    crop = padded(alpha.point(lambda v: 255 if v > 2 else 0).getbbox(), 4, base.size)
    write_imageset(prefix, base.crop(crop))
    print(f"{prefix} frame {space.rect(crop)}")
    overlays = {}
    for filename in sorted(os.listdir(os.path.join(folder, "overlays"))):
        if not filename.endswith(".png"):
            continue
        name = filename[3:-4]
        image = Image.open(os.path.join(folder, "overlays", filename)).convert("RGBA")
        box = padded(image.getchannel("A").getbbox(), 2, image.size)
        write_imageset(f"{prefix}-{name}", image.crop(box))
        overlays[name] = (image.getchannel("A"), box)
        print(f"    .{name}: {space.rect(box)}")
    return space, overlays


def joint(space: Space, overlays: dict, name: str, rows: tuple, left: bool = True):
    """Hotspot at the centre of a band of rows of one muscle, on the viewer's left half."""
    alpha, box = overlays[name]
    top = box[1] + (box[3] - box[1]) * rows[0]
    bottom = box[1] + (box[3] - box[1]) * rows[1]
    half = (box[0], int(top), int(space.center), int(bottom)) if left else (box[0], int(top), box[2], int(bottom))
    point = centroid(alpha, half)
    return None if point is None else (space.x(point[0]), space.y(point[1]))


HOTSPOTS = {
    "front": {
        "neck": ("neck-trapezius", (0.3, 0.7), False),
        "shoulders": ("shoulders", (0.2, 0.7), True),
        "elbows": ("forearms", (0.0, 0.15), True),
        "wrists": ("forearms", (0.85, 1.0), True),
        "hips": ("hip-flexors", (0.2, 0.8), False),
        "knees": ("quadriceps", (0.88, 1.0), True),
        "ankles": ("shins", (0.9, 1.0), True),
    },
    "back": {
        "neck": ("neck", (0.4, 0.8), False),
        "upperBack": ("trapezius", (0.25, 0.55), False),
        "lowerBack": ("erector-spinae", (0.6, 0.85), False),
        "shoulders": ("rear-shoulders", (0.2, 0.7), True),
        "elbows": ("forearms", (0.0, 0.15), True),
        "wrists": ("forearms", (0.85, 1.0), True),
        "hips": ("gluteus-maximus", (0.3, 0.7), False),
        "knees": ("hamstrings", (0.9, 1.0), True),
        "ankles": ("achilles-tendons", (0.75, 0.95), True),
    },
}

os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, "Contents.json"), "w") as handle:
    json.dump({"info": {"author": "xcode", "version": 1}}, handle, indent=2)

for gender in ("female", "male"):
    for view in ("front", "back"):
        space, overlays = figure(f"{gender}-{view}", os.path.join(ROOT, gender, view))
        for zone, (muscle, rows, paired) in HOTSPOTS[view].items():
            print(f"    hotspot {zone}: {joint(space, overlays, muscle, rows, left=paired)}")
