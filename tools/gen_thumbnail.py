"""Genera la miniatura del repo (docs/thumbnail.png, 1280x640: el tamano
de la vista previa social de GitHub) a partir de una captura del juego y
de los sprites del proyecto.

    python tools/gen_thumbnail.py
"""
import os

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
W, H = 1280, 640
FONT = os.path.join(ROOT, "sprites", "fonts", "Poppins-Medium.ttf")

# Tonos de la espada en las hojas del personaje (como en weapon_look.gd).
BLADE = {
    (242, 243, 199): 1.0,
    (215, 213, 152): 0.78,
    (195, 190, 138): 0.62,
    (169, 160, 121): 0.45,
}
SLASH = (225, 234, 242)


def path(*parts):
    return os.path.join(ROOT, *parts)


def frame(sheet, col, row, size=64):
    img = Image.open(path("sprites", "characters", *sheet)).convert("RGBA")
    return img.crop((col * size, row * size, (col + 1) * size, (row + 1) * size))


def recolor_blade(img, color):
    """Pinta la espada y la estela del color de un arma."""
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            shade = BLADE.get((r, g, b))
            if shade is not None:
                k = 0.35 + 0.85 * shade
                px[x, y] = tuple(min(255, int(c * k)) for c in color) + (a,)
            elif (r, g, b) == SLASH:
                px[x, y] = tuple(min(255, int(c * 0.6 + 255 * 0.4)) for c in color) + (a,)
    return img


def scale_pixel(img, factor):
    return img.resize((img.width * factor, img.height * factor), Image.NEAREST)


def glow(img, color, radius):
    """Halo de un color alrededor de la silueta de `img`."""
    alpha = img.getchannel("A").filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(radius))
    halo = Image.new("RGBA", img.size, color)
    halo.putalpha(alpha.point(lambda v: int(v * 0.9)))
    return halo


def text_layer(text, size, fill_top, fill_bottom, outline, outline_w, shadow):
    font = ImageFont.truetype(FONT, size)
    bbox = font.getbbox(text)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    pad = outline_w * 2 + 24
    layer = Image.new("RGBA", (tw + pad * 2, th + pad * 2), (0, 0, 0, 0))
    origin = (pad - bbox[0], pad - bbox[1])

    # Sombra desplazada y difuminada.
    sh = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((origin[0] + 8, origin[1] + 10), text, font=font, fill=shadow,
                            stroke_width=outline_w, stroke_fill=shadow)
    layer.alpha_composite(sh.filter(ImageFilter.GaussianBlur(6)))

    # Contorno.
    ImageDraw.Draw(layer).text(origin, text, font=font, fill=outline, stroke_width=outline_w, stroke_fill=outline)

    # Relleno en degradado vertical.
    mask = Image.new("L", layer.size, 0)
    ImageDraw.Draw(mask).text(origin, text, font=font, fill=255)
    grad = Image.new("RGBA", layer.size)
    gd = ImageDraw.Draw(grad)
    top, bottom = origin[1] + bbox[1], origin[1] + bbox[3]
    for y in range(layer.height):
        t = min(1.0, max(0.0, (y - top) / max(1, bottom - top)))
        c = tuple(int(fill_top[i] + (fill_bottom[i] - fill_top[i]) * t) for i in range(3))
        gd.line([(0, y), (layer.width, y)], fill=c + (255,))
    layer.paste(grad, (0, 0), mask)
    # Brillo en la mitad superior de las letras.
    shine = Image.new("RGBA", layer.size, (255, 255, 255, 0))
    sd = ImageDraw.Draw(shine)
    mid = top + (bottom - top) * 0.42
    for y in range(int(top), int(mid)):
        sd.line([(0, y), (layer.width, y)], fill=(255, 255, 255, 50))
    shine.putalpha(Image.composite(shine.getchannel("A"), Image.new("L", layer.size, 0), mask))
    layer.alpha_composite(shine)
    return layer


def main():
    # Fondo: el portal de una captura real, recortado sin el HUD,
    # ampliado, desenfocado y oscurecido.
    shot = Image.open(path("docs", "screenshots", "portal.jpg")).convert("RGB")
    crop = shot.crop((300, 110, 860, 390))
    bg = crop.resize((W, int(W * crop.height / crop.width)), Image.LANCZOS)
    top = (bg.height - H) // 2
    bg = bg.crop((0, top, W, top + H)).filter(ImageFilter.GaussianBlur(4))
    bg = ImageEnhance.Brightness(bg).enhance(0.6).convert("RGBA")

    # Degradado: oscuro a la izquierda (texto) y tinte morado/rojo.
    shade = Image.new("RGBA", (W, H))
    sd = ImageDraw.Draw(shade)
    for x in range(W):
        t = x / W
        a = int(235 * (1 - t) ** 1.6)
        sd.line([(x, 0), (x, H)], fill=(10, 4, 18, a))
    bg.alpha_composite(shade)
    tint = Image.new("RGBA", (W, H), (120, 30, 150, 50))
    bg.alpha_composite(tint)

    # Vineta.
    vig = Image.new("L", (W, H), 0)
    ImageDraw.Draw(vig).ellipse((-W * 0.25, -H * 0.4, W * 1.25, H * 1.4), fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(120))
    dark = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    dark.putalpha(vig.point(lambda v: 255 - v))
    bg.alpha_composite(dark)

    # Jefe al fondo a la derecha: la Reina Carnivora, enorme y en penumbra.
    queen = scale_pixel(frame(("plantmob", "plant1_idle.png"), 0, 0), 10)
    queen = ImageEnhance.Brightness(queen).enhance(0.7)
    qx, qy = W - queen.width + 70, -110
    bg.alpha_composite(glow(queen, (90, 255, 120, 255), 18), (qx, qy))
    bg.alpha_composite(queen, (qx, qy))

    # Heroe en primer plano, en pleno tajo con la Hoja Arcana.
    arcane = (204, 115, 255)
    hero = recolor_blade(frame(("main", "main_idle_attack.png"), 4, 2), arcane)
    hero = scale_pixel(hero, 9)
    hx, hy = W - hero.width - 150, H - hero.height + 80
    bg.alpha_composite(glow(hero, arcane + (255,), 22), (hx, hy))
    bg.alpha_composite(hero, (hx, hy))

    # Chispas moradas alrededor del heroe.
    sparks = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sp = ImageDraw.Draw(sparks)
    import random
    rnd = random.Random(3)
    for _ in range(60):
        x = rnd.randint(hx - 40, hx + hero.width + 40)
        y = rnd.randint(hy + 40, H)
        s = rnd.choice((4, 6, 8))
        sp.rectangle((x, y, x + s, y + s), fill=arcane + (rnd.randint(120, 230),))
    bg.alpha_composite(sparks.filter(ImageFilter.GaussianBlur(0.6)))

    # Rango SSS.
    rank = text_layer("SSS", 120, (255, 140, 250), (190, 40, 210), (25, 5, 30, 255), 9, (0, 0, 0, 200))
    rank = rank.rotate(-8, resample=Image.BICUBIC, expand=True)
    bg.alpha_composite(rank, (W - rank.width - 10, H - rank.height + 30))

    # Logo y textos.
    title = text_layer("HITDASH", 168, (255, 236, 150), (255, 120, 40), (30, 8, 10, 255), 12, (0, 0, 0, 220))
    bg.alpha_composite(title, (34, 120))

    sub_font = ImageFont.truetype(FONT, 34)
    tag_font = ImageFont.truetype(FONT, 25)
    d = ImageDraw.Draw(bg)
    d.text((72, 338), "Roguelite de acción en pixel art", font=sub_font, fill=(245, 235, 255),
           stroke_width=3, stroke_fill=(15, 5, 20))

    # Etiquetas.
    tags = ["Dash Strike", "Combos SSS", "Jefes", "6 armas", "Salas"]
    x = 72
    for tag in tags:
        bbox = tag_font.getbbox(tag)
        w = bbox[2] - bbox[0] + 30
        d.rounded_rectangle((x, 404, x + w, 450), radius=12, fill=(40, 16, 56, 220), outline=(220, 140, 255), width=2)
        d.text((x + 15, 408), tag, font=tag_font, fill=(255, 225, 255))
        x += w + 12

    d.text((74, 560), "Hecho con Godot 4", font=tag_font, fill=(200, 185, 215), stroke_width=2, stroke_fill=(10, 4, 14))

    out = path("docs", "thumbnail.png")
    bg.convert("RGB").save(out, optimize=True)
    print("ok", out)


if __name__ == "__main__":
    main()
