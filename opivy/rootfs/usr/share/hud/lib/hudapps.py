"""Finding apps' icons and names. Shared by hudctl and hud-dock."""
import os
import shlex

HOME = os.path.expanduser("~")
USER = os.path.join(os.environ.get("XDG_CONFIG_HOME", HOME + "/.config"), "hud")
APP_DIRS = (os.path.join(HOME, ".local/share/applications"), "/usr/share/applications")


def desktop_entries():
    """Every visible app as a dict: id, name, exec, icon, wmclass."""
    seen, apps = set(), []
    for folder in APP_DIRS:
        try:
            names = sorted(os.listdir(folder))
        except OSError:
            continue
        for entry in names:
            if not entry.endswith(".desktop") or entry in seen:
                continue
            seen.add(entry)
            info, section = {"id": entry[:-8]}, None
            try:
                with open(os.path.join(folder, entry), errors="replace") as f:
                    for line in f:
                        line = line.strip()
                        if line.startswith("["):
                            section = line
                            continue
                        if section != "[Desktop Entry]" or "=" not in line:
                            continue
                        k, _, val = line.partition("=")
                        if k in ("Name", "Exec", "Icon", "StartupWMClass", "NoDisplay") and k not in info:
                            info[k] = val
            except OSError:
                continue
            apps.append({"id": info["id"], "name": info.get("Name", info["id"]),
                         "exec": info.get("Exec", ""), "icon": info.get("Icon", ""),
                         "wmclass": info.get("StartupWMClass", ""), "hidden": info.get("NoDisplay") == "true"})
    return apps


def find_entry(key, apps=None):
    """The app a window's app_id or a command's program belongs to."""
    if not key:
        return None
    key_l = key.lower()
    apps = apps if apps is not None else desktop_entries()
    for test in (lambda a: a["id"].lower() == key_l,
                 lambda a: a["wmclass"].lower() == key_l,
                 lambda a: a["id"].lower().split(".")[-1] == key_l,
                 lambda a: os.path.basename(a["exec"].split()[0]).lower() == key_l if a["exec"].split() else False):
        for a in apps:
            if test(a):
                return a
    return None


# Plain names for the bundled apps, as a Mac names its own (Terminal, not
# the program's name). Keyed by app id or program name.
FRIENDLY = {"foot": "Terminal", "footclient": "Terminal", "org.xfce.thunar": "Files", "thunar": "Files",
            "org.xfce.mousepad": "Text Editor", "mousepad": "Text Editor", "org.gnome.epiphany": "Web",
            "epiphany": "Web", "hud-center": "Application Center", "pavucontrol": "Sound",
            "htop": "Activity Monitor", "wdisplays": "Displays", "blueman-manager": "Bluetooth"}


def app_name(key, apps=None):
    """The name to show for an app id or program: friendly, else the app's own."""
    if not key:
        return ""
    if key.lower() in FRIENDLY:
        return FRIENDLY[key.lower()]
    entry = find_entry(key, apps)
    return entry["name"] if entry else key.split(".")[-1].capitalize()


# Friendly names shown when the pointer rests on a dock icon.
APP_TITLES = {"APPS": "Application Center", "TERM": "Terminal", "FILES": "Files", "WEB": "Web",
              "EDIT": "Text Editor", "SCAN": "System Scan", "MAIL": "Mail"}
# Icons for commands that have no .desktop file of their own.
COMMAND_ICONS = {"hud-center": "opivy-apps", "hud": "utilities-system-monitor",
                 "hud-menu": "preferences-system"}


def app_icon(command):
    """The icon name for a command, found through the matching .desktop file."""
    try:
        words = shlex.split(command) if command else []
    except ValueError:
        words = command.split()
    if not words:
        return ""
    for w in reversed(words):          # "foot -H hud" is the system scan, not a terminal
        if w in COMMAND_ICONS:
            return COMMAND_ICONS[w]
    exe = os.path.basename(words[0])
    entry = find_entry(exe)
    return entry["icon"] if entry and entry["icon"] else exe


def icon_file(name, v):
    """A file for an icon name: Op Ivy's own, then the icon sets, then pixmaps."""
    if not name:
        return None
    if os.path.isabs(name):
        return name if os.path.exists(name) else None
    if name.startswith("opivy-"):
        return own_icon(name, v)
    themes = [v.get("icon_base", "Papirus-Dark"), "Papirus", "Adwaita", "hicolor"]
    for base in (os.path.join(HOME, ".local/share/icons"), "/usr/share/icons"):
        for theme in themes:
            for size in ("scalable", "64x64", "48x48", "128x128", "256x256"):
                for kind in ("apps", "places"):
                    for ext in ("svg", "png"):
                        path = os.path.join(base, theme, size, kind, f"{name}.{ext}")
                        if os.path.exists(path):
                            return path
    for ext in ("svg", "png", "xpm"):
        path = f"/usr/share/pixmaps/{name}.{ext}"
        if os.path.exists(path):
            return path
    return None


def own_icon(name, v):
    """Op Ivy's own icons, drawn in the theme colours."""
    folder = os.path.join(USER, "icons")
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, name + ".svg")
    line, panel = v.get("line", "#e9f6fa"), v.get("panel", "#070b0e")
    if name == "opivy-apps":        # a three-by-three grid of keys, one lit
        cells = "".join(
            f'<rect x="{9 + c * 16}" y="{9 + r * 16}" width="12" height="12" '
            f'fill="{line if (r, c) == (0, 0) else "none"}" stroke="{line}" stroke-width="2"/>'
            for r in range(3) for c in range(3))
        body = f'<rect x="2" y="2" width="60" height="60" rx="10" fill="{panel}"/>{cells}'
    else:
        return None
    with open(path, "w") as f:
        f.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" '
                f'viewBox="0 0 64 64">{body}</svg>')
    return path
