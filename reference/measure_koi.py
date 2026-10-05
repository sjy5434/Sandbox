#!/usr/bin/env python3
"""
Measures body/fin proportions directly from reference/koi_reference.webp
(a 6-angle koi render: Top/Bottom/Side(Left) on row 1, Front/Rear/Side(Right)
on row 2) instead of guessing them by eye.

Approach:
  1. Threshold every pixel against the flat gray background to get a
     fish-vs-background mask.
  2. Label connected components and pick out the silhouette for the view
     you care about by its bounding box (each of the 6 views ends up as
     its own connected component - sizes/bboxes printed below help you
     find them again if the source image changes).
  3. For the side view, walk column-by-column to get the top/bottom edge
     of the body, which gives you a height-vs-length curve. A rolling
     median or manual inspection separates "body" from "fin poking out
     of the body" (fins show up as a narrow, roughly symmetric bump/dip
     riding on top of the smoother body curve).
  4. For the top view, walk row-by-row (nose to tail) to get the
     width-vs-length curve the same way.

This produced the profile_keys / fin placement fractions / dorsal fin
height used in koi_body_v1.scad. Re-run this (or adapt it) against a new
reference image for a different koi variety (e.g. a butterfly koi) rather
than hand-guessing proportions again.

Requires: pillow, numpy, scipy (pip install --break-system-packages
pillow numpy scipy)
"""
import numpy as np
from PIL import Image
from scipy import ndimage

IMG = "koi_reference.webp"
BG_TOLERANCE = 18  # pixel must differ from the sampled background by more than this (sum of abs RGB diff) to count as "fish"


def load_mask(path):
    im = Image.open(path).convert("RGB")
    a = np.array(im).astype(int)
    bg = a[0, 0]  # corner pixel = background color
    diff = np.abs(a - bg).sum(axis=2)
    return diff > BG_TOLERANCE, a.shape[:2]


def list_components(mask, top_n=12):
    lab, n = ndimage.label(mask)
    sizes = ndimage.sum(mask, lab, range(1, n + 1))
    order = np.argsort(sizes)[::-1]
    print(f"{n} components found; largest {top_n}:")
    for i in order[:top_n]:
        comp = i + 1
        ys, xs = np.where(lab == comp)
        print(
            f"  label {comp}: size={sizes[i]:.0f} "
            f"bbox x[{xs.min()},{xs.max()}] y[{ys.min()},{ys.max()}]"
        )
    return lab


def side_view_profile(lab, label):
    """Column-by-column top/bottom edge of a side-view silhouette."""
    comp = lab == label
    ys, xs = np.where(comp)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    sub = comp[y0 : y1 + 1, x0 : x1 + 1]
    h, w = sub.shape
    top = np.full(w, np.nan)
    bot = np.full(w, np.nan)
    for x in range(w):
        col = np.where(sub[:, x])[0]
        if len(col):
            top[x] = col.min()
            bot[x] = col.max()
    idx = np.arange(w)
    good = ~np.isnan(top)
    top = np.interp(idx, idx[good], top[good])
    good = ~np.isnan(bot)
    bot = np.interp(idx, idx[good], bot[good])
    return top, bot, (x0, x1, y0, y1)


def top_view_profile(lab, label):
    """Row-by-row (nose-to-tail) width of a top-view silhouette."""
    comp = lab == label
    ys, xs = np.where(comp)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    sub = comp[y0 : y1 + 1, x0 : x1 + 1]
    h, w = sub.shape
    left = np.full(h, np.nan)
    right = np.full(h, np.nan)
    for y in range(h):
        row = np.where(sub[y, :])[0]
        if len(row):
            left[y] = row.min()
            right[y] = row.max()
    return left, right, (x0, x1, y0, y1)


if __name__ == "__main__":
    mask, shape = load_mask(IMG)
    print("image shape:", shape)
    lab = list_components(mask)

    # These labels matched koi_reference.webp when this script was written;
    # re-run list_components() and update them if the source image changes.
    SIDE_VIEW_LABEL = 16
    TOP_VIEW_LABEL = 2

    top, bot, bbox = side_view_profile(lab, SIDE_VIEW_LABEL)
    w = bbox[1] - bbox[0]
    print(f"\nSide view bbox={bbox}, width={w}px (note: x=0 end is the HEAD)")
    print("fraction-of-width  depth(px)")
    for frac in np.arange(0, 1.01, 0.05):
        xi = min(int(frac * (w - 1)), w - 1)
        print(f"  {frac:.2f}  {bot[xi]-top[xi]:.0f}")

    left, right, bbox2 = top_view_profile(lab, TOP_VIEW_LABEL)
    h = bbox2[3] - bbox2[1]
    print(f"\nTop view bbox={bbox2}, length={h}px (y=0 end is the HEAD)")
    print("fraction-of-length  width(px)")
    for frac in np.arange(0, 1.01, 0.05):
        yi = min(int(frac * (h - 1)), h - 1)
        print(f"  {frac:.2f}  {right[yi]-left[yi]:.0f}")
