# After a login on the first console, start the desktop. On any other
# terminal login, show the system scan once.
case $- in *i*) ;; *) return ;; esac
[ -z "${HUD_GREETED:-}" ] || return
export HUD_GREETED=1

if [ "$(tty)" = /dev/tty1 ] && [ -z "${WAYLAND_DISPLAY:-}" ] && command -v labwc >/dev/null; then
    hud-session
    printf '\n  Desktop closed. Type  hud-session  to start it again.\n\n'
elif [ -z "${WAYLAND_DISPLAY:-}" ]; then
    hud
fi
