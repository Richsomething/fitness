"""Draws the app icon and writes Assets.xcassets/AppIcon.appiconset: the default image, the dark one and
the tinted one that iOS 18 asks for. Nothing but shapes is used, so the icon carries no outside material.

The mark is an "M" made of one unbroken line, like a pulse or a progress curve, in white to ice blue with
a cobalt glow, on black with a pool of cobalt at the bottom: the colours of the app.

Usage: python3 make_app_icon.py <Assets.xcassets>
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SCALE = 2  # drawn at twice the size and scaled down, for clean edges
COBALT = (42, 92, 255)
COBALT_DEEP = (13, 36, 158)
ICE = (163, 189, 255)
NIGHT = (2, 3, 10)

# The M: left stem up, down to the middle, up again, right stem down.
POINTS = [(262, 742), (262, 296), (512, 604), (762, 296), (762, 742)]
STROKE = 128


def vertical_gradient(top, bottom, size):
    ramp = Image.linear_gradient("L").resize((size, size))
    return Image.composite(Image.new("RGB", (size, size), bottom), Image.new("RGB", (size, size), top), ramp)


def pool(size, color, center, radius, strength):
    """A soft round patch of light: `color` around `center`, fading to nothing well inside `radius`."""
    layer = Image.new("L", (size, size), 0)
    core = radius * 0.55
    ImageDraw.Draw(layer).ellipse((center[0] - core, center[1] - core, center[0] + core, center[1] + core),
                                  fill=int(255 * strength))
    return Image.new("RGB", (size, size), color), layer.filter(ImageFilter.GaussianBlur(radius * 0.3))


def stroke_mask(size, scale):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    points = [(x * scale, y * scale) for x, y in POINTS]
    width = STROKE * scale
    draw.line(points, fill=255, width=width, joint="curve")
    radius = width // 2
    for x, y in (points[0], points[-1]):
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=255)
    return mask


def streaks(size, scale):
    """A few thin diagonal lines of light, the app's light-trail motif, kept low and faint."""
    layer = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(layer)
    for offset, alpha in ((-180, 70), (40, 110), (260, 60)):
        draw.line([(-60 * scale, (880 + offset) * scale), (1100 * scale, (360 + offset) * scale)], fill=alpha, width=3 * scale)
    return layer.filter(ImageFilter.GaussianBlur(2 * scale))


def render(kind):
    size = SIZE * SCALE
    if kind == "tinted":
        base = Image.new("RGB", (size, size), (0, 0, 0))
    else:
        top, bottom = (NIGHT, COBALT_DEEP) if kind == "light" else (NIGHT, (7, 18, 88))
        base = vertical_gradient(top, bottom, size)
        glow_color, glow_layer = pool(size, COBALT, (size // 2, int(size * 0.95)), int(size * 0.62), 0.85 if kind == "light" else 0.55)
        base.paste(glow_color, (0, 0), glow_layer)
        base.paste(Image.new("RGB", (size, size), ICE), (0, 0), streaks(size, SCALE).point(lambda v: int(v * 0.5)))

    mask = stroke_mask(size, SCALE)

    if kind != "tinted":
        # Two glows: a tight one that hugs the line and a wide one that lights the ground around it.
        for radius, alpha in ((22, 0.9), (70, 0.75)):
            halo = mask.filter(ImageFilter.GaussianBlur(radius * SCALE)).point(lambda v, a=alpha: int(v * a))
            base.paste(Image.new("RGB", (size, size), COBALT), (0, 0), halo)

    # The line itself: white at the top running into ice blue at the bottom.
    ink = vertical_gradient((255, 255, 255), ICE, size) if kind != "tinted" else vertical_gradient((255, 255, 255), (200, 200, 200), size)
    base.paste(ink, (0, 0), mask)

    return base.resize((SIZE, SIZE), Image.LANCZOS)


def main(catalog):
    folder = os.path.join(catalog, "AppIcon.appiconset")
    os.makedirs(folder, exist_ok=True)
    files = {"light": "AppIcon.png", "dark": "AppIcon-Dark.png", "tinted": "AppIcon-Tinted.png"}
    for kind, name in files.items():
        render(kind).convert("RGB").save(os.path.join(folder, name), optimize=True)  # no alpha: the store refuses it

    def entry(name, appearance=None):
        item = {"filename": name, "idiom": "universal", "platform": "ios", "size": "1024x1024"}
        if appearance:
            item["appearances"] = [{"appearance": "luminosity", "value": appearance}]
        return item

    contents = {"images": [entry(files["light"]), entry(files["dark"], "dark"), entry(files["tinted"], "tinted")],
                "info": {"author": "xcode", "version": 1}}
    with open(os.path.join(folder, "Contents.json"), "w") as handle:
        json.dump(contents, handle, indent=2)


if __name__ == "__main__":
    main(sys.argv[1])
