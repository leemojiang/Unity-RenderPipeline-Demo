"""Generate small matching albedo and height textures for the URP parallax demo.

Uses only Python's standard library. Run with:
    python GenerateParallaxTextures.py <output-directory>
"""

from pathlib import Path
import math
import struct
import sys
import zlib


def write_png(path: Path, width: int, height: int, pixels: bytearray) -> None:
    raw = b"".join(
        b"\x00" + bytes(pixels[y * width * 4 : (y + 1) * width * 4])
        for y in range(height)
    )

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">2I5B", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def generate(output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    size, tile = 256, 64
    albedo = bytearray()
    heightmap = bytearray()
    palettes = [(166, 102, 68), (185, 126, 82), (147, 91, 64), (198, 142, 93)]

    for y in range(size):
        for x in range(size):
            lx, ly = x % tile, y % tile
            edge = min(lx, tile - 1 - lx, ly, tile - 1 - ly)

            # White is raised stone, dark is recessed grout.
            h = max(0.04, min(0.88, 0.08 + 0.80 * min(edge / 7.0, 1.0)))
            if edge > 7:
                h += 0.012 * math.sin(x * 0.22) * math.sin(y * 0.19)
            h8 = max(0, min(255, round(h * 255)))
            heightmap.extend((h8, h8, h8, 255))

            tile_id = ((x // tile) + 2 * (y // tile)) % len(palettes)
            base = palettes[tile_id]
            shade = 0.46 if edge < 2 else (0.72 + 0.04 * min(edge - 2, 5) if edge < 7 else 1.0)
            grain = 1.0 + 0.035 * math.sin(x * 0.31 + y * 0.17) * math.sin(y * 0.27)
            rgb = [max(0, min(255, round(c * shade * grain))) for c in base]
            albedo.extend((*rgb, 255))

    write_png(output / "ParallaxTiles_Albedo.png", size, size, albedo)
    write_png(output / "ParallaxTiles_Height.png", size, size, heightmap)


if __name__ == "__main__":
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("Textures")
    generate(target)
