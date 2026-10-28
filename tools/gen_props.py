"""Genera el pixel art de los obstaculos de las salas (columnas, cajas,
barriles, vasijas, antorchas) y la textura de luz.

Todo se dibuja pixel a pixel con una semilla fija, asi que el resultado es
siempre el mismo y libre de derechos. Para regenerarlo:

    python tools/gen_props.py

Escribe PNGs en sprites/props/. En el juego se escalan x3 con filtro nearest.
"""
import math
import os
import random

from PIL import Image

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sprites", "props")

T = (0, 0, 0, 0)

# Paleta por escenario: contorno, sombra profunda, sombra, medio, luz, brillo,
# acento (musgo / oro / runas) y acento claro.
PALETTES = {
    "dungeon": dict(
        outline=(22, 18, 28), deep=(52, 50, 62), dark=(74, 72, 86), mid=(104, 102, 118),
        light=(138, 136, 150), shine=(172, 170, 184), accent=(70, 96, 58), accent2=(98, 128, 74),
    ),
    "garden": dict(
        outline=(18, 26, 18), deep=(52, 62, 50), dark=(76, 88, 70), mid=(104, 116, 96),
        light=(134, 146, 122), shine=(164, 176, 150), accent=(62, 128, 52), accent2=(112, 180, 70),
    ),
    "castle": dict(
        outline=(30, 10, 12), deep=(78, 26, 28), dark=(110, 38, 38), mid=(142, 54, 50),
        light=(176, 76, 66), shine=(206, 108, 90), accent=(196, 150, 60), accent2=(240, 202, 104),
    ),
    "abyss": dict(
        outline=(10, 6, 18), deep=(28, 20, 44), dark=(42, 30, 64), mid=(58, 44, 88),
        light=(80, 64, 116), shine=(106, 88, 148), accent=(176, 92, 255), accent2=(232, 186, 255),
    ),
}


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[T for _ in range(w)] for _ in range(h)]

    def set(self, x, y, color):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = color if len(color) == 4 else (*color, 255)

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return T

    def rect(self, x0, y0, x1, y1, color):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, color)

    def outline(self, color):
        """Contorno de 1 px alrededor de todo lo opaco."""
        solid = [[self.px[y][x][3] > 0 for x in range(self.w)] for y in range(self.h)]
        for y in range(self.h):
            for x in range(self.w):
                if solid[y][x]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and solid[ny][nx]:
                        self.set(x, y, color)
                        break

    def save(self, name):
        img = Image.new("RGBA", (self.w, self.h))
        img.putdata([c for row in self.px for c in row])
        os.makedirs(OUT_DIR, exist_ok=True)
        path = os.path.join(OUT_DIR, name + ".png")
        img.save(path)
        print("ok", path)


def shade_column(x, x0, x1, p):
    """Color de una columna vertical de un cilindro iluminado desde la izquierda."""
    t = (x - x0) / max(1, x1 - x0)
    if t < 0.12:
        return p["light"]
    if t < 0.3:
        return p["shine"] if t < 0.2 else p["light"]
    if t < 0.68:
        return p["mid"]
    if t < 0.86:
        return p["dark"]
    return p["deep"]


# --- Columnas ---------------------------------------------------------------

def pillar(style, broken, seed):
    rnd = random.Random(seed)
    p = PALETTES[style]
    W, H = 24, 50
    c = Canvas(W, H)
    sx0, sx1 = 6, 17          # fuste
    base_top = H - 7
    top = rnd.randint(16, 24) if broken else 8

    # Fuste con sombreado cilindrico.
    for y in range(top, base_top):
        for x in range(sx0, sx1 + 1):
            c.set(x, y, shade_column(x, sx0, sx1, p))

    if style == "castle":
        # Ladrillos: juntas horizontales y verticales alternas.
        for y in range(top, base_top):
            row = (y - top) // 4
            if (y - top) % 4 == 3:
                for x in range(sx0, sx1 + 1):
                    c.set(x, y, p["deep"])
            else:
                for x in range(sx0, sx1 + 1):
                    if (x - sx0 + (2 if row % 2 else 0)) % 6 == 5:
                        c.set(x, y, p["deep"])
        # Bandas doradas.
        for band in (top + 3, base_top - 4):
            if band > top:
                for x in range(sx0, sx1 + 1):
                    c.set(x, band, p["accent"] if x > sx0 + 2 else p["accent2"])
                    c.set(x, band + 1, p["accent"] if x < sx1 - 2 else p["deep"])
    else:
        # Sillares de piedra.
        for y in range(top + 5, base_top, 7):
            for x in range(sx0, sx1 + 1):
                c.set(x, y, p["deep"])
            jx = sx0 + (3 if (y // 7) % 2 else 7)
            for yy in range(y + 1, min(y + 7, base_top)):
                c.set(jx, yy, p["dark"])

    # Grietas (camino aleatorio de pixeles oscuros).
    for _ in range(2 if style != "abyss" else 1):
        x, y = rnd.randint(sx0 + 2, sx1 - 2), rnd.randint(top + 4, base_top - 6)
        for _ in range(rnd.randint(4, 8)):
            c.set(x, y, p["outline"])
            if rnd.random() < 0.5:
                c.set(x + 1, y, p["deep"])
            x += rnd.choice((-1, 0, 1))
            y += 1

    if style == "abyss":
        # Runas brillantes en el centro del fuste.
        cx = (sx0 + sx1) // 2
        for y in range(top + 4, base_top - 3, 6):
            glyph = rnd.choice([
                [(0, 0), (0, 1), (0, 2), (-1, 1), (1, 1)],
                [(-1, 0), (1, 0), (0, 1), (-1, 2), (1, 2)],
                [(0, 0), (-1, 1), (1, 1), (0, 2), (0, 3)],
            ])
            for dx, dy in glyph:
                c.set(cx + dx, y + dy, p["accent2"] if dy == 1 else p["accent"])

    # Capitel (o rotura).
    if broken:
        # Borde superior irregular, iluminado.
        for x in range(sx0, sx1 + 1):
            cut = top + rnd.choice((0, 0, 1, 2, 3))
            for y in range(top, cut):
                c.set(x, y, T)
            c.set(x, cut, p["shine"] if x < sx1 - 3 else p["light"])
    else:
        for y in range(top - 6, top):
            for x in range(3, W - 3):
                c.set(x, y, p["mid"])
        for x in range(3, W - 3):
            c.set(x, top - 6, p["shine"])
            c.set(x, top - 5, p["light"])
            c.set(x, top - 1, p["deep"])
        for x in range(4, W - 4):
            c.set(x, top - 3, p["dark"])
        for y in range(top - 6, top):
            c.set(3, y, p["light"])
            c.set(W - 4, y, p["deep"])
        if style == "castle":
            for x in range(3, W - 3):
                c.set(x, top - 3, p["accent"])
            c.set(W // 2, top - 3, p["accent2"])
        if style == "abyss":
            # Cristal sobre el capitel.
            cx = W // 2
            for dy, half in enumerate((0, 1, 1, 2, 2, 2)):
                for dx in range(-half, half + 1):
                    c.set(cx + dx, top - 12 + dy, p["accent2"] if dx < 0 else p["accent"])

    # Basa escalonada.
    for y in range(base_top, H - 1):
        x0, x1 = (4, W - 5) if y < base_top + 3 else (2, W - 3)
        for x in range(x0, x1 + 1):
            c.set(x, y, shade_column(x, x0, x1, p))
    for x in range(2, W - 2):
        c.set(x, base_top + 3, p["shine"] if x < W // 2 else p["light"])
    for x in range(4, W - 4):
        c.set(x, base_top, p["light"])

    # Musgo y enredaderas.
    moss = {"dungeon": 0.25, "garden": 1.0, "castle": 0.0, "abyss": 0.0}[style]
    if moss > 0:
        for x in range(2, W - 2):
            for y in range(H):
                col = c.get(x, y)
                above = c.get(x, y - 1)
                if col[3] and not above[3] and rnd.random() < 0.6 * moss:
                    c.set(x, y, p["accent2"] if rnd.random() < 0.5 else p["accent"])
                    if rnd.random() < 0.5 * moss:
                        c.set(x, y + 1, p["accent"])
        if style == "garden":
            for _ in range(3):
                x = rnd.randint(sx0, sx1)
                start = top if not broken else top + 2
                length = rnd.randint(8, 22)
                for y in range(start, min(start + length, base_top)):
                    c.set(x, y, p["accent"])
                    if rnd.random() < 0.3:
                        c.set(x + rnd.choice((-1, 1)), y, p["accent2"])
                    if rnd.random() < 0.15:
                        x = max(sx0, min(sx1, x + rnd.choice((-1, 1))))

    if broken:
        # Cascotes al pie.
        for bx in (rnd.randint(0, 3), rnd.randint(W - 6, W - 4)):
            by = H - 4
            c.rect(bx, by, bx + 2, by + 1, p["mid"])
            c.set(bx, by, p["light"])
            c.set(bx + 2, by + 1, p["dark"])

    c.outline(p["outline"])
    c.save("pillar_%s_%s" % (style, "broken" if broken else "intact"))


# --- Rompibles -------------------------------------------------------------

def crate():
    c = Canvas(18, 18)
    wood = dict(deep=(70, 38, 20), dark=(104, 60, 30), mid=(142, 88, 44), light=(178, 120, 64), shine=(206, 152, 92))
    # Cara superior.
    for y in range(1, 5):
        for x in range(1, 17):
            c.set(x, y, wood["shine"] if (x + y) % 7 else wood["light"])
    for x in range(1, 17):
        c.set(x, 4, wood["light"])
    # Frente con tablas horizontales.
    for y in range(5, 17):
        for x in range(1, 17):
            col = wood["mid"] if (y - 5) % 4 != 3 else wood["dark"]
            if x > 13:
                col = wood["dark"]
            c.set(x, y, col)
    # Marco y refuerzo en diagonal.
    for y in range(5, 17):
        c.set(1, y, wood["deep"])
        c.set(2, y, wood["light"])
        c.set(15, y, wood["deep"])
        c.set(16, y, wood["deep"])
    for x in range(1, 17):
        c.set(x, 5, wood["deep"])
        c.set(x, 16, wood["deep"])
    for i in range(10):
        c.set(3 + i, 15 - i, wood["light"])
        c.set(4 + i, 15 - i, wood["dark"])
    # Clavos.
    for x, y in ((2, 6), (14, 6), (2, 15), (14, 15)):
        c.set(x, y, (200, 200, 190))
    c.outline((26, 14, 8))
    c.save("crate")


def barrel():
    c = Canvas(16, 20)
    wood = dict(deep=(66, 34, 18), dark=(98, 54, 28), mid=(134, 80, 40), light=(170, 110, 58), shine=(198, 140, 82))
    metal = dict(dark=(60, 62, 70), mid=(110, 112, 124), light=(170, 172, 184))
    for y in range(3, 19):
        bulge = 1 if 6 <= y <= 15 else 0
        x0, x1 = 2 - bulge, 13 + bulge
        for x in range(x0, x1 + 1):
            col = shade_column(x, x0, x1, wood)
            if (x - x0) % 3 == 2:
                col = wood["deep"] if col != wood["shine"] else wood["dark"]
            c.set(x, y, col)
    # Tapa eliptica.
    for y in range(0, 4):
        half = (5, 6, 6, 5)[y]
        for x in range(8 - half, 8 + half):
            c.set(x, y + 1, wood["light"] if y in (1, 2) else wood["dark"])
    for x in range(4, 12):
        c.set(x, 2, wood["shine"])
    # Aros metalicos.
    for band in (5, 15):
        for x in range(0, 16):
            if c.get(x, band)[3]:
                c.set(x, band, metal["light"] if x < 6 else metal["mid"])
                c.set(x, band + 1, metal["dark"])
    c.outline((24, 12, 6))
    c.save("barrel")


def pot():
    c = Canvas(14, 15)
    clay = dict(deep=(110, 50, 30), dark=(150, 72, 40), mid=(190, 100, 56), light=(222, 140, 84), shine=(244, 182, 128))
    for y in range(3, 14):
        r = [3, 4, 5, 6, 6, 6, 6, 5, 5, 4, 3][y - 3]
        for x in range(7 - r, 7 + r):
            c.set(x, y, shade_column(x, 7 - r, 6 + r, clay))
    # Cuello y boca.
    c.rect(4, 1, 9, 2, clay["mid"])
    for x in range(4, 10):
        c.set(x, 1, clay["light"])
    c.rect(5, 0, 8, 0, clay["deep"])
    # Franja decorativa.
    for x in range(2, 12):
        if c.get(x, 8)[3]:
            c.set(x, 8, clay["deep"] if x % 2 else (236, 214, 160))
    c.set(4, 5, clay["shine"])
    c.set(4, 6, clay["shine"])
    c.outline((40, 18, 10))
    c.save("pot")


# --- Antorcha y luz ---------------------------------------------------------

def torch():
    """Soporte de pared con copa; la llama es de particulas en el juego."""
    c = Canvas(8, 10)
    iron = dict(dark=(40, 38, 44), mid=(84, 80, 90), light=(130, 126, 138))
    c.rect(2, 0, 5, 1, iron["mid"])        # copa
    c.set(2, 0, iron["light"])
    c.rect(3, 2, 4, 6, (110, 70, 36))       # mango de madera
    c.set(3, 2, (150, 100, 56))
    c.rect(1, 7, 6, 8, iron["mid"])         # anclaje
    c.set(1, 7, iron["light"])
    c.outline((16, 12, 14))
    c.save("torch")


def portal_gate():
    """Arco de piedra antiguo para el portal. Las runas van en una capa
    aparte (blanca) para tenirlas en el juego y hacerlas brillar."""
    W, H = 48, 58
    gate = Canvas(W, H)
    runes = Canvas(W, H)
    p = dict(outline=(16, 14, 22), deep=(40, 38, 50), dark=(60, 58, 72), mid=(86, 84, 100),
             light=(116, 114, 132), shine=(148, 146, 164))
    cx = W / 2
    outer_r, inner_r = 23.5, 14.5
    arch_cy = 24
    for y in range(H):
        for x in range(W):
            dx = x + 0.5 - cx
            if y < arch_cy:
                d = math.hypot(dx, (y + 0.5 - arch_cy) * 1.15)
                inside_outer = d <= outer_r
                inside_inner = d <= inner_r
            else:
                inside_outer = abs(dx) <= outer_r
                inside_inner = abs(dx) <= inner_r
            if inside_outer and not inside_inner and y < H - 4:
                # Sombreado: lado izquierdo iluminado.
                t = (dx + outer_r) / (2 * outer_r)
                col = p["light"] if t < 0.25 else p["mid"] if t < 0.7 else p["dark"]
                gate.set(x, y, col)
    # Dovelas del arco y sillares de las jambas.
    for y in range(H - 4):
        for x in range(W):
            if not gate.get(x, y)[3]:
                continue
            dx = x + 0.5 - cx
            if y < arch_cy:
                angle = math.degrees(math.atan2(arch_cy - y - 0.5, dx))
                if int(angle) % 22 in (0, 1):
                    gate.set(x, y, p["deep"])
            elif (y - arch_cy) % 8 == 7:
                gate.set(x, y, p["deep"])
    # Clave del arco mas grande.
    gate.rect(int(cx) - 3, 0, int(cx) + 2, 6, p["shine"])
    gate.rect(int(cx) - 2, 1, int(cx) + 1, 5, p["light"])
    runes.rect(int(cx) - 1, 2, int(cx), 4, (255, 255, 255))
    # Basas.
    for bx in (0, W - 10):
        gate.rect(bx, H - 6, bx + 9, H - 1, p["mid"])
        for x in range(bx, bx + 10):
            gate.set(x, H - 6, p["shine"])
            gate.set(x, H - 1, p["deep"])
    # Runas: columna de glifos en cada jamba y puntos por el arco.
    rnd = random.Random(5)
    glyphs = [
        [(0, 0), (0, 1), (0, 2), (1, 1)],
        [(0, 0), (1, 1), (0, 2), (1, 2)],
        [(1, 0), (0, 1), (1, 1), (1, 2)],
        [(0, 0), (1, 0), (0, 2), (1, 2), (0, 1)],
    ]
    for side_x in (int(cx - 19.5), int(cx + 17.5)):
        for gy in range(arch_cy + 2, H - 9, 6):
            for gx, gy2 in rnd.choice(glyphs):
                runes.set(side_x + gx, gy + gy2, (255, 255, 255))
    for i in range(7):
        a = math.radians(20 + i * 23.3)
        r = (outer_r + inner_r) / 2
        x = int(cx + math.cos(a) * r)
        y = int(arch_cy - math.sin(a) * r / 1.15)
        runes.set(x, y, (255, 255, 255))
        runes.set(x, y + 1, (255, 255, 255))
    gate.outline(p["outline"])
    gate.save("portal_gate")
    runes.save("portal_runes")


def light_texture():
    size = 128
    img = Image.new("RGBA", (size, size))
    data = []
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - size / 2 + 0.5, y - size / 2 + 0.5) / (size / 2)
            a = max(0.0, 1.0 - d) ** 2
            data.append((255, 255, 255, int(a * 255)))
    img.putdata(data)
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, "light.png")
    img.save(path)
    print("ok", path)


if __name__ == "__main__":
    seed = 11
    for style in PALETTES:
        for broken in (False, True):
            pillar(style, broken, seed)
            seed += 7
    crate()
    barrel()
    pot()
    torch()
    portal_gate()
    light_texture()
