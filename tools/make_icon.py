"""아이콘을 코드로 그린다. 게임 화면과 같은 색 규칙을 쓴다."""
import colorsys
import os
from PIL import Image, ImageDraw

SS = 4                      # 4배로 그린 뒤 줄여서 계단을 없앤다
SIZE = 1024
S = SIZE * SS


def hsl(h, s, l):
    r, g, b = colorsys.hls_to_rgb(h / 360.0, l, s)
    return int(r * 255), int(g * 255), int(b * 255)


def lerp(a, b, k):
    return tuple(int(x + (y - x) * k) for x, y in zip(a, b))


def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius, fill=255)
    return m


def main():
    out = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    # 배경 그라디언트 (게임 배경과 같은 색)
    top, mid, bottom = (107, 205, 255), (171, 163, 255), (255, 198, 176)
    bg = Image.new("RGB", (S, S))
    px = bg.load()
    for y in range(S):
        k = y / (S - 1)
        c = lerp(top, mid, k / 0.55) if k < 0.55 else lerp(mid, bottom, (k - 0.55) / 0.45)
        for x in range(S):
            px[x, y] = c

    card = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    card.paste(bg, (0, 0), rounded_mask(S, int(S * 0.225)))

    d = ImageDraw.Draw(card)

    # 쌓인 층. 아래에서 위로 색상환을 돌린다
    layers = [
        (28, 1.00), (70, 0.94), (140, 0.88), (280, 0.82),
    ]
    base_w = int(S * 0.60)
    h = int(S * 0.098)
    gap = int(S * 0.016)
    cx = S // 2
    y = int(S * 0.80) - h
    offsets = [0, -0.022, 0.018, -0.012]

    for (hue, wk), off in zip(layers, offsets):
        w = int(base_w * wk)
        x0 = cx - w // 2 + int(S * off)
        col = hsl(hue, 0.82, 0.62)
        d.rounded_rectangle([x0, y, x0 + w, y + h], int(h * 0.3), fill=col)
        # 윗면 하이라이트
        d.rounded_rectangle([x0, y, x0 + w, y + int(h * 0.34)], int(h * 0.3),
                            fill=lerp(col, (255, 255, 255), 0.38))
        y -= h + gap

    # 노즐
    nz_w, nz_h = int(S * 0.26), int(S * 0.115)
    nx0 = cx - nz_w // 2
    ny0 = int(S * 0.135)
    d.rounded_rectangle([nx0, ny0, nx0 + nz_w, ny0 + nz_h], int(S * 0.02),
                        fill=(118, 124, 140))
    d.rounded_rectangle([nx0, ny0, nx0 + nz_w, ny0 + int(nz_h * 0.38)], int(S * 0.02),
                        fill=(150, 156, 172))
    tip = int(S * 0.07)
    d.polygon([
        (cx - nz_w * 0.26, ny0 + nz_h),
        (cx + nz_w * 0.26, ny0 + nz_h),
        (cx + nz_w * 0.09, ny0 + nz_h + tip),
        (cx - nz_w * 0.09, ny0 + nz_h + tip),
    ], fill=(92, 98, 114))

    # 짜여 나오는 필라멘트
    fy0 = ny0 + nz_h + tip
    fy1 = y + h + gap + int(h * 0.35)
    d.rounded_rectangle([cx - int(S * 0.022), fy0, cx + int(S * 0.022), fy1],
                        int(S * 0.022), fill=(255, 206, 56))

    icon = card.resize((SIZE, SIZE), Image.LANCZOS)
    icon.save(os.path.join(out, "icon.png"))
    print("icon.png 저장")

    # macOS .icns 용 묶음
    iconset = os.path.join(out, "icon.iconset")
    os.makedirs(iconset, exist_ok=True)
    for base in (16, 32, 128, 256, 512):
        icon.resize((base, base), Image.LANCZOS).save(
            os.path.join(iconset, f"icon_{base}x{base}.png"))
        icon.resize((base * 2, base * 2), Image.LANCZOS).save(
            os.path.join(iconset, f"icon_{base}x{base}@2x.png"))
    print("icon.iconset 저장")

    icon.save(os.path.join(out, "icon.ico"),
              sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print("icon.ico 저장")

    strip = Image.new("RGBA", (16 + 32 + 64 + 128 + 40, 128), (255, 255, 255, 255))
    x = 0
    for base in (16, 32, 64, 128):
        strip.paste(icon.resize((base, base), Image.LANCZOS), (x, 128 - base))
        x += base + 10
    strip.save(os.path.join(out, "tools", "icon-sizes.png"))
    print("tools/icon-sizes.png 저장")


if __name__ == "__main__":
    main()
