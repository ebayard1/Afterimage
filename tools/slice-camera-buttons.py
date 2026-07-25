#!/usr/bin/env python3
"""Round 2: inpaint the green placeholders out of the shell, re-slice the
buttons with zero margin (disc fills the canvas exactly), and rebuild the
lamp overlay with feathered edges so the crop seam disappears."""
from PIL import Image
import numpy as np
from scipy import ndimage
import os

SHEET = '/Users/ethanbayard/Downloads/button-contact-sheet-last-column-reversed-preview.png'
SHELL_OFF = '/Users/ethanbayard/Downloads/camera-ui-original-based-red-light-off-fixed-text.png'
SHELL_ON = '/Users/ethanbayard/Downloads/camera-ui-original-based-red-light-on-fixed-text.png'
OUT = os.path.expanduser('~/Desktop/Afterimage/art-sliced')
ASSETS = os.path.expanduser('~/Desktop/Afterimage/afterimage/afterimage/Assets.xcassets')

# ---------- 1. Shell: inpaint the green discs ----------
off = np.asarray(Image.open(SHELL_OFF).convert('RGBA'))
r, g, b = off[..., 0].astype(int), off[..., 1].astype(int), off[..., 2].astype(int)
green = (g > r + 25) & (g > b + 25)
green = ndimage.binary_dilation(green, iterations=4)   # swallow the AA fringe
# nearest-neighbor inpaint: every green pixel takes the nearest non-green pixel
_, (iy, ix) = ndimage.distance_transform_edt(green, return_indices=True)
filled = off.copy()
filled[green] = off[iy[green], ix[green]]
Image.fromarray(filled).save(f'{OUT}/CameraShell-inpainted.png')
print('shell inpainted:', int(green.sum()), 'px filled')

# ---------- 2. Buttons: re-slice with ZERO margin ----------
sheet = np.asarray(Image.open(SHEET).convert('RGBA')).astype(float)
H, W = sheet.shape[:2]
CELL_W, CELL_H = W // 3, H // 4

FRAMES = {
    'FlipRest': (0, 0), 'FlipPressed': (0, 1),
    'FlashOnRest': (1, 0), 'FlashOnPressed': (1, 1),
    'FlashOffPressed': (1, 2), 'FlashOffRest': (1, 3),
    'ShutterRest': (2, 0), 'ShutterPressed': (2, 1),
    'RecordPressed': (2, 2), 'RecordRest': (2, 3),
}

def fit_circle(cell):
    rr, gg, bb = cell[..., 0], cell[..., 1], cell[..., 2]
    lum = 0.299 * rr + 0.587 * gg + 0.114 * bb
    dark = lum < 110
    lab, n = ndimage.label(dark)
    sizes = ndimage.sum(dark, lab, range(1, n + 1))
    blob = lab == (int(np.argmax(sizes)) + 1)
    ys, xs = np.nonzero(blob)
    y_top = ys.min()
    widths = {}
    for y in range(y_top, ys.max() + 1):
        row = np.nonzero(blob[y])[0]
        if len(row):
            widths[y] = (row.min(), row.max())
    maxw_y = max(widths, key=lambda y: widths[y][1] - widths[y][0])
    x0, x1 = widths[maxw_y]
    radius = (x1 - x0 + 1) / 2
    return (x0 + x1) / 2, y_top + radius, radius

def checker_tones(img):
    corner = img[:40, :40, :3].reshape(-1, 3)
    uniq, counts = np.unique(np.round(corner / 8) * 8, axis=0, return_counts=True)
    return uniq[np.argsort(-counts)][:2]

tones = checker_tones(sheet)
for name, (col, row) in FRAMES.items():
    cell = sheet[row * CELL_H:(row + 1) * CELL_H, col * CELL_W:(col + 1) * CELL_W]
    cx, cy, rad = fit_circle(cell)
    # ZERO margin: crop box is the disc's bounding box exactly
    x0, x1 = int(round(cx - rad)), int(round(cx + rad))
    y0, y1 = int(round(cy - rad)), int(round(cy + rad))
    crop = cell[y0:y1, x0:x1].copy()
    ch, cw = crop.shape[:2]
    yy, xx = np.mgrid[0:ch, 0:cw]
    dist = np.sqrt((xx - (cx - x0)) ** 2 + (yy - (cy - y0)) ** 2)
    # feather INWARD: opaque to r-2, fades out exactly at r
    alpha = np.clip((rad - dist) / 2.0, 0, 1)
    rgb = crop[..., :3]
    is_checker = np.zeros((ch, cw), bool)
    for t in tones:
        is_checker |= (np.abs(rgb - t).max(axis=-1) < 14)
    alpha[(dist > rad - 6) & is_checker] = 0
    crop[..., 3] = alpha * 255
    Image.fromarray(crop.astype(np.uint8)).save(f'{OUT}/{name}.png')
    print(f'{name:16s} r={rad:5.1f} -> {cw}x{ch} (disc fills canvas)')

# ---------- 3. Lamp overlay with feathered edges ----------
on = np.asarray(Image.open(SHELL_ON).convert('RGBA')).astype(int)
offi = np.asarray(Image.open(SHELL_OFF).convert('RGBA')).astype(int)
diff = np.abs(offi[..., :3] - on[..., :3]).max(axis=-1) > 8
ys, xs = np.nonzero(diff)
PAD = 22
x0 = max(0, xs.min() - PAD); x1 = min(on.shape[1] - 1, xs.max() + PAD)
y0 = max(0, ys.min() - PAD); y1 = min(on.shape[0] - 1, ys.max() + PAD)
lamp = on[y0:y1 + 1, x0:x1 + 1].astype(np.uint8).copy()
lh, lw = lamp.shape[:2]
F = 16.0   # feather width
yy, xx = np.mgrid[0:lh, 0:lw].astype(float)
edge = np.ones((lh, lw))
if x0 > 0:                edge = np.minimum(edge, xx / F)
if x1 < on.shape[1] - 1:  edge = np.minimum(edge, (lw - 1 - xx) / F)
if y0 > 0:                edge = np.minimum(edge, yy / F)
if y1 < on.shape[0] - 1:  edge = np.minimum(edge, (lh - 1 - yy) / F)
lamp[..., 3] = (np.clip(edge, 0, 1) * 255).astype(np.uint8)
Image.fromarray(lamp).save(f'{OUT}/RecLampOn.png')
print(f'RecLampOn rect: x={x0} y={y0} w={x1-x0+1} h={y1-y0+1} (feather {int(F)}px)')

# ---------- 4. Install into the asset catalog ----------
import shutil
shutil.copy(f'{OUT}/CameraShell-inpainted.png', f'{ASSETS}/CameraShell.imageset/CameraShell.png')
for name in list(FRAMES) + ['RecLampOn']:
    shutil.copy(f'{OUT}/{name}.png', f'{ASSETS}/{name}.imageset/{name}.png')
print('assets installed')
