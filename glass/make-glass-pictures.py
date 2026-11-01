"""Draws the pictures for two of the Claude Glass looks:

  droplet.png  misty glass with drip streaks and water droplets      (/glass droplet)
  winter.png   winter window at dusk: blurred lights, melt streaks, hanging drops,
               droplets and fern frost along the edges                (/glass winter)

Run:  python make-frost-texture.py [output folder]
Needs Pillow and numpy. The result is random but repeatable (fixed seeds).
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 1600, 1000


def smooth_noise(rng, scale, octaves=4):
    """Soft cloudy noise in 0..1."""
    out = np.zeros((H, W), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        cells = scale * (2 ** o)
        small = rng.random((max(2, H // cells), max(2, W // cells))).astype(np.float32)
        img = Image.fromarray((small * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)
        out += amp * (np.asarray(img, np.float32) / 255)
        total += amp
        amp *= 0.5
    return out / total


def edge_weight(power=1.6):
    """0 in the middle of the window, 1 at the edges and corners."""
    xx = np.abs(np.linspace(-1, 1, W, dtype=np.float32))[None, :]
    yy = np.abs(np.linspace(-1, 1, H, dtype=np.float32))[:, None]
    return np.clip(np.maximum(xx, yy) ** power + 0.35 * (xx * yy), 0, 1)


def rgba(rgb, alpha):
    out = np.zeros((H, W, 4), np.float32)
    for i in range(3):
        out[..., i] = rgb[i]
    out[..., 3] = np.clip(alpha, 0, 1) * 255
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def condensation():
    rng = np.random.default_rng(7)
    # 1. Mist: light grey, thicker toward the top, cloudy, never fully solid
    yy = np.linspace(0, 1, H, dtype=np.float32)[:, None]
    haze = 0.30 + 0.22 * smooth_noise(rng, 160) + 0.12 * (1 - yy)
    haze = np.clip(haze, 0, 1) * np.ones((1, W), np.float32)

    # 2. Drip streaks: wobbly vertical channels wiped clear of mist
    clear = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(clear)
    for _ in range(70):
        x = rng.uniform(0, W)
        y0, y1 = rng.uniform(-0.1, 0.55) * H, rng.uniform(0.75, 1.1) * H
        width = rng.uniform(3, 16)
        pts, y = [], y0
        while y < y1:
            pts.append((x, y))
            x += rng.normal(0, 1.4)
            y += rng.uniform(6, 14)
        d.line(pts, fill=int(rng.uniform(150, 235)), width=int(width), joint="curve")
        r = width * rng.uniform(0.8, 1.3)
        d.ellipse((pts[-1][0] - r, pts[-1][1] - r, pts[-1][0] + r, pts[-1][1] + r), fill=235)
    clear = np.asarray(clear.filter(ImageFilter.GaussianBlur(2.2)), np.float32) / 255
    alpha = haze * (1 - 0.85 * clear)

    # 3. Droplets: clear the mist inside, soft rim, small glint
    drops = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(drops)
    holes = Image.new("L", (W, H), 0)
    hd = ImageDraw.Draw(holes)
    density = smooth_noise(rng, 220, 2)
    count = 0
    while count < 5200:
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        if rng.random() > 0.35 + 0.65 * density[int(y), int(x)] * (0.5 + 0.5 * y / H):
            continue
        count += 1
        r = float(np.clip(rng.lognormal(0.9, 0.55), 1.0, 11.0))
        hd.ellipse((x - r, y - r, x + r, y + r), fill=166)
        dd.ellipse((x - r, y - r, x + r, y + r), outline=(30, 36, 46, 85), width=max(1, int(r / 4)))
        g = max(1.0, r * 0.35)
        gx, gy = x - r * 0.35, y - r * 0.4
        dd.ellipse((gx - g, gy - g, gx + g, gy + g), fill=(255, 255, 255, 200))
    drops = drops.filter(ImageFilter.GaussianBlur(0.7))
    alpha *= 1 - np.asarray(holes.filter(ImageFilter.GaussianBlur(0.8)), np.float32) / 255

    mist = rgba((0.86 * 225, 0.86 * 232, 0.86 * 240), alpha).filter(ImageFilter.GaussianBlur(1.2))
    return Image.alpha_composite(mist, drops)


def ice():
    """The winter look: a winter window at dusk. Soft blue blurred lights behind the glass,
    one warm glow, thin melt streaks with hanging drops, scattered droplets, and
    fern frost along the left, right and bottom edges. A finished picture, kept a
    deep blue so Claude's text stays readable on it."""
    rng = np.random.default_rng(23)
    xx = np.linspace(0, 1, W, dtype=np.float32)[None, :]
    yy = np.linspace(0, 1, H, dtype=np.float32)[:, None]

    # 1. Behind the glass: deep blue with big soft blurred lights, darker low down
    top, low = np.array([46, 66, 92], np.float32), np.array([26, 40, 60], np.float32)
    sky = top * (1 - yy[..., None]) + low * yy[..., None] + np.zeros((H, W, 3), np.float32)
    behind = Image.fromarray(sky.astype(np.uint8), "RGB").convert("RGBA")
    lights = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lights)
    for _ in range(55):
        x, y, r = rng.uniform(0, W), rng.uniform(0, H * 0.85), rng.uniform(40, 150)
        c = rng.uniform(0, 1)
        ld.ellipse((x - r, y - r, x + r, y + r),
                   fill=(int(70 + 40 * c), int(95 + 40 * c), int(125 + 35 * c), int(rng.uniform(50, 110))))
    for x, y, r, a in ((0.82, 0.33, 120, 120), (0.86, 0.45, 70, 90)):      # the warm glow
        ld.ellipse((x * W - r, y * H - r, x * W + r, y * H + r), fill=(205, 165, 125, a))
    behind = Image.alpha_composite(behind, lights.filter(ImageFilter.GaussianBlur(45)))

    # 2. The glass itself: a faint frosted grain
    grain = (rng.random((H, W)).astype(np.float32) - 0.5) * 18
    arr = np.asarray(behind, np.float32).copy()
    arr[..., :3] = np.clip(arr[..., :3] + grain[..., None], 0, 255)
    arr[..., 3] = 0.93 * 255
    glass = Image.fromarray(arr.astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(0.6))

    water = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wd = ImageDraw.Draw(water)

    def drop(x, y, r, hang):
        """A water drop: lighter inside, dark rim low down, bright glint up top.
        hang > 0 stretches it into a teardrop hanging from a streak."""
        if hang:
            wd.polygon([(x - r, y), (x, y - r * hang), (x + r, y)], fill=(150, 175, 200, 90))
        wd.ellipse((x - r, y - r, x + r, y + r), fill=(150, 175, 200, 90))
        wd.arc((x - r, y - r, x + r, y + r), 20, 160, fill=(12, 20, 32, 170), width=max(1, int(r / 3)))
        g = max(0.8, r * 0.3)
        wd.ellipse((x - r * 0.35 - g, y - r * 0.35 - g, x - r * 0.35 + g, y - r * 0.35 + g),
                   fill=(245, 250, 255, 230))

    # 3. Melt streaks: thin wavy lines running down, most ending in a hanging drop
    for _ in range(26):
        x = rng.uniform(0.05, 0.95) * W
        y0 = rng.uniform(-0.05, 0.3) * H
        y1 = y0 + rng.uniform(0.15, 0.85) * H
        pts, y = [], y0
        while y < y1:
            pts.append((x, y))
            x += rng.normal(0, 0.5)
            y += 6
        wd.line(pts, fill=(150, 178, 205, 55), width=4)
        wd.line([(px - 1.2, py) for px, py in pts], fill=(225, 238, 248, 85), width=1)
        if rng.random() < 0.75:
            drop(pts[-1][0], pts[-1][1] + 6, rng.uniform(5.5, 9), 2.3)

    # 4. Scattered droplets, more toward the top
    count = 0
    while count < 900:
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        if rng.random() > 1 - 0.6 * (y / H):
            continue
        count += 1
        r = float(np.clip(rng.lognormal(0.7, 0.5), 0.8, 7))
        drop(x, y, r, 1.4 if r > 3.5 and rng.random() < 0.4 else 0)
    water = water.filter(ImageFilter.GaussianBlur(0.5))

    # 5. Fern frost along the left, right and bottom edges (thin at the bottom,
    #    where the prompt and status line are)
    def frost_weight(x, y):
        left, right, bottom = 1 - x / (0.04 * W), 1 - (W - x) / (0.09 * W), 1 - (H - y) / (0.07 * H)
        return max(0.0, left, right, bottom * 0.75)

    frost = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    fd = ImageDraw.Draw(frost)

    def fern(x, y, ang, length, depth, alpha):
        step = 2.4
        steps = max(2, int(length / step))
        bend = rng.normal(0, 0.02)
        for s in range(steps):
            nx, ny = x + math.cos(ang) * step, y + math.sin(ang) * step
            fd.line((x, y, nx, ny), fill=(232, 243, 250, alpha), width=1)
            if depth < 2 and s > 0:
                side_len = length * (0.42 if depth == 0 else 0.5) * (1 - s / steps) ** 1.1
                if side_len > 3:
                    for side in (1, -1):
                        if rng.random() < 0.85:
                            fern(nx, ny, ang + side * math.radians(rng.uniform(55, 65)),
                                 side_len * rng.uniform(0.6, 1.0), depth + 1, int(alpha * 0.8))
            ang += bend
            x, y = nx, ny

    made = 0
    while made < 260:
        x, y = rng.uniform(-20, W + 20), rng.uniform(-20, H + 20)
        w = frost_weight(x, y)
        if w <= 0 or rng.random() > w:
            continue
        made += 1
        if (H - y) / H < 0.07 and 0.04 * W < x < 0.91 * W:
            ang = -math.pi / 2 + rng.normal(0, 0.5)                    # bottom: grow upward
        else:
            ang = (0 if x < W / 2 else math.pi) + rng.normal(0, 0.6)   # sides: grow inward
        reach = 0.5 if x < 0.1 * W else 1.0                          # short on the left, where lines start
        fern(x, y, ang, rng.uniform(25, 85) * (0.6 + 0.6 * w) * reach, 0, int(150 + 90 * w))

    edge = np.zeros((H, W), np.float32)
    edge = np.maximum(edge, np.clip(1 - xx / 0.035, 0, 1))
    edge = np.maximum(edge, np.clip(1 - (1 - xx) / 0.08, 0, 1))
    edge = np.maximum(edge, np.clip(1 - (1 - yy) / 0.05, 0, 1) * 0.6)
    haze = rgba((210, 228, 240), edge ** 1.4 * 0.55).filter(ImageFilter.GaussianBlur(18))
    glow = frost.filter(ImageFilter.GaussianBlur(2.5))

    out = glass
    for layer in (haze, water, glow, frost.filter(ImageFilter.GaussianBlur(0.3))):
        out = Image.alpha_composite(out, layer)
    return out


if __name__ == "__main__":
    folder = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
    for name, make in (("droplet.png", condensation), ("winter.png", ice)):
        path = os.path.join(folder, name)
        make().save(path, optimize=True)
        print(f"saved {path} ({W}x{H})")
