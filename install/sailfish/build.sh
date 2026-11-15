#!/bin/bash

# Builds Sail Commander (Double Commander for Sailfish OS).
#
# This script should be executed from the root of the source tree inside
# the Sailfish OS build target (Sailfish SDK, 'sfdk build' or 'mb2 build'
# does it when the RPM package is built, see rpm/sailcommander.spec).
#
# Free Pascal and Lazarus are not packaged for Sailfish OS, so the script
# downloads them to the 'install/sailfish/toolchain' directory first.
# Sailfish OS has no X11, therefore the Qt5 widgetset of Lazarus and its
# binding library (libQt5Pas) are built without the X11 support.

set -e

FPC_VERSION=${FPC_VERSION:-3.2.2}
LAZARUS_TAG=${LAZARUS_TAG:-lazarus_4_4}

SRC_DIR=$(pwd)
TOOLCHAIN=${TOOLCHAIN:-$SRC_DIR/install/sailfish/toolchain}
JOBS=${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}
QMAKE=${QMAKE:-$(command -v qmake-qt5 || command -v qmake)}

# Free Pascal names of the processor architectures
case "$(uname -m)" in
  aarch64)
    FPC_ARCHIVE=fpc-$FPC_VERSION.aarch64-linux
    ;;
  arm*)
    FPC_ARCHIVE=fpc-$FPC_VERSION.arm-linux-eabihf-raspberry
    ;;
  i?86)
    FPC_ARCHIVE=fpc-$FPC_VERSION.i386-linux
    ;;
  x86_64)
    FPC_ARCHIVE=fpc-$FPC_VERSION.x86_64-linux
    ;;
  *)
    echo "Unsupported processor architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

FPC_URL=${FPC_URL:-https://downloads.sourceforge.net/project/freepascal/Linux/$FPC_VERSION/$FPC_ARCHIVE.tar}
LAZARUS_URL=${LAZARUS_URL:-https://gitlab.com/freepascal.org/lazarus/lazarus/-/archive/$LAZARUS_TAG/lazarus-$LAZARUS_TAG.tar.gz}

FPC_DIR=$TOOLCHAIN/fpc
LAZARUS_DIR=$TOOLCHAIN/lazarus
LAZARUS_CFG=$TOOLCHAIN/lazarus-config

mkdir -p "$TOOLCHAIN"

install_fpc()
{
  if [ -x "$FPC_DIR/bin/fpc" ]; then
    return
  fi

  echo "*** Installing Free Pascal $FPC_VERSION"
  if [ ! -f "$TOOLCHAIN/$FPC_ARCHIVE.tar" ]; then
    curl -L --fail -o "$TOOLCHAIN/$FPC_ARCHIVE.tar" "$FPC_URL"
  fi

  rm -rf "$TOOLCHAIN/fpc-setup" "$FPC_DIR"
  mkdir -p "$TOOLCHAIN/fpc-setup" "$FPC_DIR"
  tar -xf "$TOOLCHAIN/$FPC_ARCHIVE.tar" -C "$TOOLCHAIN/fpc-setup" --strip-components=1

  # The installer is interactive, so unpack the packages manually
  (cd "$TOOLCHAIN/fpc-setup" && tar -xf binary.*.tar)
  for PACKAGE in "$TOOLCHAIN"/fpc-setup/*.tar.gz; do
    tar -xzf "$PACKAGE" -C "$FPC_DIR"
  done
  rm -rf "$TOOLCHAIN/fpc-setup"

  # Make the compiler binary visible to the 'fpc' driver
  for COMPILER in "$FPC_DIR"/lib/fpc/$FPC_VERSION/ppc*; do
    ln -sf "$COMPILER" "$FPC_DIR/bin/$(basename "$COMPILER")"
  done
}

configure_fpc()
{
  export PATH=$FPC_DIR/bin:$PATH
  export PPC_CONFIG_PATH=$TOOLCHAIN/fpc-config

  mkdir -p "$PPC_CONFIG_PATH"
  fpcmkcfg -d basepath="$FPC_DIR/lib/fpc/$FPC_VERSION" -o "$PPC_CONFIG_PATH/fpc.cfg"

  # Options for all the Double Commander projects
  {
    echo "-dSAILFISH"
    if [ "$(fpc -iTP)" != "arm" ]; then
      echo "-fPIC"
    fi
    # Linked libraries depend on the libraries which are not listed explicitly
    echo "-k--allow-shlib-undefined"
    echo "-Fl$SRC_DIR"
  } >> "$PPC_CONFIG_PATH/fpc.cfg"
}

install_lazarus()
{
  if [ ! -d "$LAZARUS_DIR/lcl" ]; then
    echo "*** Downloading Lazarus ($LAZARUS_TAG)"
    curl -L --fail -o "$TOOLCHAIN/lazarus.tar.gz" "$LAZARUS_URL"
    rm -rf "$LAZARUS_DIR"
    mkdir -p "$LAZARUS_DIR"
    tar -xzf "$TOOLCHAIN/lazarus.tar.gz" -C "$LAZARUS_DIR" --strip-components=1
    rm -f "$TOOLCHAIN/lazarus.tar.gz"

    # Sailfish OS has no X11
    sed -i 's/{\$DEFINE HASX11}/{.$DEFINE HASX11}/' \
        "$LAZARUS_DIR/lcl/interfaces/qt5/qtdefines.inc"
    sed -i -e '/QT += x11extras/d' -e '/qx11info_x11_c\./d' \
        "$LAZARUS_DIR/lcl/interfaces/qt5/cbindings/Qt5Pas.pro"
  fi

  if [ ! -x "$LAZARUS_DIR/lazbuild" ]; then
    echo "*** Building lazbuild"
    make -C "$LAZARUS_DIR" lazbuild
  fi

  mkdir -p "$LAZARUS_CFG"
  export lazbuild="$LAZARUS_DIR/lazbuild --lazarusdir=$LAZARUS_DIR --primary-config-path=$LAZARUS_CFG"
}

build_qt5pas()
{
  if ls "$SRC_DIR"/libQt5Pas.so* >/dev/null 2>&1; then
    return
  fi

  echo "*** Building libQt5Pas"
  (
    cd "$LAZARUS_DIR/lcl/interfaces/qt5/cbindings"
    "$QMAKE" Qt5Pas.pro
    make -j"$JOBS"
    cp -a libQt5Pas.so* "$SRC_DIR/"
  )
}

build_doublecmd()
{
  echo "*** Building Double Commander"
  export lcl=qt5
  export DC_ARCH="--widgetset=qt5"

  # The components build script makes its own copy of the compiler
  # configuration, so the options above should be in the global one
  (
    cd components
    $lazbuild chsdet/chsdet.lpk $DC_ARCH
    $lazbuild multithreadprocs/multithreadprocslaz.lpk $DC_ARCH
    $lazbuild kascrypt/kascrypt.lpk $DC_ARCH
    $lazbuild doublecmd/doublecmd_common.lpk $DC_ARCH
    $lazbuild Image32/Image32.lpk $DC_ARCH
    $lazbuild KASToolBar/kascomp.lpk $DC_ARCH
    $lazbuild viewer/viewerpackage.lpk $DC_ARCH
    $lazbuild gifview/gifview.lpk $DC_ARCH
    $lazbuild synunihighlighter/synuni.lpk $DC_ARCH
    $lazbuild virtualterminal/virtualterminal.lpk $DC_ARCH
  )

  $lazbuild src/doublecmd.lpi --bm=release $DC_ARCH
  strip doublecmd

  # Plugins without external dependencies, they are optional
  (
    cd plugins
    for PLUGIN in wcx/base64/src/base64wcx.lpi wcx/cpio/src/cpio.lpi \
                  wcx/deb/src/deb.lpi wcx/rpm/src/rpm.lpi wcx/zip/src/Zip.lpi \
                  wfx/ftp/src/ftp.lpi; do
      $lazbuild $PLUGIN $DC_ARCH || echo "*** Warning: cannot build $PLUGIN"
    done
  )
}

install_fpc
configure_fpc
install_lazarus
build_qt5pas
build_doublecmd

echo "*** Done"
