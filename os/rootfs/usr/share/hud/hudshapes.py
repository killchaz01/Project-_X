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


# ------------------------------------------------------------ 3-D blocks
S3 = math.sqrt(3)


def block_geometry(r, t, gap):
    """Numbers shared by tri_blocks and the code that lays the blocks out.

    The opening is an equilateral triangle with corners r from its centre.
    Each side of it gets a straight beam t thick, gap away from it; the two
    slanted beams stand on the level one and end in square cuts side by
    side at the top.
    """
    ci = r / 2 + gap / 2                 # centre to a beam's inner face
    co = ci + t                          # centre to a beam's outer face
    y_top = -(r + t * 0.15)              # where the slanted beams are cut
    y_foot = r / 2 - gap / 2             # where they stand
    y_bar = r / 2 + gap / 2              # top of the level beam
    half = (2 * co + y_foot) / S3        # half the level beam's length
    return ci, co, y_top, y_foot, y_bar, half


def tri_blocks(cx, cy, r, t, gap=3, up=True):
    """Front faces of the three beams of the 3-D tri mark, as point lists.

    With up=False the mark is flipped top to bottom (the level beam on top).
    """
    ci, co, y_top, y_foot, y_bar, half = block_geometry(r, t, gap)

    def on(c, y):                        # x where the left-side line c meets height y
        return -(2 * c + y) / S3

    left = [(on(co, y_top), y_top), (-gap / 2, y_top), (-gap / 2, -2 * ci + S3 * gap / 2),
            (on(ci, y_foot), y_foot), (on(co, y_foot), y_foot)]
    right = [(-x, y) for x, y in reversed(left)]
    level = [(-half, y_bar), (half, y_bar), (half, y_bar + t), (-half, y_bar + t)]
    flip = 1 if up else -1
    return [[(cx + x, cy + flip * y) for x, y in poly] for poly in (left, right, level)]


def block_faces(polys, ex, ey):
    """Turn front faces into visible 3-D faces seen from the front.

    Each face is pushed back by (ex, ey) on screen. Returns a list of
    (kind, points) with kind "front", "top" or "side": every "top" and
    "side" face first, then the fronts, so drawing in order hides the right
    parts.
    """
    backs, fronts = [], []
    for poly in polys:
        mx = sum(x for x, _ in poly) / len(poly)
        my = sum(y for _, y in poly) / len(poly)
        for (x0, y0), (x1, y1) in zip(poly, poly[1:] + poly[:1]):
            nx, ny = y1 - y0, x0 - x1             # a normal to the edge...
            if nx * ((x0 + x1) / 2 - mx) + ny * ((y0 + y1) / 2 - my) < 0:
                nx, ny = -nx, -ny                 # ...turned to face outwards
            if nx * ex + ny * ey > 1e-6:
                kind = "top" if -ny > abs(nx) * 0.5 else "side"
                backs.append((kind, [(x0, y0), (x1, y1), (x1 + ex, y1 + ey), (x0 + ex, y0 + ey)]))
        fronts.append(("front", poly))
    return backs + fronts
