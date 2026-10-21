#!/usr/bin/env python3
"""
Membuat semua aset merek Horas dari SATU gambar master (PNG, latar krem polos).

Hasil:
  assets/images/horas_logo.png        logo lengkap (bubble + tulisan), latar transparan
  assets/images/horas_logo_dark.png   sama, tulisan diwarnai terang untuk mode gelap
  assets/images/horas_mark.png        hanya bubble bermotif, latar transparan
  android/.../mipmap-*/ic_launcher.png               ikon (Android < 8)
  android/.../mipmap-*/ic_launcher_foreground.png    ikon adaptif (Android 8+)
  android/.../mipmap-*/ic_launcher_monochrome.png    ikon bertema (Android 13+)
  android/.../mipmap-anydpi-v26/ic_launcher.xml, values/ic_launcher_background.xml
  web/icons/*.png dan web/favicon.png

Pemakaian (dari folder proyek):
    pip install pillow numpy scipy
    python tools/make_brand_assets.py --source path/ke/logo_master.png

Latar dihapus dengan flood-fill dari tepi gambar, sehingga motif krem di DALAM
bubble tetap utuh, sedangkan lubang huruf (o, a) ikut transparan.
"""
import argparse
import os

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

Image.MAX_IMAGE_PIXELS = None

WORK = 2875          # resolusi kerja (master 5750 px diperkecil setengah)
BG_THRESHOLD = 36    # jarak warna ke latar untuk dianggap "latar"
ERODE = 2            # px: buang pinggiran campuran warna agar tanpa halo
DARK_WORDMARK = (232, 165, 156)   # = warna primer mode gelap di aplikasi (0xFFE8A59C)
CREAM = (251, 243, 232)           # warna latar logo (#FBF3E8)
LOGO_WIDTH = 768     # logo lengkap tampil <= ~220 dp -> tajam sampai layar 3,5x
MARK_WIDTH = 256     # bubble tampil <= 64 dp -> tajam sampai layar 4x

DENSITIES = {  # nama folder: skala dp->px
    "mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0,
}


def extract(path):
    """Mengembalikan (rgba, bubble_box, split_y) pada resolusi kerja."""
    img = Image.open(path).convert("RGB").resize((WORK, WORK), Image.LANCZOS)
    a = np.asarray(img).astype(np.int16)
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(border, axis=0)
    dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
    bg_like = dist < BG_THRESHOLD

    lab, n = ndi.label(bg_like)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}

    # bubble = komponen foreground terbesar; tulisan berada di bawahnya
    fg_lab, fn = ndi.label(~bg_like)
    sizes = ndi.sum(~bg_like, fg_lab, range(1, fn + 1))
    big = int(np.argmax(sizes)) + 1
    box = ndi.find_objects(fg_lab)[big - 1]
    split_y = box[0].stop

    transparent = np.isin(lab, list(edge))
    centers = ndi.center_of_mass(bg_like, lab, range(1, n + 1))
    for i, (cy, _cx) in enumerate(centers, start=1):
        # lubang huruf (di bawah bubble) transparan; motif di dalam bubble tidak
        if i not in edge and cy > split_y:
            transparent |= lab == i

    alpha = ndi.binary_erosion(~transparent, iterations=ERODE)
    rgba = np.dstack([a.astype(np.uint8), (alpha * 255).astype(np.uint8)])
    return rgba, box, split_y


def crop_to_alpha(rgba, pad=0):
    ys, xs = np.where(rgba[:, :, 3] > 0)
    y0, y1 = max(ys.min() - pad, 0), min(ys.max() + 1 + pad, rgba.shape[0])
    x0, x1 = max(xs.min() - pad, 0), min(xs.max() + 1 + pad, rgba.shape[1])
    return rgba[y0:y1, x0:x1]


def to_image(arr):
    return Image.fromarray(np.ascontiguousarray(arr), "RGBA")


def resize_width(img, width):
    return img.resize((width, round(img.height * width / img.width)), Image.LANCZOS)


def monochrome(mark_arr):
    """Siluet satu warna untuk ikon bertema: bubble padat, motif jadi lubang."""
    green = mark_arr[:, :, 1].astype(float)
    cream_weight = np.clip((green - 110.0) / 90.0, 0.0, 1.0)
    alpha = (mark_arr[:, :, 3] / 255.0) * (1.0 - cream_weight)
    out = np.zeros(mark_arr.shape, dtype=np.uint8)
    out[:, :, 3] = np.round(alpha * 255).astype(np.uint8)
    return to_image(out)


def place(mark, canvas, height_frac, bg=None):
    """Menaruh [mark] di tengah kanvas persegi; tinggi = height_frac * kanvas."""
    out = Image.new("RGBA", (canvas, canvas), (*bg, 255) if bg else (0, 0, 0, 0))
    h = round(canvas * height_frac)
    w = round(h * mark.width / mark.height)
    out.alpha_composite(mark.resize((w, h), Image.LANCZOS), ((canvas - w) // 2, (canvas - h) // 2))
    return out


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    print("  ", os.path.relpath(path))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True, help="PNG master logo (bubble + tulisan, latar polos)")
    ap.add_argument("--project", default=".", help="folder proyek Flutter")
    args = ap.parse_args()
    root = args.project

    rgba, box, split_y = extract(args.source)
    full_arr = crop_to_alpha(rgba, pad=24)

    # ---- aset di dalam aplikasi
    save(resize_width(to_image(full_arr), LOGO_WIDTH), f"{root}/assets/images/horas_logo.png")

    dark = rgba.copy()
    dark[split_y:, :, :3] = DARK_WORDMARK       # hanya tulisan (di bawah bubble)
    save(resize_width(to_image(crop_to_alpha(dark, pad=24)), LOGO_WIDTH), f"{root}/assets/images/horas_logo_dark.png")

    mark_arr = rgba.copy()
    mark_arr[split_y:, :, 3] = 0                # buang tulisan
    mark_arr = crop_to_alpha(mark_arr, pad=16)
    mark_img = to_image(mark_arr)
    save(resize_width(mark_img, MARK_WIDTH), f"{root}/assets/images/horas_mark.png")

    # ---- ikon Android
    res = f"{root}/android/app/src/main/res"
    mono_img = monochrome(mark_arr)
    for name, scale in DENSITIES.items():
        save(place(mark_img, round(108 * scale), 56 / 108), f"{res}/mipmap-{name}/ic_launcher_foreground.png")
        save(place(mono_img, round(108 * scale), 56 / 108), f"{res}/mipmap-{name}/ic_launcher_monochrome.png")
        legacy = place(mark_img, round(48 * scale), 0.66, bg=CREAM).convert("RGB")
        save(legacy, f"{res}/mipmap-{name}/ic_launcher.png")

    os.makedirs(f"{res}/mipmap-anydpi-v26", exist_ok=True)
    with open(f"{res}/mipmap-anydpi-v26/ic_launcher.xml", "w", encoding="utf-8") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background"/>\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
            '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n'
            "</adaptive-icon>\n"
        )
    with open(f"{res}/values/ic_launcher_background.xml", "w", encoding="utf-8") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<resources>\n"
            f'    <color name="ic_launcher_background">#{CREAM[0]:02X}{CREAM[1]:02X}{CREAM[2]:02X}</color>\n'
            "</resources>\n"
        )
    print("   android: ikon adaptif + legacy + monokrom")

    # ---- ikon web
    for size in (192, 512):
        save(place(mark_img, size, 0.72, bg=CREAM).convert("RGB"), f"{root}/web/icons/Icon-{size}.png")
        save(place(mark_img, size, 0.58, bg=CREAM).convert("RGB"), f"{root}/web/icons/Icon-maskable-{size}.png")
    save(place(mark_img, 64, 0.94), f"{root}/web/favicon.png")


if __name__ == "__main__":
    main()
