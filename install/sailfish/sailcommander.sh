#!/bin/sh

# Sail Commander launcher

APPDIR=@APPDIR@

# The Qt binding library is shipped together with the application
export LD_LIBRARY_PATH=$APPDIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

# Sailfish OS compositor is a Wayland compositor
# which draws the window decorations by itself
export QT_QPA_PLATFORM=${QT_QPA_PLATFORM:-wayland}
export QT_WAYLAND_DISABLE_WINDOWDECORATION=${QT_WAYLAND_DISABLE_WINDOWDECORATION:-1}

exec "$APPDIR/doublecmd" "$@"
