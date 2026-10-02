"""Draws the PNG minimap icon sets into icons/<set>/<kind>.png.

Run from the plugin folder: python3 tools/make_icons.py
Needs Pillow. Each icon is drawn at 4x and scaled down, so edges are smooth.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

SIZE = 28
SS = 4
S = SIZE * SS

COLOURS = {
    "chest": (255, 215, 0),
    "rareChest": (255, 60, 220),
    "safe": (0, 200, 255),
    "corpse": (255, 140, 0),
    "ghost": (255, 50, 50),
    "ghostEstimate": (255, 190, 60),
}
INK = (18, 14, 22, 255)


def canvas():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def u(v):
    return v * SS


def n(v):
    return max(1, int(round(v * SS)))


def box(x0, y0, x1, y1):
    return [u(x0), u(y0), u(x1), u(y1)]


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def shade(rgb, t):
    return mix(rgb, (0, 0, 0), t) if t > 0 else mix(rgb, (255, 255, 255), -t)


def glow(img, rgb, radius, alpha, blur):
    layer = canvas()
    d = ImageDraw.Draw(layer)
    c = S / 2
    d.ellipse([c - u(radius), c - u(radius), c + u(radius), c + u(radius)], fill=rgb + (alpha,))
    return Image.alpha_composite(layer.filter(ImageFilter.GaussianBlur(u(blur))), img)


def shadow(img, dx=0.8, dy=1.2, blur=1.0, alpha=110):
    a = img.split()[3].point(lambda v: v * alpha // 255)
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sh.putalpha(a)
    sh = sh.filter(ImageFilter.GaussianBlur(u(blur)))
    moved = Image.new("RGBA", img.size, (0, 0, 0, 0))
    moved.paste(sh, (int(u(dx)), int(u(dy))))
    return Image.alpha_composite(moved, img)


def outline(img, width=1.1):
    a = img.split()[3]
    grown = a.filter(ImageFilter.MaxFilter(int(u(width)) * 2 + 1))
    edge = Image.new("RGBA", img.size, INK)
    edge.putalpha(grown)
    return Image.alpha_composite(edge, img)


def finish(img):
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def gradient_fill(shape_mask, top, bottom, y0, y1):
    grad = Image.new("RGBA", (S, S))
    gd = ImageDraw.Draw(grad)
    for y in range(S):
        t = min(1, max(0, (y - u(y0)) / max(1, u(y1) - u(y0))))
        gd.line([(0, y), (S, y)], fill=mix(top, bottom, t) + (255,))
    out = canvas()
    out.paste(grad, (0, 0), shape_mask)
    return out


def mask_of(draw_fn):
    m = Image.new("L", (S, S), 0)
    draw_fn(ImageDraw.Draw(m))
    return m


def ghost_shape(d, sway=0.0):
    d.ellipse(box(6.5, 4, 21.5, 19), fill=255)
    d.rectangle(box(6.5, 11.5, 21.5, 20), fill=255)
    pts = []
    for i in range(0, 61):
        x = 6.5 + 15 * i / 60
        y = 20 + 2.2 * math.sin(i / 60 * math.pi * 4 + sway)
        pts.append((u(x), u(y)))
    d.polygon([(u(6.5), u(19))] + pts + [(u(21.5), u(19))], fill=255)


# spirit: different shapes, flat in the kind colour with a white highlight


def flat(mask, rgb):
    img = gradient_fill(mask, shade(rgb, -0.3), shade(rgb, 0.3), 3, 24)
    return img


def spirit_open_chest(rgb, gem=False):
    back = mask_of(lambda d: d.polygon([(u(6), u(11)), (u(8), u(4)), (u(20), u(4)), (u(22), u(11))], fill=255))
    body = mask_of(lambda d: d.rounded_rectangle(box(4.5, 12, 23.5, 23), radius=n(1.5), fill=255))
    img = flat(back, shade(rgb, 0.35))
    gold = canvas()
    gd = ImageDraw.Draw(gold)
    if gem:
        gd.polygon([(u(14), u(6)), (u(18), u(10)), (u(14), u(15)), (u(10), u(10))], fill=(255, 255, 255, 255))
        gd.polygon([(u(14), u(6)), (u(18), u(10)), (u(14), u(10))], fill=(255, 210, 250, 255))
    else:
        for (x, y) in ((9, 10), (13, 8.5), (17, 10), (11, 11.5), (15, 11.5)):
            gd.ellipse(box(x, y, x + 3.2, y + 3.2), fill=(255, 236, 140, 255), outline=(190, 140, 20, 255), width=n(0.5))
    img = Image.alpha_composite(img, gold)
    img = Image.alpha_composite(img, flat(body, rgb))
    d = ImageDraw.Draw(img)
    d.rectangle(box(4.5, 15, 23.5, 16.2), fill=shade(rgb, 0.45) + (255,))
    d.rounded_rectangle(box(12, 14, 16, 18.5), radius=n(0.8), fill=(255, 255, 255, 255))
    rays = canvas()
    rd = ImageDraw.Draw(rays)
    for a in (-60, -30, 0, 30, 60):
        r = math.radians(a - 90)
        rd.line([u(14), u(10), u(14 + 11 * math.cos(r)), u(10 + 11 * math.sin(r))], fill=(255, 255, 220, 110), width=n(1.2))
    rays = rays.filter(ImageFilter.GaussianBlur(u(0.6)))
    return finish(shadow(Image.alpha_composite(rays, outline(img))))


def spirit_vault(rgb):
    m = mask_of(lambda d: d.ellipse(box(3.5, 3.5, 24.5, 24.5), fill=255))
    img = flat(m, rgb)
    d = ImageDraw.Draw(img)
    d.ellipse(box(6, 6, 22, 22), outline=shade(rgb, 0.45) + (255,), width=n(1))
    for a in range(0, 360, 60):
        r = math.radians(a)
        d.line([u(14 + 2 * math.cos(r)), u(14 + 2 * math.sin(r)), u(14 + 6.5 * math.cos(r)), u(14 + 6.5 * math.sin(r))],
               fill=(255, 255, 255, 255), width=n(1.2))
        d.ellipse(box(14 + 6.5 * math.cos(r) - 1, 14 + 6.5 * math.sin(r) - 1, 14 + 6.5 * math.cos(r) + 1, 14 + 6.5 * math.sin(r) + 1),
                  fill=(255, 255, 255, 255))
    d.ellipse(box(11.8, 11.8, 16.2, 16.2), fill=(255, 255, 255, 255))
    d.ellipse(box(13, 13, 15, 15), fill=shade(rgb, 0.5) + (255,))
    return finish(shadow(outline(img)))


def spirit_tombstone(rgb):
    m = mask_of(lambda d: (d.ellipse(box(7, 3.5, 21, 15), fill=255), d.rectangle(box(7, 9, 21, 22), fill=255)))
    img = flat(m, rgb)
    d = ImageDraw.Draw(img)
    d.rectangle(box(13, 7, 15, 17), fill=(255, 255, 255, 255))
    d.rectangle(box(10, 9.5, 18, 11.5), fill=(255, 255, 255, 255))
    ground = mask_of(lambda d2: d2.rounded_rectangle(box(4, 21, 24, 24.5), radius=n(1.5), fill=255))
    img = Image.alpha_composite(img, flat(ground, shade(rgb, 0.4)))
    return finish(shadow(outline(img)))


def spirit_skull(rgb):
    bones = canvas()
    bd = ImageDraw.Draw(bones)
    for (x0, y0, x1, y1) in ((5, 23.5, 23, 17.5), (5, 17.5, 23, 23.5)):
        bd.line([u(x0), u(y0), u(x1), u(y1)], fill=shade(rgb, 0.3) + (255,), width=n(2))
        for (x, y) in ((x0, y0), (x1, y1)):
            bd.ellipse(box(x - 1.5, y - 1.5, x + 1.5, y + 1.5), fill=shade(rgb, 0.3) + (255,))
    m = mask_of(lambda d: (d.ellipse(box(7, 3.5, 21, 17), fill=255), d.rounded_rectangle(box(9.5, 13, 18.5, 20), radius=n(1.5), fill=255)))
    img = Image.alpha_composite(bones, flat(m, rgb))
    d = ImageDraw.Draw(img)
    for x in (9.3, 15):
        d.ellipse(box(x, 9, x + 3.7, 13), fill=INK)
    d.polygon([(u(14), u(13.5)), (u(15), u(15.5)), (u(13), u(15.5))], fill=INK)
    for x in (12, 14, 16):
        d.line([u(x), u(17), u(x), u(20)], fill=INK, width=n(0.6))
    return finish(shadow(outline(img)))


def spirit_helmet(rgb):
    crest = mask_of(lambda d: d.chord(box(6, 1.5, 22, 10), 180, 360, fill=255))
    helm = mask_of(lambda d: (d.chord(box(6.5, 6, 21.5, 22), 180, 360, fill=255), d.rectangle(box(6.5, 13.5, 21.5, 15), fill=255),
                              d.polygon([(u(6.5), u(14)), (u(10), u(14)), (u(10), u(23)), (u(7.5), u(23.5))], fill=255),
                              d.polygon([(u(21.5), u(14)), (u(18), u(14)), (u(18), u(23)), (u(20.5), u(23.5))], fill=255)))
    img = Image.alpha_composite(flat(crest, shade(rgb, 0.35)), flat(helm, rgb))
    d = ImageDraw.Draw(img)
    d.rectangle(box(6.5, 13.6, 21.5, 15), fill=(255, 255, 255, 255))
    d.rectangle(box(11, 15, 17, 23), fill=INK)
    d.rectangle(box(13.2, 15, 14.8, 20), fill=rgb + (255,))
    return finish(shadow(outline(img)))


def spirit_grave(rgb):
    mound = mask_of(lambda d: d.chord(box(3, 15, 25, 31), 180, 360, fill=255))
    img = flat(mound, shade(rgb, 0.25))
    sword = canvas()
    sd = ImageDraw.Draw(sword)
    sd.polygon([(u(12.8), u(20)), (u(12.8), u(7)), (u(14), u(4.5)), (u(15.2), u(7)), (u(15.2), u(20))], fill=(235, 238, 245, 255))
    sd.rectangle(box(9.5, 17.5, 18.5, 19.3), fill=rgb + (255,))
    sd.rectangle(box(13, 19.3, 15, 23), fill=shade(rgb, 0.4) + (255,))
    sd.ellipse(box(12.6, 22.4, 15.4, 25.2), fill=rgb + (255,))
    sword = sword.rotate(180, center=(S / 2, u(14.5)))
    img = Image.alpha_composite(img, sword)
    return finish(shadow(outline(img)))


def spirit_shield(rgb):
    m = mask_of(lambda d: d.rounded_rectangle(box(6, 3, 22, 25), radius=n(2), fill=255))
    img = flat(m, rgb)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box(7.6, 4.6, 20.4, 23.4), radius=n(1.4), outline=shade(rgb, 0.45) + (255,), width=n(0.8))
    w = (255, 255, 255, 255)
    d.polygon([(u(14), u(7)), (u(17.5), u(14)), (u(14), u(21)), (u(10.5), u(14))], outline=w, width=n(1.2))
    d.line([u(10), u(9.5), u(18), u(18.5)], fill=w, width=n(1.1))
    d.line([u(18), u(9.5), u(10), u(18.5)], fill=w, width=n(1.1))
    d.ellipse(box(12.3, 12.3, 15.7, 15.7), fill=w)
    return finish(shadow(outline(img)))


def spirit_hooded(rgb):
    m = mask_of(lambda d: d.polygon([(u(14), u(2.5)), (u(22), u(10)), (u(23.5), u(24)), (u(19.5), u(21.5)), (u(16.5), u(24)),
                                     (u(14), u(21.5)), (u(11.5), u(24)), (u(8.5), u(21.5)), (u(4.5), u(24)), (u(6), u(10))], fill=255))
    img = flat(m, rgb)
    d = ImageDraw.Draw(img)
    d.ellipse(box(9, 8, 19, 17.5), fill=INK)
    eyes = canvas()
    ed = ImageDraw.Draw(eyes)
    for x in (11, 15):
        ed.ellipse(box(x, 11.2, x + 2, 13.4), fill=(255, 255, 255, 255))
    halo = eyes.filter(ImageFilter.GaussianBlur(u(0.9)))
    img = Image.alpha_composite(Image.alpha_composite(img, halo), eyes)
    return finish(shadow(outline(img)))


# symbols as masks, so a set can ink, carve or glow them


def symbol_mask(kind, cx=14, cy=14, k=1.0):
    def t(x, y):
        return u(cx + (x - 14) * k), u(cy + (y - 14) * k)

    def rect(x0, y0, x1, y1):
        a, b = t(x0, y0)
        c, d = t(x1, y1)
        return [a, b, c, d]

    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    if kind in ("chest", "rareChest"):
        d.rounded_rectangle(rect(7, 12, 21, 21), radius=n(1.2 * k), fill=255)
        d.chord(rect(7, 6, 21, 16), 180, 360, fill=255)
        d.rectangle(rect(7, 11, 21, 12), fill=255)
        d.line([*t(7, 12.6), *t(21, 12.6)], fill=0, width=n(0.9 * k))
        d.rectangle(rect(12.8, 11.5, 15.2, 15.5), fill=0)
        if kind == "rareChest":
            cx, cy = t(19.5, 8)
            a, b = u(3.4 * k), u(1 * k)
            d.polygon([(cx, cy - a), (cx + b, cy), (cx, cy + a), (cx - b, cy)], fill=255)
            d.polygon([(cx - a, cy), (cx, cy - b), (cx + a, cy), (cx, cy + b)], fill=255)
    elif kind == "safe":
        d.rounded_rectangle(rect(7, 7, 21, 21), radius=n(1.5 * k), fill=255)
        d.ellipse(rect(9.5, 9.5, 18.5, 18.5), fill=0)
        d.ellipse(rect(11.3, 11.3, 16.7, 16.7), fill=255)
        d.ellipse(rect(13, 13, 15, 15), fill=0)
        for ang in range(0, 360, 90):
            r = math.radians(ang)
            d.line([*t(14 + 3 * math.cos(r), 14 + 3 * math.sin(r)), *t(14 + 4.4 * math.cos(r), 14 + 4.4 * math.sin(r))],
                   fill=255, width=n(1 * k))
    elif kind == "corpse":
        d.ellipse(rect(8, 6, 20, 18), fill=255)
        d.rounded_rectangle(rect(10.5, 15, 17.5, 21.5), radius=n(1.2 * k), fill=255)
        d.ellipse(rect(9.8, 10.5, 13.2, 14.2), fill=0)
        d.ellipse(rect(14.8, 10.5, 18.2, 14.2), fill=0)
        d.polygon([t(14, 14.8), t(15, 16.8), t(13, 16.8)], fill=0)
        for x in (12.2, 14, 15.8):
            d.line([*t(x, 18.3), *t(x, 21.5)], fill=0, width=n(0.6 * k))
    elif kind in ("ghost", "ghostEstimate"):
        d.ellipse(rect(8, 5.5, 20, 17.5), fill=255)
        d.rectangle(rect(8, 11.5, 20, 19), fill=255)
        pts = [t(8, 18.5)]
        for i in range(0, 41):
            x = 8 + 12 * i / 40
            pts.append(t(x, 19.5 + 1.8 * math.sin(i / 40 * math.pi * 3)))
        pts.append(t(20, 18.5))
        d.polygon(pts, fill=255)
        d.ellipse(rect(10.6, 10, 12.8, 13.4), fill=0)
        d.ellipse(rect(15.2, 10, 17.4, 13.4), fill=0)
    return m


def solid(mask, rgb, alpha=255):
    layer = Image.new("RGBA", (S, S), rgb + (alpha,))
    out = canvas()
    out.paste(layer, (0, 0), mask)
    return out


def ImageChopsInvert(m):
    return m.point(lambda v: 255 - v)


# pictures of the vault's own objects, drawn from the wiki's renders (used by native and the mixed set's safe)


WOOD, WOOD_DARK = (112, 58, 40), (58, 28, 22)
VGOLD_LIGHT, VGOLD, VGOLD_DARK = (255, 232, 140), (214, 160, 52), (128, 84, 24)
SPECTRAL = (90, 235, 240)
ZAROS = (170, 60, 220)


def flare(d, x, y, sx):
    d.polygon([(u(x), u(y + 2)), (u(x + sx * 0.4), u(y - 2.6)), (u(x + sx * 2.6), u(y - 0.2)), (u(x + sx * 2.2), u(y + 2.6))],
              fill=VGOLD + (255,))


CHEST_LOOKS = ("flared", "plain", "corners", "domed", "strongbox", "open")


def vault_chest(rgb, gold=False, look="flared", wood=None, trim=None, lock=None, sparkle=(255, 255, 255)):
    top, bottom = (VGOLD_LIGHT, VGOLD_DARK) if gold else (shade(WOOD, -0.25), WOOD_DARK)
    if wood:
        top, bottom = shade(wood, -0.3), shade(wood, 0.5)
    trim = trim or (VGOLD_DARK if gold else VGOLD)
    lock = lock or (VGOLD_DARK if gold else VGOLD_LIGHT)
    iron = (70, 72, 80)
    flat_lid = look == "strongbox"
    lid_top = 4 if look == "domed" else 6.5
    if look == "open":
        back = mask_of(lambda d: d.polygon([(u(5.5), u(12)), (u(7.5), u(4.5)), (u(20.5), u(4.5)), (u(22.5), u(12))], fill=255))
        img = gradient_fill(back, shade(bottom, 0.2), shade(bottom, 0.5), 4, 12)
        coins = canvas()
        cd = ImageDraw.Draw(coins)
        for (x, y) in ((8.5, 9.5), (12, 8), (15.5, 8.6), (18.5, 9.8), (10.5, 10.6), (14, 10.4), (17, 11)):
            cd.ellipse(box(x, y, x + 3, y + 3), fill=VGOLD_LIGHT + (255,), outline=VGOLD_DARK + (255,), width=n(0.4))
        shine = solid(coins.split()[3], (255, 240, 170)).filter(ImageFilter.GaussianBlur(u(1.2)))
        img = Image.alpha_composite(Image.alpha_composite(img, shine), coins)
    elif flat_lid:
        lid = mask_of(lambda d: d.rounded_rectangle(box(5, 8, 23, 13), radius=n(1), fill=255))
        img = gradient_fill(lid, top, mix(top, bottom, 0.5), 8, 13)
    else:
        lid = mask_of(lambda d: (d.chord(box(5, lid_top, 23, 17 + (13 - 17) * 0 + (lid_top - 6.5) * -1), 180, 360, fill=255),
                                 d.rectangle(box(5, 11.5, 23, 13), fill=255)))
        img = gradient_fill(lid, top, mix(top, bottom, 0.5), lid_top, 13)
    body = mask_of(lambda d: d.rounded_rectangle(box(5, 12.5, 23, 23.5), radius=n(1.2), fill=255))
    img = Image.alpha_composite(img, gradient_fill(body, mix(top, bottom, 0.3), bottom, 12, 24))
    d = ImageDraw.Draw(img)
    if not gold:
        for y in (15.5, 18.5, 21.2):
            d.line([u(5.5), u(y), u(22.5), u(y)], fill=shade(wood or WOOD, 0.55) + (255,), width=n(0.4))
    band = iron if look == "strongbox" else trim
    d.rectangle(box(5, 12, 23, 13.3), fill=band + (255,))
    d.rectangle(box(5, 22.3, 23, 23.5), fill=band + (255,))
    if look == "strongbox":
        for x in (9, 19):
            d.rectangle(box(x - 0.8, 8, x + 0.8, 23.5), fill=iron + (255,))
            for y in (9.5, 15, 20.5):
                d.ellipse(box(x - 0.45, y - 0.45, x + 0.45, y + 0.45), fill=(170, 172, 180, 255))
    elif look == "domed":
        for x in (8.5, 19.5):
            d.rectangle(box(x - 0.9, 5, x + 0.9, 23.5), fill=trim + (255,))
    else:
        for x in (5, 21.6):
            d.rectangle(box(x, 12, x + 1.4, 23.5), fill=trim + (255,))
    if look == "flared":
        flare(d, 5.2, 9, -1)
        flare(d, 22.8, 9, 1)
    if look == "corners":
        for (x, y, sx, sy) in ((5, 12, 1, 1), (23, 12, -1, 1), (5, 23.5, 1, -1), (23, 23.5, -1, -1)):
            d.polygon([(u(x), u(y)), (u(x + sx * 3.2), u(y)), (u(x), u(y + sy * 3.2))], fill=VGOLD_LIGHT + (255,))
    if look != "open":
        d.polygon([(u(14), u(10)), (u(17), u(12.5)), (u(16.4), u(18.5)), (u(14), u(20)), (u(11.6), u(18.5)), (u(11), u(12.5))],
                  fill=lock + (255,))
        d.ellipse(box(13.2, 13.6, 14.8, 15.2), fill=INK)
        d.rectangle(box(13.6, 14.8, 14.4, 17), fill=INK)
    else:
        d.rounded_rectangle(box(12.2, 14, 15.8, 18), radius=n(0.6), fill=lock + (255,))
    img = outline(img)
    if gold:
        sd = ImageDraw.Draw(img)
        for (cx, cy, r) in ((22, 4.5, 3.6), (6.5, 5.5, 2.2)):
            sd.polygon([(u(cx), u(cy - r)), (u(cx + r * 0.25), u(cy)), (u(cx), u(cy + r)), (u(cx - r * 0.25), u(cy))], fill=sparkle + (255,))
            sd.polygon([(u(cx - r), u(cy)), (u(cx), u(cy - r * 0.25)), (u(cx + r), u(cy)), (u(cx), u(cy + r * 0.25))], fill=sparkle + (255,))
    return img


def vault_safe(rgb):
    steel = (84, 88, 100)
    body = mask_of(lambda d: d.polygon([(u(5.5), u(4.5)), (u(22.5), u(4.5)), (u(23.2), u(23)), (u(4.8), u(23))], fill=255))
    img = gradient_fill(body, shade(steel, -0.3), shade(steel, 0.45), 4, 23)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box(7, 7.5, 21, 21), radius=n(0.8), outline=shade(steel, 0.55) + (255,), width=n(0.6))
    d.ellipse(box(8.5, 9.5, 16.5, 17.5), fill=(225, 228, 232, 255), outline=(150, 150, 160, 255), width=n(0.5))
    for a in range(0, 360, 30):
        r = math.radians(a)
        d.line([u(12.5 + 3.3 * math.cos(r)), u(13.5 + 3.3 * math.sin(r)), u(12.5 + 3.9 * math.cos(r)), u(13.5 + 3.9 * math.sin(r))],
               fill=(70, 70, 80, 255), width=n(0.35))
    d.ellipse(box(10.6, 11.6, 14.4, 15.4), fill=(190, 194, 200, 255))
    d.polygon([(u(12.5), u(9.8)), (u(13.1), u(10.8)), (u(11.9), u(10.8))], fill=INK)
    d.ellipse(box(17.4, 11.6, 20, 14.2), fill=(220, 208, 170, 255))
    d.rounded_rectangle(box(18.1, 13.6, 19.3, 18.5), radius=n(0.5), fill=(220, 208, 170, 255))
    return outline(img)


def vault_corpse(rgb):
    img = canvas()
    d = ImageDraw.Draw(img)
    bone = (226, 216, 190, 255)
    for (x0, y0, x1, y1) in ((5, 22, 23, 17), (6, 16.5, 22.5, 22.5)):
        d.line([u(x0), u(y0), u(x1), u(y1)], fill=bone, width=n(1.6))
        for (x, y) in ((x0, y0), (x1, y1)):
            d.ellipse(box(x - 1.3, y - 1.3, x + 1.3, y + 1.3), fill=bone)
    helmet = canvas()
    hm = mask_of(lambda dd: (dd.chord(box(7.5, 4.5, 20.5, 19), 180, 360, fill=255), dd.rectangle(box(7.5, 11.5, 20.5, 13), fill=255),
                             dd.polygon([(u(7.5), u(12)), (u(10.5), u(12)), (u(10.5), u(19)), (u(8.3), u(19.5))], fill=255),
                             dd.polygon([(u(20.5), u(12)), (u(17.5), u(12)), (u(17.5), u(19)), (u(19.7), u(19.5))], fill=255)))
    armour = (70, 140, 92)
    helmet = gradient_fill(hm, shade(armour, -0.35), shade(armour, 0.5), 4, 20)
    hd = ImageDraw.Draw(helmet)
    hd.rectangle(box(7.5, 11.6, 20.5, 12.8), fill=ZAROS + (255,))
    hd.ellipse(box(11, 13, 17, 19), fill=INK)
    hd.line([u(14), u(4.8), u(14), u(11.5)], fill=shade(armour, 0.55) + (255,), width=n(0.6))
    img = Image.alpha_composite(img, helmet)
    return outline(img)


def vault_ghost(rgb):
    m = mask_of(ghost_shape)
    body = gradient_fill(m, mix(SPECTRAL, (255, 255, 255), 0.7), SPECTRAL, 4, 22)
    body.putalpha(m.point(lambda v: v * 235 // 255))
    d = ImageDraw.Draw(body)
    d.chord(box(8.2, 4.3, 19.8, 15), 180, 360, fill=shade(SPECTRAL, 0.3) + (255,))
    d.rectangle(box(8.2, 9.4, 19.8, 10.8), fill=shade(SPECTRAL, 0.3) + (255,))
    d.polygon([(u(14), u(2.4)), (u(15.1), u(5)), (u(12.9), u(5))], fill=shade(SPECTRAL, 0.3) + (255,))
    for x in (10.4, 15.2):
        d.ellipse(box(x, 11.5, x + 2.4, 14.4), fill=INK)
        d.ellipse(box(x + 0.6, 12, x + 1.4, 12.8), fill=(255, 255, 255, 255))
    aura = solid(m, SPECTRAL).filter(ImageFilter.GaussianBlur(u(1.4)))
    return Image.alpha_composite(aura, outline(body, 0.8))


VAULT_PICTURES = {
    "chest": lambda: vault_chest(COLOURS["chest"], look="strongbox"),
    "rareChest": lambda: vault_chest(COLOURS["rareChest"], gold=True, look="strongbox", wood=(90, 30, 130),
                                     sparkle=(235, 190, 255)),
    "safe": lambda: vault_safe(COLOURS["safe"]),
    "corpse": lambda: vault_corpse(COLOURS["corpse"]),
    "ghost": lambda: vault_ghost(COLOURS["ghost"]),
    "ghostEstimate": lambda: vault_ghost(COLOURS["ghostEstimate"]),
}


def picture(kind, scale, cx, cy):
    art = VAULT_PICTURES[kind]()
    w = int(S * scale)
    art = art.resize((w, w), Image.LANCZOS)
    out = canvas()
    out.paste(art, (int(u(cx) - w / 2), int(u(cy) - w / 2)), art)
    return out


RIM_LIGHT, RIM, RIM_DARK = (205, 220, 245), (140, 162, 205), (70, 86, 125)


def native(kind):
    return finish(shadow(outline(picture(kind, 1.0, 14, 14), 1.0), blur=0.6, alpha=130))


def glowing_safe():
    return finish(shadow(glow(picture("safe", 1.0, 14, 14), COLOURS["safe"], 12.5, 135, 2.2)))


# kharid-et: archaeology find tags, the object inked on parchment, tied with string in its colour


PARCHMENT_LIGHT, PARCHMENT, PARCHMENT_DARK = (244, 226, 186), (222, 190, 136), (150, 108, 62)
SEPIA = (74, 44, 24)


def find_tag(kind):
    rgb = COLOURS[kind]
    tag = mask_of(lambda d: d.polygon([(u(9), u(4)), (u(19), u(4)), (u(22.5), u(8)), (u(22.5), u(25)), (u(5.5), u(25)), (u(5.5), u(8))],
                                      fill=255))
    img = gradient_fill(tag, PARCHMENT_LIGHT, PARCHMENT, 4, 25)
    stains = canvas()
    sd = ImageDraw.Draw(stains)
    for (x, y, r) in ((8, 21, 2.2), (19, 12, 1.6), (17, 23, 1.2)):
        sd.ellipse(box(x - r, y - r, x + r, y + r), fill=PARCHMENT_DARK + (60,))
    img = Image.alpha_composite(img, Image.composite(stains.filter(ImageFilter.GaussianBlur(u(0.8))), canvas(), tag))
    edge = Image.composite(tag, Image.new("L", (S, S), 0), ImageChopsInvert(tag.filter(ImageFilter.MinFilter(int(u(0.9)) * 2 + 1))))
    img = Image.alpha_composite(img, solid(edge, PARCHMENT_DARK, 200))
    sym = symbol_mask(kind, 14, 16.3, 0.6)
    wash = solid(sym.filter(ImageFilter.MaxFilter(int(u(2.2)) * 2 + 1)), rgb, 235).filter(ImageFilter.GaussianBlur(u(1)))
    img = Image.alpha_composite(img, Image.composite(wash, canvas(), tag))
    img = Image.alpha_composite(img, solid(sym, SEPIA, 255))
    d = ImageDraw.Draw(img)
    d.ellipse(box(12.6, 5.6, 15.4, 8.4), fill=PARCHMENT_DARK + (255,))
    d.ellipse(box(13.3, 6.3, 14.7, 7.7), fill=(0, 0, 0, 0))
    img = outline(img, 0.7)
    string = canvas()
    st = ImageDraw.Draw(string)
    st.line([u(14), u(7), u(16), u(3.5), u(20), u(1.6), u(24), u(2.4)], fill=shade(rgb, 0.15) + (255,), width=n(1.2), joint="curve")
    img = Image.alpha_composite(img, string)
    img = img.rotate(-10, resample=Image.BICUBIC, center=(S / 2, S / 2))
    return finish(shadow(img, blur=0.7, alpha=120))


SETS = {
    "native": dict({k: (lambda k=k: native(k)) for k in COLOURS},
                   corpse=lambda: spirit_skull(COLOURS["corpse"]),
                   ghost=lambda: spirit_hooded(COLOURS["ghost"]),
                   ghostEstimate=lambda: spirit_hooded(COLOURS["ghostEstimate"])),
    "digsite": {k: (lambda k=k: find_tag(k)) for k in COLOURS},
    "spirit": {
        "chest": lambda: spirit_open_chest(COLOURS["chest"]),
        "rareChest": lambda: spirit_open_chest(COLOURS["rareChest"], gem=True),
        "safe": lambda: spirit_vault(COLOURS["safe"]),
        "corpse": lambda: spirit_tombstone(COLOURS["corpse"]),
        "ghost": lambda: spirit_hooded(COLOURS["ghost"]),
        "ghostEstimate": lambda: spirit_hooded(COLOURS["ghostEstimate"]),
    },
    "mixed": {
        "chest": lambda: spirit_open_chest(COLOURS["chest"]),
        "rareChest": lambda: spirit_open_chest(COLOURS["rareChest"], gem=True),
        "safe": glowing_safe,
        "corpse": lambda: spirit_skull(COLOURS["corpse"]),
        "ghost": lambda: spirit_hooded(COLOURS["ghost"]),
        "ghostEstimate": lambda: spirit_hooded(COLOURS["ghostEstimate"]),
    },
}


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "icons")
    for name, kinds in SETS.items():
        folder = os.path.join(root, name)
        os.makedirs(folder, exist_ok=True)
        for kind, draw in kinds.items():
            draw().save(os.path.join(folder, kind + ".png"))
            print(os.path.join("icons", name, kind + ".png"))


if __name__ == "__main__":
    main()
