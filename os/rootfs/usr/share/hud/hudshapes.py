"""Shape geometry shared by hudctl, hud-center and hud-icons."""
import math


def tri_bars(cx, cy, r, t, d, gap=4, up=True):
    """The "tri" tile: three bars set around a triangular opening.

    Returns three outlines (lists of x,y points). The first is the level
    bar, used as the title plate; the other two are the slanted sides.

      r    size of the opening (centre to corner)
      t    thickness of the bars
      d    centre to each flattened outer corner
      gap  space between neighbouring bars
      up   True: opening points up, title bar at the bottom. False: flipped.
    """
    s3 = math.sqrt(3)
    ri = r / 2
    p1 = (gap - ri * s3, ri)
    p2 = (-d * s3 / 2 + gap / 4, d / 2 + gap * s3 / 4)
    p3 = (((ri + t) / 2 - d) * 2 / s3, ri + t)
    base = [p1, p2, p3, (-p3[0], p3[1]), (-p2[0], p2[1]), (-p1[0], p1[1])]
    bars = []
    for k in range(3):
        a = math.radians(120 * k)
        c, s = math.cos(a), math.sin(a)
        pts = [(x * c - y * s, x * s + y * c) for x, y in base]
        if not up:
            pts = [(x, -y) for x, y in pts]
        bars.append([(cx + x, cy + y) for x, y in pts])
    return bars


def tri_size(r, t, d):
    """Width and height of a tri tile, without any margin."""
    return math.sqrt(3) * d, d + r / 2 + t
