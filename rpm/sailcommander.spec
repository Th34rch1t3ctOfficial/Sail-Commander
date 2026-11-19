# Sail Commander - Double Commander for Sailfish OS
#
# Build inside the Sailfish SDK from the root of the source tree:
#   sfdk build        (or 'mb2 build' inside the platform SDK)
#
# Free Pascal and Lazarus are downloaded during the build,
# see install/sailfish/build.sh for details.

Name:       sailcommander
Summary:    Double Commander for Sailfish OS
Version:    1.3.0
# Every build gets its own release number (date and time of the build),
# so the package manager always takes a newer build as an update
Release:    %(date -u +%%Y%%m%%d%%H%%M)
License:    GPLv2+
URL:        https://github.com/Th34rch1t3ctOfficial/Sail-Commander
Source0:    %{name}-%{version}.tar.bz2

BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Gui)
BuildRequires:  pkgconfig(Qt5Widgets)
BuildRequires:  pkgconfig(Qt5Network)
BuildRequires:  pkgconfig(Qt5PrintSupport)
BuildRequires:  pkgconfig(dbus-1)
BuildRequires:  pkgconfig(glib-2.0)
BuildRequires:  qt5-qmake
BuildRequires:  make
BuildRequires:  gcc-c++
BuildRequires:  binutils
BuildRequires:  curl
BuildRequires:  tar
BuildRequires:  gzip

# The binary is built by Free Pascal, there is no debug information for RPM
%define debug_package %{nil}
%define __strip /bin/true

# Do not export the bundled Qt binding library and do not require it
%global __provides_exclude_from ^%{_libdir}/%{name}/.*$
%global __requires_exclude ^libQt5Pas\\.so.*$

%description
Sail Commander is a fork of Double Commander, a cross platform open source
file manager with two panels, adapted for Sailfish OS and a touch screen.

%prep
%setup -q -n %{name}-%{version}

%build
install/sailfish/build.sh

%install
rm -rf %{buildroot}
install/sailfish/install.sh %{buildroot} %{_libdir}

%files
%defattr(-,root,root,-)
%license LICENSE.md
%{_bindir}/%{name}
%{_libdir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
