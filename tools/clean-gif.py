"""Clean Clawd's GIFs: remove the light halo and the colour noise.

The original GIFs were resampled over a light background: the silhouette
has a 1-2 px light outline, boundaries between colours have in-between
shades, and the body has several near-identical oranges. Per frame:

  1. Body shades snap to exactly BODY, or SHADE where they are darker
     (side shading).
  2. Light lines: a thin-line pixel that is a neighbour's colour mixed with
     white (the old background) takes that neighbour's colour.
  3. Edges: Clawd has no outline, so the outer 1-2 px ring takes the colour
     just inside it. Thin details (lens rims, tools) have no inside and are
     left alone.

Shapes, frames, timing and transparency are otherwise kept.

Usage: uv run --with numpy --with pillow python -I tools/clean-gif.py IN.gif OUT.gif
"""

import sys

import numpy as np
from PIL import Image, ImageSequence

BODY = np.array([201, 113, 89], dtype=float)
WHITE = np.array([255.0, 255.0, 255.0])
SHADE = BODY * 0.935  # the body's side shade, same hue
BODY_SNAP = 38.0     # shades this close to BODY are body (or its shade)
SHADE_STEP = 6.0     # this much darker than BODY counts as shade
SAME = 14.0          # colour distance that still counts as the same colour
THIN = 4             # fewer same-colour neighbours than this = thin line
BLEND_GAP = 40.0     # a colour must differ this much from white to blend
BLEND_FIT = 16.0     # max distance of a blend from the line between them
LIGHTER = 12.0       # luminance step that marks a halo pixel
NEIGHBOURS = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
CROSS = [(-1, 0), (1, 0), (0, -1), (0, 1)]


def shifted(a, dy, dx, fill):
    out = np.full_like(a, fill)
    h, w = a.shape[:2]
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    out[yd, xd] = a[ys, xs]
    return out


def luminance(c):
    return c[..., 0] * 0.299 + c[..., 1] * 0.587 + c[..., 2] * 0.114


def neighbours(rgb, opaque):
    return ([shifted(rgb, dy, dx, 0.0) for dy, dx in NEIGHBOURS],
            [shifted(opaque, dy, dx, False) for dy, dx in NEIGHBOURS])


def same_count(rgb, opaque, nb_rgb, nb_op):
    count = np.zeros(opaque.shape, dtype=int)
    for c, o in zip(nb_rgb, nb_op):
        count += o & (np.linalg.norm(c - rgb, axis=-1) <= SAME)
    return count


def fix_blends(rgb, opaque):
    nb_rgb, nb_op = neighbours(rgb, opaque)
    thin = opaque & (same_count(rgb, opaque, nb_rgb, nb_op) < THIN)
    fixed = 0
    for y, x in zip(*np.nonzero(thin)):
        p = rgb[y, x]
        colours = [nb_rgb[k][y, x] for k in range(8) if nb_op[k][y, x]]
        best, best_fit = None, BLEND_FIT
        for a in colours:
            for b in [WHITE]:
                span = b - a
                gap = np.linalg.norm(span)
                if gap < BLEND_GAP:
                    continue
                t = float(np.dot(p - a, span) / (gap * gap))
                if not 0.08 < t < 0.92:
                    continue
                fit = np.linalg.norm(p - (a + t * span))
                if fit < best_fit:
                    best_fit = fit
                    best = a
        if best is not None:
            rgb[y, x] = best
            fixed += 1
    return fixed


def ring(opaque):
    edge = np.zeros_like(opaque)
    for dy, dx in CROSS:
        edge |= ~shifted(opaque, dy, dx, False)
    return edge & opaque


def inside_colour(rgb, outer, inner):
    """For each pixel of `outer`, the most common colour among its `inner` neighbours."""
    votes = {}
    for dy, dx in NEIGHBOURS:
        c = shifted(rgb, dy, dx, 0.0)
        ok = outer & shifted(inner, dy, dx, False)
        for y, x in zip(*np.nonzero(ok)):
            votes.setdefault((y, x), []).append(tuple(c[y, x]))
    return {k: np.array(max(set(v), key=v.count)) for k, v in votes.items()}


def repaint_edges(rgb, opaque):
    """Clawd has no outline: the outer ring takes the colour just inside it.

    The halo can be 2 px, so the second ring is fixed first (only where it is
    lighter than the solid colour behind it), then the outer ring follows the
    second. Thin details have no inside and keep their colour.
    """
    ring1 = ring(opaque)
    ring2 = ring(opaque & ~ring1)
    core = opaque & ~ring1 & ~ring2
    fixed = 0
    for (y, x), c in inside_colour(rgb, ring2, core).items():
        if luminance(rgb[y, x]) > luminance(c) + LIGHTER:
            rgb[y, x] = c
            fixed += 1
    for (y, x), c in inside_colour(rgb, ring1, ring2 | core).items():
        if np.linalg.norm(rgb[y, x] - c) > SAME:
            rgb[y, x] = c
            fixed += 1
    return fixed


def clean(rgba):
    rgb = rgba[..., :3].astype(float)
    opaque = rgba[..., 3] > 127
    # Body shades: two tones, so side shading (3D look) survives.
    near = opaque & (np.linalg.norm(rgb - BODY, axis=-1) <= BODY_SNAP)
    darker = luminance(rgb) < luminance(BODY) - SHADE_STEP
    rgb[near & ~darker] = BODY
    rgb[near & darker] = SHADE
    counts = [fix_blends(rgb, opaque), fix_blends(rgb, opaque), repaint_edges(rgb, opaque)]
    out = np.zeros_like(rgba)
    out[opaque, :3] = np.clip(np.rint(rgb[opaque]), 0, 255).astype(np.uint8)
    out[opaque, 3] = 255
    return out, counts


def main(src, dst):
    im = Image.open(src)
    frames, durations = [], []
    totals = np.zeros(3, dtype=int)
    for frame in ImageSequence.Iterator(im):
        durations.append(frame.info.get("duration", im.info.get("duration", 100)))
        out, counts = clean(np.array(frame.convert("RGBA")))
        totals += counts
        frames.append(Image.fromarray(out, "RGBA"))
    frames[0].save(dst, save_all=True, append_images=frames[1:], duration=durations,
                   loop=im.info.get("loop", 0), disposal=2, optimize=False)
    print(f"{src.split('/')[-1]}: {len(frames)} frames, blends {totals[0] + totals[1]}, "
          f"edges {totals[2]}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
