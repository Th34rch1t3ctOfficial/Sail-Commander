# Sail Commander

**Sail Commander** is a fork of [Double Commander](https://github.com/doublecmd/doublecmd)
adapted for [Sailfish OS](https://sailfishos.org) and a touch screen. It is the same
application (the same source code, plugins, configuration and icons), with
a *mobile mode* which is turned on automatically on Sailfish OS:

- one file panel at a time, the opposite one is a tap away (button in the panel header)
- touch file view: two-line items, kinetic scrolling, tap opens a file or directory,
  tap on an icon selects it, long press shows the context menu
- the main menu at the top, the main file commands (Edit, Copy, Move, Delete) at the bottom
- a list of places (device memory, memory cards, user directories, file system root,
  bookmarks) above the root directory instead of the drive bar
- dark and light appearance which follows the Sailfish OS ambience

The mobile mode can be tried on a desktop too: `DC_MOBILE=1 ./doublecmd`
(`DC_MOBILE_THEME=light` or `dark` chooses the appearance). The touch file view is
also available as the internal command `cm_TouchView`.

## Building for Sailfish OS

The package is built inside the [Sailfish SDK](https://docs.sailfishos.org/Tools/Sailfish_SDK/)
from the root of the source tree:

    sfdk build

See [rpm/sailcommander.spec](rpm/sailcommander.spec) and
[install/sailfish/build.sh](install/sailfish/build.sh). Free Pascal and Lazarus are not
packaged for Sailfish OS, so the build script downloads them. Sailfish OS has no X11,
therefore the Qt5 widgetset of Lazarus and its binding library are built without it.
The GitHub workflow [build-sailfish](.github/workflows/sailfish.yml) builds the packages
for `aarch64` and `armv7hl`.

The port is experimental. The application uses Qt Widgets (not Silica), so it cannot
be published in the Jolla Store.

---

**Double Commander** is a [free](https://www.gnu.org/philosophy/free-sw.html) cross-platform open source file manager with two panels side by side (or one above the other). It is inspired by Total Commander and features some innovative new ideas. 

Double Commander can be run on several platforms and operating systems.
It supports 32-bit and 64-bit processors. See [Supported platforms](https://github.com/doublecmd/doublecmd/wiki/Supported-platforms)
for a complete list.

See Double Commander in action in the [Screenshot Gallery](https://doublecmd.sourceforge.io/gallery).

## Where to start

### Download

Go to the [Double Commander download page](https://sourceforge.net/p/doublecmd/wiki/Download) to download the latest release.

You can check the latest version on the [Versions](https://github.com/doublecmd/doublecmd/wiki/Versions) page.

See if Double Commander is supported for your platform on the [Supported
platforms](https://github.com/doublecmd/doublecmd/wiki/Supported-platforms) page.

### Develop

For more information on the development of Double Commander,
see the [Development](https://github.com/doublecmd/doublecmd/wiki/Development) page.

### Discuss
  
Go to our [forum](https://doublecmd.h1n.ru) for discussions. There are English and Russian sections.

If you want to stay up-to-date with the project, you can check out the available [news feeds](https://github.com/doublecmd/doublecmd/wiki/News-feeds).
