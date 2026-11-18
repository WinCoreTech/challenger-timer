#!/usr/bin/env python3
"""Renders brand/*.svg into Android launcher icons and the Play Store images.
Run with a Python that has cairosvg: python3 tools/make_icons.py"""
import pathlib, cairosvg
root = pathlib.Path(__file__).resolve().parent.parent
res = root / 'android/app/src/main/res'
def png(svg, out, px):
    out.parent.mkdir(parents=True, exist_ok=True)
    cairosvg.svg2png(url=str(root / 'brand' / svg), write_to=str(out), output_width=px, output_height=px)
legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
layer = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}
for d, px in legacy.items():
    png('logo.svg', res / f'mipmap-{d}/ic_launcher.png', px)
for d, px in layer.items():
    png('logo_foreground.svg', res / f'mipmap-{d}/ic_launcher_foreground.png', px)
    png('logo_mono.svg', res / f'mipmap-{d}/ic_launcher_monochrome.png', px)
png('logo.svg', root / 'brand/playstore_512.png', 512)
png('logo.svg', root / 'brand/logo_1024.png', 1024)
print('icons written')
