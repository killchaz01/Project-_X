"""The station console: layout, live system data and clickable areas.

Used by hud-wallpaper (one still picture) and hud-console (the live
desktop layer, redrawn every second). build() returns SVG text plus a
list of hot spots, each a box in the 2560x1600 drawing with a command to
run when it is clicked.
"""
import calendar
import datetime
import os
import pwd
import socket
import subprocess
import time

W, H = 2560, 1600
MONTHS = "DEC NOV OCT SEP AUG JUL JUN MAY APR MAR FEB JAN".split()


# ------------------------------------------------------------------ data
class Probe:
    """Reads the machine's state. Cheap reads every call; slow ones less often."""

    def __init__(self):
        self.cpu_prev = None
        self.net_prev = None
        self.slow_at = 0
        self.failed, self.ip, self.iface, self.muted = 0, "", "", False

    @staticmethod
    def _read(path, default=""):
        try:
            with open(path) as f:
                return f.read()
        except OSError:
            return default

    def cpu(self):
        fields = self._read("/proc/stat").split("\n", 1)[0].split()[1:]
        if not fields:
            return 0.0
        nums = [int(x) for x in fields]
        idle, total = nums[3] + (nums[4] if len(nums) > 4 else 0), sum(nums)
        prev, self.cpu_prev = self.cpu_prev, (idle, total)
        if not prev:     # first call: fall back to the load average
            load = float((self._read("/proc/loadavg") or "0").split()[0])
            return min(100.0, 100.0 * load / (os.cpu_count() or 1))
        d_total = total - prev[1]
        return 0.0 if d_total <= 0 else 100.0 * (1 - (idle - prev[0]) / d_total)

    def memory(self):
        info = {}
        for line in self._read("/proc/meminfo").splitlines():
            k, _, rest = line.partition(":")
            info[k] = int(rest.split()[0]) if rest.split() else 0
        total = info.get("MemTotal", 1)
        return 100.0 * (total - info.get("MemAvailable", total)) / total

    @staticmethod
    def disk():
        try:
            st = os.statvfs("/")
        except OSError:
            return 0.0, 0.0
        total, free = st.f_blocks * st.f_frsize, st.f_bavail * st.f_frsize
        return (100.0 * (total - free) / total if total else 0.0), free / 1e9

    def network_rate(self):
        """Bytes per second through all non-loopback interfaces."""
        total = 0
        for line in self._read("/proc/net/dev").splitlines()[2:]:
            name, _, rest = line.partition(":")
            if name.strip() == "lo" or not rest.split():
                continue
            parts = rest.split()
            total += int(parts[0]) + int(parts[8])
        now = time.monotonic()
        prev, self.net_prev = self.net_prev, (total, now)
        if not prev or now <= prev[1]:
            return 0.0
        return max(0.0, (total - prev[0]) / (now - prev[1]))

    def battery(self):
        base = "/sys/class/power_supply"
        try:
            names = sorted(os.listdir(base))
        except OSError:
            return None
        for n in names:
            if n.startswith("BAT") and self._read(f"{base}/{n}/capacity").strip():
                return (int(self._read(f"{base}/{n}/capacity").strip()),
                        self._read(f"{base}/{n}/status").strip().upper())
        return None

    def default_route(self):
        for line in self._read("/proc/net/route").splitlines()[1:]:
            parts = line.split()
            if len(parts) > 2 and parts[1] == "00000000":
                return parts[0]
        return ""

    def slow(self):
        """Things that cost a process to find out: every 10 seconds."""
        if time.monotonic() < self.slow_at:
            return
        self.slow_at = time.monotonic() + 10
        try:
            out = subprocess.run(["systemctl", "--failed", "--no-legend", "--plain"],
                                 capture_output=True, text=True, timeout=3).stdout
            self.failed = len([ln for ln in out.splitlines() if ln.strip()])
        except (OSError, subprocess.SubprocessError):
            self.failed = 0
        self.iface = self.default_route()
        self.ip = ""
        if self.iface:
            # The address the machine would send from; nothing is sent.
            try:
                with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                    s.connect(("192.0.2.1", 9))
                    self.ip = s.getsockname()[0]
            except OSError:
                pass
        try:
            out = subprocess.run(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"],
                                 capture_output=True, text=True, timeout=3).stdout
            self.muted = "MUTED" in out
        except (OSError, subprocess.SubprocessError):
            self.muted = False

    def collect(self, v):
        self.slow()
        now = datetime.datetime.now()
        up = int(float((self._read("/proc/uptime") or "0").split()[0]))
        cpu, mem = self.cpu(), self.memory()
        disk_pct, disk_free = self.disk()
        rate = self.network_rate()
        bat = self.battery()
        warn, alert = v["warn"], v["alert"]
        online = bool(self.iface)

        units = [
            ("CORE", f"ONLINE - LOAD {cpu:4.1f}%  {os.cpu_count() or 1} CORES",
             alert if cpu > 90 else warn),
            ("STORE", f"MOUNTED - {disk_pct:.1f}% USED  {disk_free:.0f} GB FREE",
             alert if disk_pct > 95 else warn),
            ("LINK", f"ONLINE - {self.iface.upper()} {self.ip}" if online else "X OFFLINE X - NO SIGNAL",
             warn if online else alert),
        ]
        if bat:
            pct, status = bat
            word = {"CHARGING": "-CHARGING-", "DISCHARGING": "-DISCHARGING-",
                    "FULL": "FULL"}.get(status, status)
            units.append(("POWER", f"{word} {pct:.1f}%  BATTERY", alert if pct < 10 else warn))
        else:
            units.append(("POWER", f"MAINS - UPTIME {up // 86400}D {up % 86400 // 3600:02d}H",
                          warn))
        try:
            user = pwd.getpwuid(os.getuid()).pw_name
        except KeyError:
            user = "operator"
        return {
            "now": now, "colon": now.second % 2 == 0,
            "units": units,
            "busy": cpu > 60, "failed": self.failed, "online": online,
            "up_h": up // 3600, "up_m": up % 3600 // 60, "up_s": up % 60,
            "meters": [("CPU", cpu / 100), ("MEM", mem / 100), ("DSK", disk_pct / 100),
                       ("NET", min(1.0, rate / 2_000_000))],
            "muted": self.muted,
            "user": user.upper()[:12], "host": socket.gethostname().upper()[:16],
            "kernel": os.uname().release.upper()[:20],
        }


# --------------------------------------------------------------- drawing
class Canvas:
    def __init__(self, v):
        self.v = v
        self.out, self.spots = [], []
        self.SW = float(v.get("border_width", "2")) + 1
        self.BG, self.LINE, self.DIM = v["bg"], v["line"], v["line_dim"]
        self.MUTED, self.TITLE = v["muted"], v["title"]
        self.NAME = v.get("os_name", "HUD").upper()

    def add(self, s):
        self.out.append(s)

    def spot(self, x, y, w, h, command, tip):
        self.spots.append((x, y, w, h, command, tip))

    def text(self, x, y, string, colour=None, size=26, anchor="start", spacing=2):
        colour = colour or self.LINE
        string = (str(string).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))
        self.add(f'<text x="{x:.0f}" y="{y:.0f}" fill="{colour}" font-family="{self.v["font_ui"]}, sans-serif" '
                 f'font-size="{size}" font-weight="bold" letter-spacing="{spacing}" '
                 f'text-anchor="{anchor}">{string}</text>')

    def box(self, x, y, w, h, colour=None, width=None, fill="none"):
        self.add(f'<rect x="{x:.0f}" y="{y:.0f}" width="{w:.0f}" height="{h:.0f}" fill="{fill}" '
                 f'stroke="{colour or self.LINE}" stroke-width="{width or self.SW}"/>')

    def rect(self, x, y, w, h, fill=None):
        self.add(f'<rect x="{x:.0f}" y="{y:.0f}" width="{w:.0f}" height="{h:.0f}" fill="{fill or self.LINE}"/>')

    def plate(self, x, y, w, h, string, size=None, colour=None, anchor="start"):
        size = size or h * 0.62
        self.rect(x, y, w, h, colour or self.LINE)
        tx = {"start": x + h * 0.3, "middle": x + w / 2, "end": x + w - h * 0.3}[anchor]
        self.text(tx, y + h / 2 + size * 0.36, string, self.BG, size, anchor)

    def checker(self, x, y, size, n=3, colour=None):
        c = size / n
        for i in range(n):
            for j in range(n):
                if (i + j) % 2 == 0:
                    self.rect(x + i * c, y + j * c, c, c, colour)

    def split(self, x, y, size, flip=False, colour=None, lit=True):
        colour = colour or self.LINE
        a, b = x + size, y + size
        if lit:
            tri = f"M{x} {y}H{a}L{x} {b}Z" if flip else f"M{a} {y}V{b}H{x}Z"
            self.add(f'<path d="{tri}" fill="{colour}"/>')
        self.box(x, y, size, size, colour, 2)

    def octagon(self, x, y, w, h, c, colour=None, width=None, fill="none"):
        self.add(f'<path d="M{x + c} {y}H{x + w - c}L{x + w} {y + c}V{y + h - c}L{x + w - c} {y + h}'
                 f'H{x + c}L{x} {y + h - c}V{y + c}Z" fill="{fill}" stroke="{colour or self.LINE}" '
                 f'stroke-width="{width if width is not None else self.SW}"/>')

    def mark(self, x, y, size, colour, ground):
        t = size * 0.12
        self.rect(x, y, size, size, colour)
        self.rect(x + t, y + t, size - 2 * t, size - 2 * t, ground)
        a, b, m = x + size * 0.26, x + size * 0.74, x + size * 0.5
        self.add(f'<path d="M{a:.1f} {y + size * 0.28:.1f}L{m:.1f} {y + size * 0.72:.1f}L{b:.1f} '
                 f'{y + size * 0.28:.1f}" fill="none" stroke="{colour}" stroke-width="{t:.1f}"/>')

    def name_plate(self, x, y, w, h):
        self.rect(x, y, w, h)
        self.mark(x + h * 0.12, y + h * 0.12, h - 2 * h * 0.12, self.BG, self.LINE)
        size = h * 0.5
        self.text(x + h * 1.05, y + h * 0.56, self.NAME, self.BG, size, spacing=size * 0.04)
        self.text(x + h * 1.08, y + h * 0.84, "STATION SYSTEMS", self.BG, h * 0.13, spacing=h * 0.035)


def build(v, d, glow=True):
    """The whole console as (svg_text, hot_spots), from settings v and data d."""
    c = Canvas(v)
    add, text, box, rect, plate, split = c.add, c.text, c.box, c.rect, c.plate, c.split
    LINE, DIM, MUTED, BG, SW = c.LINE, c.DIM, c.MUTED, c.BG, c.SW
    term = v.get("terminal", "foot")
    now = d["now"]

    add(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">')
    blur = 1.2 + 1.3 * int(v.get("glow_strength", "1") or 0)
    add(f'''<defs>
<radialGradient id="tube" cx="50%" cy="46%" r="75%">
 <stop offset="0" stop-color="{v["bg_alt"]}"/><stop offset="0.7" stop-color="{BG}"/>
</radialGradient>
<filter id="glow" x="-5%" y="-5%" width="110%" height="110%">
 <feGaussianBlur stdDeviation="{blur}" result="b"/>
 <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
</filter>
<pattern id="scan" width="4" height="4" patternUnits="userSpaceOnUse">
 <rect width="4" height="1.2" fill="{BG}"/>
</pattern>
</defs>''')
    add(f'<rect width="{W}" height="{H}" fill="url(#tube)"/>')
    add('<g filter="url(#glow)">' if glow and v.get("glow") == "yes" else "<g>")

    L, R, T, B = 70, W - 70, 130, H - 190
    SPLIT_X, MID_Y = 1560, 800
    box(L, T, R - L, B - T)
    for x, y in ((L, T), (R, T), (L, B), (R, B)):
        c.checker(x - 21, y - 21, 42)
    add(f'<path d="M{SPLIT_X} {T}V{B}M{L} {MID_Y}H{R}" stroke="{LINE}" stroke-width="{SW}" fill="none"/>')

    # --- upper left: the status board ---
    px, py = L + 70, T + 50
    c.name_plate(px, py, 640, 170)
    c.spot(px, py, 640, 170, "hud-menu", "System menu")
    text(px, py + 200, f"OPERATOR {d['user']}  -  UNIT {d['host']}  -  ALL UNITS REPORT TO THIS DESK.",
         MUTED, 13, spacing=2)
    text(px, py + 236, "DESK 14  -  OPERATIONAL NOTIFICATIONS", LINE, 19, spacing=5)
    split(px + 760, py + 4, 34)
    text(px + 808, py + 30, "STATION TIME", LINE, 22, spacing=4)
    cw = SPLIT_X - 70 - px - 760
    box(px + 760, py + 56, cw, 114, DIM, 2, v["panel"])
    text(px + 790, py + 146, now.strftime("%H %M") + (" :" if d["colon"] else "  "), v["warn"], 84, spacing=10)
    c.spot(px + 760, py, cw, 170, f"{term} -H cal -3", "Calendar")
    actions = (f"{term} -e htop", "thunar /", f"{term} -e nmtui", "hud-menu power")
    tips = ("Processes", "Files", "Network settings", "Lock, log out, restart, shut down")
    for i, (unit, state, colour) in enumerate(d["units"]):
        yy = py + 266 + i * 84
        text(px + 110, yy + 42, unit, LINE, 15, "end")
        text(px + 126, yy + 48, f"{i + 1:02d}", colour, 40, spacing=0)
        split(px + 226, yy + 8, 44, flip=i % 2 == 1, colour=colour)
        rw = SPLIT_X - 70 - px - 290
        box(px + 290, yy + 2, rw, 58, DIM, 2, v["panel"])
        text(px + 312, yy + 44, state, colour, 31, spacing=4)
        c.spot(px, yy, rw + 290, 64, actions[i], tips[i])

    # --- lower left: the station log (a real calendar) ---
    gx, gy = L + 70, MID_Y + 76
    text(gx, gy, f"OPERATOR {d['user']} CYCLE LOG", LINE, 34, spacing=6)
    c.spot(gx, gy - 40, 1000, 160, f"{term} -H cal -y", "This year's calendar")
    for row in range(3):
        y = gy + 46 + row * 34
        year = now.year - row
        if row == 0:
            plate(gx - 6, y - 23, 150, 30, f"CYCLE {year % 100:02d}", 17)
        else:
            text(gx + 3, y, f"CYCLE {year % 100:02d}", LINE, 17, spacing=3)
        for i, mth in enumerate(MONTHS):
            x = gx + 180 + i * 72
            if row == 0 and 12 - i == now.month:
                plate(x - 8, y - 23, 66, 30, mth, 17)
            elif row == 0 and 12 - i > now.month:
                text(x, y, mth, DIM, 17, spacing=1)        # months still to come
            else:
                text(x, y, mth, LINE, 17, spacing=1)
    text(gx, gy + 172, "LOCK STATION - PASSWORD REQUIRED", LINE, 31, spacing=6)
    rect(gx + 430, gy + 192, 380, 40)
    for i in range(6):
        rect(gx + 446 + i * 12, gy + 200, 6, 24, BG)
    add(f'<path d="M{gx + 530} {gy + 212}H{gx + 590}M{gx + 610} {gy + 212}H{gx + 650}" stroke="{BG}" stroke-width="5"/>')
    c.spot(gx, gy + 140, 830, 100, "swaylock -f", "Lock the screen")
    add(f'<path d="M{gx} {gy + 250}H{SPLIT_X - 70}" stroke="{DIM}" stroke-width="2"/>')
    rect(gx, gy + 270, 36, 70)
    text(gx + 90, gy + 292, now.strftime("%b").upper(), LINE, 17, spacing=3)
    days = calendar.monthrange(now.year, now.month)[1]
    for day in range(1, days + 1):
        x = gx + 250 + ((day - 1) % 16) * 56
        y = gy + 300 + ((day - 1) // 16) * 34
        if day == now.day:
            plate(x - 7, y - 23, 44, 30, f"{day:02d}", 17)
        else:
            text(x, y, f"{day:02d}", LINE if day < now.day else DIM, 17, spacing=1)
    by = gy + 370
    box(gx, by, 330, 140, LINE, 2)
    add(f'<path d="M{gx + 90} {by}V{by + 140}" stroke="{LINE}" stroke-width="2"/>')
    rect(gx + 20, by + 30, 50, 30)
    text(gx + 45, by + 112, "QC", LINE, 20, "middle")
    c.spot(gx, by, 90, 140, "hud-menu screenshot", "Screenshot (quick capture)")
    text(gx + 210, by + 34, "ARCHIVAL", LINE, 19, "middle")
    text(gx + 210, by + 60, "PLAYBACK", LINE, 19, "middle")
    rect(gx + 112, by + 74, 196, 32)
    text(gx + 112, by + 126, "VIDEOS AND RECORDINGS", MUTED, 9, spacing=1)
    c.spot(gx + 90, by, 240, 140, 'thunar "$(xdg-user-dir VIDEOS)"', "Videos")
    bx0, bw = gx + 350, SPLIT_X - 70 - gx - 350
    box(bx0, by, bw, 140, LINE, 2)
    split(bx0 + 22, by + 18, 28)
    split(bx0 + 22, by + 94, 28, flip=True)
    for i, line in enumerate((f"HOST {d['host']}", f"KERNEL {d['kernel']}", f"SESSION {d['user']}")):
        text(bx0 + 70, by + 34 + i * 16, line, MUTED, 10, spacing=1)
    text(bx0 + bw - 190, by + 30, now.strftime("%y%m-%d%H"), LINE, 15, "end")
    c.name_plate(bx0 + bw - 176 - 460, by + 44, 460, 84)
    c.spot(bx0 + bw - 176 - 460, by + 44, 460, 84, "hud-center apps", "Application Center")
    c.checker(bx0 + bw - 150, by + 20, 100, 3)
    c.spot(bx0 + bw - 150, by + 20, 100, 100, "hud-center catalog", "Install apps")

    # --- upper right: the eight-sided status frame (uptime) ---
    ox, oy, ow, oh = SPLIT_X + 100, T + 106, R - SPLIT_X - 200, 450
    text(ox + ow / 2 - 60, oy - 28, "DESK 14", LINE, 21, "end")
    text(ox + ow - 30, oy - 28, "00-TRAQ", LINE, 21, "end")
    rect(ox, oy, ow, oh)
    c.octagon(ox + 14, oy + 14, ow - 28, oh - 28, 96, BG, 0, BG)
    c.octagon(ox + 34, oy + 34, ow - 68, oh - 68, 84, LINE, SW + 2)
    text(ox + ow / 2, oy + 104, "WORKING" if d["busy"] else "STANDBY", LINE, 60, "middle", 4)
    sub = "ALL UNITS ACCOUNTED FOR" if not d["failed"] else f"{d['failed']} UNIT{'S' if d['failed'] > 1 else ''} FAILED"
    text(ox + ow / 2, oy + 142, sub, LINE if not d["failed"] else v["alert"], 17, "middle", 4)
    add(f'<path d="M{ox + 34} {oy + 162}H{ox + ow - 34}M{ox + 34} {oy + 318}H{ox + ow - 34}" '
        f'stroke="{LINE}" stroke-width="{SW + 2}"/>')
    text(ox + 70, oy + 280, f"{min(d['up_h'], 99):02d}:", LINE, 100, spacing=0)
    text(ox + 346, oy + 274, f"{d['up_m']:02d}:", LINE, 58, spacing=0)
    plate(ox + 506, oy + 216, 124, 70, f"{d['up_s']:02d}", 52, anchor="middle")
    text(ox + 250, oy + 308, "HOUR", LINE, 12, "middle")
    text(ox + 400, oy + 308, "MIN", LINE, 12, "middle")
    text(ox + 568, oy + 308, "UP", LINE, 12, "middle")
    c.checker(ox + ow / 2 - 18, oy + 330, 36)
    text(ox + ow / 2, oy + 400, "LINK ESTABLISHED" if d["online"] else "NO LINK", LINE, 19, "middle", 4)
    c.spot(ox, oy, ow, oh, f"{term} -H hud", "System scan")
    split(ox - 64, oy + oh / 2 - 23, 46)
    split(ox + ow + 18, oy + oh / 2 - 23, 46, flip=True)
    text(ox + ow / 2, oy + oh + 62, "COM . NAV", LINE, 38, "middle", 6)
    c.spot(ox, oy + oh + 20, ow, 60, f"{term} -e nmtui", "Network settings")

    # --- lower right: function list, keys, log entry and meters ---
    rx, ry = SPLIT_X + 60, MID_Y + 60
    update = (f"{term} -e sh -c 'sudo apt-get update && sudo apt-get full-upgrade; "
              "echo; echo Finished. Press Enter.; read _'")
    groups = ((("NETWORK", f"{term} -e nmtui"), ("BLUETOOTH", "blueman-manager"), ("SOUND", "pavucontrol"),
               ("DISPLAYS", "wdisplays"), ("UPDATE SYS", update)),
              (("POWER MENU", "hud-menu power"), ("LOCK", "swaylock -f")),
              (("SEARCH", "hud-search"), ("FILES", "thunar"), ("TERMINAL", term), ("APP CENTER", "hud-center apps")),
              (("ALERTS", "hud-menu alerts-toggle"), ("DIAGNOSTIC", f"{term} -H hud")))
    y = ry
    for group in groups:
        for word, command in group:
            text(rx + 270, y, word, LINE, 16, "end", 2)
            c.spot(rx + 70, y - 22, 216, 26, command, word.title())
            y += 26
        y += 22
    add(f'<path d="M{rx + 296} {MID_Y}V{B}M{rx + 400} {MID_Y}V{B}" stroke="{LINE}" stroke-width="{SW}"/>')
    keys = (("MUTE", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", "Mute or unmute", d["muted"]),
            ("THEME", "hud-menu theme", "Change theme", True),
            ("PREFS", "hud-center prefs", "Control Center", True))
    for i, (label, command, tip, lit) in enumerate(keys):
        ky = ry - 24 + i * 96
        split(rx + 318, ky, 60, flip=i == 0, lit=lit)
        text(rx + 348, ky + 80, label, LINE, 11, "middle", 0)
        c.spot(rx + 306, ky - 6, 84, 92, command, tip)
    c.checker(rx + 318, ry + 290, 60, 3)
    c.spot(rx + 306, ry + 280, 84, 80, "hud-center catalog", "Install apps")
    vx, vw = rx + 440, R - 60 - rx - 440
    for bx in (vx, vx + vw - 22):
        rect(bx, ry - 20, 22, 36)
        rect(bx, ry + 40, 22, 70)
    text(vx + vw / 2, ry + 50, "VIEW LOG ENTRY", LINE, 21, "middle", 2)
    text(vx + vw / 2, ry + 92, now.strftime("YEAR %y %b %d").upper(), LINE, 15, "middle", 3)
    c.spot(vx, ry - 20, vw, 130, f"{term} -e journalctl -f -n 200", "System log")
    for i, (label, level) in enumerate(d["meters"]):
        mx = vx + 30 + i * 105
        box(mx - 15, ry + 160, 70, 200, LINE, 2)
        level = max(0.02, min(1.0, level))
        rect(mx - 6, ry + 160 + 191 - 182 * level, 52, 182 * level)
        text(mx + 20, ry + 388, label, LINE, 16, "middle")
    c.spot(vx, ry + 150, vw, 260, f"{term} -e htop", "Processes")
    c.name_plate(vx, ry + 424, vw, 84)
    c.spot(vx, ry + 424, vw, 84, "hud-center apps", "Application Center")

    add("</g>")
    if v.get("scanlines") == "yes":
        add(f'<rect width="{W}" height="{H}" fill="url(#scan)" opacity="0.22"/>')
    add("</svg>")
    return "\n".join(c.out), c.spots
