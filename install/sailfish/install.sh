#!/bin/bash

# Installs Sail Commander built by build.sh into the given root directory.
#
# Usage: install/sailfish/install.sh <root directory> <library directory>
# Example: install/sailfish/install.sh /tmp/root /usr/lib64

set -e

DC_ROOT=$1
DC_LIBDIR=${2:-/usr/lib}

if [ -z "$DC_ROOT" ]; then
  echo "Usage: $0 <root directory> [library directory]" >&2
  exit 1
fi

DC_APP_DIR=$DC_LIBDIR/sailcommander
DC_INSTALL_DIR=$DC_ROOT$DC_APP_DIR

install -d "$DC_INSTALL_DIR"

# Program and its data, the same layout as the portable version
# but the configuration is stored in the user home directory
install -m 755 doublecmd "$DC_INSTALL_DIR/"
install -m 644 doublecmd.help pinyin.tbl "$DC_INSTALL_DIR/"
if [ -f doublecmd.zdli ]; then
  install -m 644 doublecmd.zdli "$DC_INSTALL_DIR/"
fi
cp -a libQt5Pas.so* "$DC_INSTALL_DIR/"
cp -r default language highlighters "$DC_INSTALL_DIR/"

install -d "$DC_INSTALL_DIR/pixmaps"
cp -r pixmaps/dctheme pixmaps/mainicon "$DC_INSTALL_DIR/pixmaps/"
# The icon cache is used only when it is newer than the theme directory,
# otherwise all the icons are searched at every start, which is slow
touch "$DC_INSTALL_DIR/pixmaps/dctheme/icon-theme.cache"

install -d "$DC_INSTALL_DIR/doc"
install -m 644 doc/*.txt "$DC_INSTALL_DIR/doc/"

# Plugins which have been built
for PLUGIN in wcx/base64/base64.wcx wcx/cpio/cpio.wcx wcx/deb/deb.wcx \
              wcx/rpm/rpm.wcx wcx/zip/zip.wcx wfx/ftp/ftp.wfx; do
  if [ -f "plugins/$PLUGIN" ]; then
    install -d "$DC_INSTALL_DIR/plugins/$(dirname $PLUGIN)"
    install -m 644 "plugins/$PLUGIN" "$DC_INSTALL_DIR/plugins/$PLUGIN"
    if [ -d "plugins/$(dirname $PLUGIN)/language" ]; then
      cp -r "plugins/$(dirname $PLUGIN)/language" "$DC_INSTALL_DIR/plugins/$(dirname $PLUGIN)/"
    fi
  fi
done

# Launcher
install -d "$DC_ROOT/usr/bin"
sed "s|@APPDIR@|$DC_APP_DIR|g" install/sailfish/sailcommander.sh > "$DC_ROOT/usr/bin/sailcommander"
chmod 755 "$DC_ROOT/usr/bin/sailcommander"

# Desktop entry and icons
install -d "$DC_ROOT/usr/share/applications"
install -m 644 install/sailfish/sailcommander.desktop "$DC_ROOT/usr/share/applications/"
for ICON in install/sailfish/icons/*.png; do
  SIZE=$(basename "$ICON" .png)
  install -d "$DC_ROOT/usr/share/icons/hicolor/${SIZE}x${SIZE}/apps"
  install -m 644 "$ICON" "$DC_ROOT/usr/share/icons/hicolor/${SIZE}x${SIZE}/apps/sailcommander.png"
done
