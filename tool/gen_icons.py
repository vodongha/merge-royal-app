"""Generate Merge Royal store art: adaptive icon, 512 icon, feature graphic, logo."""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = r"C:\Users\ADMIN\Documents\Personal\merge-royal-app"
ICON_DIR = os.path.join(REPO, "assets", "icon")
STORE_DIR = os.path.join(REPO, "store")
os.makedirs(ICON_DIR, exist_ok=True)
os.makedirs(STORE_DIR, exist_ok=True)

# Palette
DARK = (5, 6, 8)
NEON = (79, 247, 224)
NEON_DEEP = (31, 185, 166)
PURPLE = (139, 125, 255)
PINK = (224, 70, 122)
WHITE = (255, 255, 255)

F_BLACK = r"C:\Windows\Fonts\ariblk.ttf"   # Arial Black
F_SYM = r"C:\Windows\Fonts\seguisym.ttf"   # Segoe UI Symbol (has ♠)
F_ARIAL = r"C:\Windows\Fonts\arialbd.ttf"


def font(path, size):
    return ImageFont.truetype(path, size)


def glow_bg(w, h, glow=NEON_DEEP, strength=120, blobs=None):
    """Dark background with soft neon radial glow(s)."""
    bg = Image.new("RGB", (w, h), DARK)
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    if blobs is None:
        blobs = [(w * 0.5, h * 0.42, min(w, h) * 0.55, 110)]
    for cx, cy, r, a in blobs:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(glow[0], glow[1], glow[2], a))
    layer = layer.filter(ImageFilter.GaussianBlur(strength))
    bg.paste(layer, (0, 0), layer)
    return bg


def rounded(draw, box, radius, **kw):
    draw.rounded_rectangle(box, radius=radius, **kw)


def draw_card(base, cx, cy, w, h, color=NEON, spade=False, value=None, rot=0):
    """Draw one neon card (with glow) centered at (cx,cy) onto RGBA `base`."""
    pad = int(max(w, h) * 0.9)
    cw, ch = w + pad, h + pad
    card = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    d = ImageDraw.Draw(card)
    bx0, by0 = (cw - w) // 2, (ch - h) // 2
    box = [bx0, by0, bx0 + w, by0 + h]
    r = int(w * 0.16)

    # glow halo
    glow = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    rounded(gd, box, r, outline=(color[0], color[1], color[2], 255), width=int(w * 0.06))
    glow = glow.filter(ImageFilter.GaussianBlur(int(w * 0.08)))
    card.alpha_composite(glow)

    # body fill (dark with translucent tint) + neon border
    rounded(d, box, r, fill=(10, 18, 20, 235))
    rounded(d, box, r, outline=(color[0], color[1], color[2], 255), width=int(w * 0.035))
    # top sheen
    sheen = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sheen)
    rounded(sd, [bx0, by0, bx0 + w, by0 + int(h * 0.42)], r,
            fill=(255, 255, 255, 38))
    mask = Image.new("L", (cw, ch), 0)
    md = ImageDraw.Draw(mask)
    rounded(md, box, r, fill=255)
    card.paste(sheen, (0, 0), Image.composite(sheen.split()[3], Image.new("L", (cw, ch), 0), mask))

    if spade:
        fsz = int(h * 0.5)
        fnt = font(F_SYM, fsz)
        glyph = "♠"
        tb = d.textbbox((0, 0), glyph, font=fnt)
        tw, th = tb[2] - tb[0], tb[3] - tb[1]
        d.text((cx_offset := bx0 + (w - tw) / 2 - tb[0], by0 + (h - th) / 2 - tb[1]),
               glyph, font=fnt, fill=color)
    if value is not None:
        fnt = font(F_BLACK, int(h * 0.22))
        d.text((bx0 + w * 0.12, by0 + h * 0.06), str(value), font=fnt, fill=WHITE)

    if rot:
        card = card.rotate(rot, resample=Image.BICUBIC, expand=False)
    base.alpha_composite(card, (int(cx - cw / 2), int(cy - ch / 2)))


def card_motif(size, scale=1.0, offy=0.0):
    """Two overlapping neon cards (back + front-with-spade), transparent layer."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cw = int(size * 0.40 * scale)
    ch = int(cw * 1.4)
    cx, cy = size * 0.5, size * (0.52 + offy)
    # back card (purple-ish, offset up-left, slight rotate)
    draw_card(layer, cx - cw * 0.34, cy - ch * 0.20, cw, ch, color=PURPLE, value=8, rot=9)
    # front card (neon, with spade, offset down-right)
    draw_card(layer, cx + cw * 0.30, cy + ch * 0.16, cw, ch, color=NEON, spade=True, rot=-6)
    return layer


# ---- 1) Adaptive foreground (transparent, safe-zone padded) ----------------
FG = 1024
fg = card_motif(FG, scale=0.82, offy=-0.02)
fg.save(os.path.join(ICON_DIR, "foreground.png"))
print("foreground.png")

# ---- 2) Adaptive background ------------------------------------------------
bg = glow_bg(FG, FG, glow=NEON_DEEP, strength=160,
             blobs=[(FG * 0.5, FG * 0.5, FG * 0.6, 120)]).convert("RGBA")
bg.save(os.path.join(ICON_DIR, "background.png"))
print("background.png")

# ---- 3) Full composite icon (main) + Play 512 ------------------------------
full = bg.copy()
full.alpha_composite(card_motif(FG, scale=0.72))
full = full.convert("RGB")
full.save(os.path.join(ICON_DIR, "icon.png"))
full.resize((512, 512), Image.LANCZOS).save(os.path.join(STORE_DIR, "play_icon_512.png"))
print("icon.png + play_icon_512.png")


# ---- helper: neon wordmark -------------------------------------------------
def wordmark(draw, xy, text, size, color=NEON, anchor="lm"):
    fnt = font(F_BLACK, size)
    x, y = xy
    return fnt


def draw_neon_text(img, text, fnt, xy, color=NEON, anchor="lm", glow_r=14):
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.text(xy, text, font=fnt, fill=(color[0], color[1], color[2], 255), anchor=anchor)
    glow = glow.filter(ImageFilter.GaussianBlur(glow_r))
    img.alpha_composite(glow)
    d = ImageDraw.Draw(img)
    d.text(xy, text, font=fnt, fill=color, anchor=anchor)


# ---- 4) Feature graphic 1024 x 500 -----------------------------------------
FW, FH = 1024, 500
feat = glow_bg(FW, FH, glow=NEON_DEEP, strength=130,
               blobs=[(FW * 0.74, FH * 0.5, 360, 120),
                      (FW * 0.2, FH * 0.3, 240, 70)]).convert("RGBA")
# cards on the right
motif = card_motif(FH, scale=1.05)
feat.alpha_composite(motif, (int(FW * 0.60), 0))
# wordmark on the left
draw_neon_text(feat, "MERGE", font(F_BLACK, 110), (60, 190), color=NEON, anchor="lm", glow_r=18)
draw_neon_text(feat, "ROYAL", font(F_BLACK, 110), (60, 300), color=WHITE, anchor="lm", glow_r=14)
d = ImageDraw.Draw(feat)
d.text((66, 372), "MERGE  TO  WIN", font=font(F_ARIAL, 34), fill=NEON, anchor="lm")
feat.convert("RGB").save(os.path.join(STORE_DIR, "feature_graphic_1024x500.png"))
print("feature_graphic_1024x500.png")

# ---- 5) Logo (transparent wordmark + small card mark) ----------------------
LW, LH = 1280, 420
logo = Image.new("RGBA", (LW, LH), (0, 0, 0, 0))
logo.alpha_composite(card_motif(LH, scale=0.95), (-20, 0))
draw_neon_text(logo, "MERGE", font(F_BLACK, 130), (430, 165), color=NEON, anchor="lm", glow_r=20)
draw_neon_text(logo, "ROYAL", font(F_BLACK, 130), (430, 295), color=WHITE, anchor="lm", glow_r=16)
logo.save(os.path.join(STORE_DIR, "logo.png"))
print("logo.png")

print("DONE")
