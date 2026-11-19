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


def tri_blocks(cx, cy, r, t, gap=2.5, up=True):
    """Front faces of the three beams of the 3-D tri mark.

    The opening is an equilateral triangle with corners r from its centre;
    each beam is t thick and gap away from it. As in the reference sketch,
    the two slanted beams end in square cuts side by side at the top; the
    right one stands on the level beam, which runs out to its outer edge;
    the left one runs down past the level beam's left end, which stops
    short against it.

    Returns (faces, opening centre). The mark is centred on cx across;
    with up=False it is flipped top to bottom.
    """
    ci = r / 2 + gap / 2                 # centre to a beam's inner face
    co = ci + t                          # centre to a beam's outer face
    y_top = -(r + t * 0.2)               # where the slanted beams are cut
    y_bar = r / 2 + gap / 2              # top of the level beam
    y_low = y_bar + t                    # bottom of the level beam
    y_foot = y_bar - gap                 # where the right beam stands

    def on(c, y):                        # x on the left-side line c at height y
        return -(2 * c + y) / S3

    apex = -2 * ci + S3 * gap / 2        # inner faces meet the centre line here
    left = [(on(co, y_top), y_top), (-gap / 2, y_top), (-gap / 2, apex),
            (on(ci, y_low), y_low), (on(co, y_low), y_low)]
    right = [(-on(co, y_top), y_top), (-on(co, y_foot), y_foot), (-on(ci, y_foot), y_foot),
             (gap / 2, apex), (gap / 2, y_top)]
    level = [(on(ci - gap, y_bar), y_bar), (-on(co, y_foot), y_bar),
             (-on(co, y_foot), y_low), (on(ci - gap, y_low), y_low)]
    polys = [left, right, level]
    xs = [x for poly in polys for x, _ in poly]
    shift = -(min(xs) + max(xs)) / 2
    flip = 1 if up else -1
    faces = [[(cx + shift + x, cy + flip * y) for x, y in poly] for poly in polys]
    return faces, (cx + shift, cy)


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
