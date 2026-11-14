# Cyberdyne OS: run the HUD scan once when a person logs in on a terminal.
case $- in *i*) ;; *) return ;; esac
if [ -z "${CYBERDYNE_HUD_SHOWN:-}" ] && [ -x /usr/local/bin/hud ]; then
    export CYBERDYNE_HUD_SHOWN=1
    /usr/local/bin/hud
    if [ -d /run/live/medium ]; then
        printf '  LIVE SESSION. Nothing is saved. To install to a disk:\n'
        printf '    sudo cyberdyne-install\n\n'
    fi
fi
