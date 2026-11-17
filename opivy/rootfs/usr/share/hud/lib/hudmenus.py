"""The shortcut menus (menus.conf): used when an app publishes no menus of its own.

Shared by hud-menubar and hud-appmenu.
"""
import os
import shlex
import subprocess

import hudapps

MENUS = ("file", "edit", "view", "window", "help")
MODS = {"ctrl": "ctrl", "shift": "shift", "alt": "alt", "cmd": "logo", "logo": "logo"}


def front_window():
    """(app_id, title) of the window in front, or ("", "")."""
    try:
        out = subprocess.run(["wlrctl", "toplevel", "list", "state:focused"],
                             capture_output=True, text=True, timeout=2).stdout
    except (OSError, subprocess.SubprocessError):
        return "", ""
    app, _, title = out.split("\n", 1)[0].partition(":")
    return app.strip(), title.strip()


def read_menus():
    rows = []
    for path in ("/usr/share/hud/menus.conf", os.path.join(hudapps.USER, "menus.conf")):
        try:
            with open(path) as f:
                for line in f:
                    parts = [p.strip() for p in line.split("|")]
                    if len(parts) == 4 and not line.lstrip().startswith("#"):
                        rows.append(parts)
        except OSError:
            pass
    return rows


def items_for(app, menu, rows):
    keys = [app.lower(), app.lower().split(".")[-1]] if app else ["desktop"]
    own = [(label, action) for a, m, label, action in rows if m == menu and a.lower() in keys]
    if own or not app:
        return own
    return [(label, action) for a, m, label, action in rows if m == menu and a == "*"]


def hint(action):
    if action.startswith("@"):
        return ""
    return "+".join(p.upper() if len(p) == 1 else p.capitalize() for p in action.split("+"))


def run(command):
    subprocess.Popen(command, shell=True, start_new_session=True, cwd=hudapps.HOME,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def press(action):
    *mods, key = action.split("+")
    args = ["wtype"]
    for m in mods:
        args += ["-M", MODS.get(m.lower(), m.lower())]
    args += ["-k", key]
    for m in reversed(mods):
        args += ["-m", MODS.get(m.lower(), m.lower())]
    subprocess.run(args)


def perform(app, action):
    """Carry out one menu item for the app in front."""
    quoted = shlex.quote("app_id:" + app)
    if action == "@minimize":
        run(f"wlrctl toplevel minimize {quoted} state:focused")
    elif action == "@hide":
        run(f"wlrctl toplevel minimize {quoted}")
    elif action == "@front":
        run(f"wlrctl toplevel focus {quoted}")
    elif action == "@quit":
        run(f"wlrctl toplevel close {quoted}")
    elif action.startswith("@run:"):
        run(action[5:])
    else:
        press(action)
