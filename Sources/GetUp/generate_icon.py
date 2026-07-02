import struct
import zlib
import math
import os

def create_png_rgba(width, height, pixels):
    """Create PNG from a flat list of (r,g,b,a) tuples, top-to-bottom."""
    raw = b""
    for y in range(height):
        raw += b"\x00"  # filter none
        for x in range(width):
            r, g, b, a = pixels[y * width + x]
            raw += struct.pack("BBBB", r, g, b, a)

    def chunk(ctype, data):
        c = ctype + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")


def draw_icon(size):
    """Draw a coffee-cup style icon: warm brown rounded rect with 'UP'."""
    cx, cy = size / 2, size / 2
    r = size * 0.44
    pixels = [(0, 0, 0, 0)] * (size * size)

    bg_r, bg_g, bg_b = 0xF5, 0xA6, 0x23  # warm orange-brown
    text_r, text_g, text_b = 255, 255, 255

    # Simple chair shape: horizontal bar at bottom, vertical back on left
    bar_h = int(size * 0.14)
    bar_w = int(size * 0.64)
    bar_y0 = int(size * 0.62)
    bar_x0 = int(size * 0.18)

    back_w = int(size * 0.14)
    back_h = int(size * 0.52)
    back_x0 = int(size * 0.18)
    back_y0 = int(size * 0.10)

    for y in range(size):
        for x in range(size):
            px = x + 0.5
            py = y + 0.5

            on = False
            # seat (horizontal bar)
            if bar_x0 <= px <= bar_x0 + bar_w and bar_y0 <= py <= bar_y0 + bar_h:
                on = True
            # backrest (vertical bar)
            if back_x0 <= px <= back_x0 + back_w and back_y0 <= py <= back_y0 + back_h:
                on = True

            if on:
                # rounded corners effect: skip corners of rectangles
                left = px - bar_x0
                right = (bar_x0 + bar_w) - px
                bottom = (bar_y0 + bar_h) - py
                top_seat = py - bar_y0
                left2 = px - back_x0
                right2 = (back_x0 + back_w) - px
                top2 = py - back_y0
                bottom2 = (back_y0 + back_h) - py

                corner = min(r * 0.06, size * 0.06)

                in_seat = bar_x0 <= px <= bar_x0 + bar_w and bar_y0 <= py <= bar_y0 + bar_h
                in_back = back_x0 <= px <= back_x0 + back_w and back_y0 <= py <= back_y0 + back_h

                seat_corner = False
                if in_seat:
                    if left < corner and top_seat < corner:
                        if math.hypot(left - corner, top_seat - corner) > corner:
                            seat_corner = True
                    if right < corner and top_seat < corner:
                        if math.hypot(right - corner, top_seat - corner) > corner:
                            seat_corner = True

                back_corner = False
                if in_back:
                    if left2 < corner and top2 < corner:
                        if math.hypot(left2 - corner, top2 - corner) > corner:
                            back_corner = True
                    if right2 < corner and top2 < corner:
                        if math.hypot(right2 - corner, top2 - corner) > corner:
                            back_corner = True

                if not seat_corner and not back_corner:
                    pixels[y * size + x] = (bg_r, bg_g, bg_b, 255)

    return create_png_rgba(size, size, pixels)


# macOS icon sizes required for iconset
sizes = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}

iconset_dir = os.path.join(os.path.dirname(__file__), "icon.iconset")
os.makedirs(iconset_dir, exist_ok=True)

for filename, size in sizes.items():
    path = os.path.join(iconset_dir, filename)
    png_data = draw_icon(size)
    with open(path, "wb") as f:
        f.write(png_data)
    print(f"  {filename} ({size}x{size})")

print("\nIcons generated. Run: iconutil -c icns icon.iconset")
