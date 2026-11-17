{
   Sail Commander
   -------------------------------------------------------------------------
   Mobile (touch screen) mode support, used by the Sailfish OS port

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program. If not, see <http://www.gnu.org/licenses/>.
}

unit uMobile;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

var
  {en
     Mobile mode: single file panel, touch file view, side button bar.
     Enabled automatically on Sailfish OS, can be forced on any system
     using the environment variable DC_MOBILE=1 (or disabled using DC_MOBILE=0).
  }
  gMobileMode: Boolean = False;

{en
   Returns @true when running on Sailfish OS.
}
function IsSailfishOS: Boolean;
{en
   Detects mobile mode and prepares the process environment.
   Must be called before the widgetset is initialized.
}
procedure InitializeMobileEnvironment;
{en
   Applies touch friendly application style.
   Must be called right after the widgetset is initialized.
}
procedure InitializeMobileStyle;
{en
   Returns @true when the dark appearance should be used. Follows the
   Sailfish OS ambience, can be forced using the environment variable
   DC_MOBILE_THEME=dark (or DC_MOBILE_THEME=light).
}
function MobileDarkTheme: Boolean;
{en
   User interface scale factor relative to a 96 DPI screen.
}
function MobileScale: Double;
{en
   Converts a size in 96 DPI pixels to the device pixels.
}
function MobilePx(Value: Integer): Integer;
{en
   Returns size of an icon which is the closest to the scaled one.
}
function MobileIconSize(Value: Integer): Integer;

implementation

uses
  Forms, Math, Process
{$IF DEFINED(UNIX)}
  , BaseUnix, ctypes
{$ENDIF}
{$IF DEFINED(LCLQT5)}
  , qt5
{$ENDIF}
  ;

const
  // Width of a phone screen in density independent pixels
  PHONE_WIDTH_DP = 360;

{$IF DEFINED(UNIX)}
function setenv(name, value: PAnsiChar; overwrite: cint): cint; cdecl; external 'c';

procedure SetEnvironmentDefault(const AName, AValue: String);
begin
  if GetEnvironmentVariable(AName) = EmptyStr then
    setenv(PAnsiChar(AName), PAnsiChar(AValue), 1);
end;

procedure SetEnvironment(const AName, AValue: String);
begin
  setenv(PAnsiChar(AName), PAnsiChar(AValue), 1);
end;

{en
   Reads a display mode of a DRM connector ("1080x2400"), returns smaller side.
}
function GetDrmScreenWidth: Integer;
var
  S: String;
  P: Integer;
  AModes: TStringList;
  ASearch: TSearchRec;
begin
  Result:= 0;
  if FindFirst('/sys/class/drm/card*-*', faAnyFile, ASearch) = 0 then
  try
    repeat
      if FileExists('/sys/class/drm/' + ASearch.Name + '/modes') then
      try
        AModes:= TStringList.Create;
        try
          AModes.LoadFromFile('/sys/class/drm/' + ASearch.Name + '/modes');
          if AModes.Count > 0 then
          begin
            S:= Trim(AModes[0]);
            P:= Pos('x', S);
            if P > 0 then
            begin
              Result:= Min(StrToIntDef(Copy(S, 1, P - 1), 0),
                           StrToIntDef(Copy(S, P + 1, MaxInt), 0));
              if Result > 0 then Exit;
            end;
          end;
        finally
          AModes.Free;
        end;
      except
        Result:= 0;
      end;
    until FindNext(ASearch) <> 0;
  finally
    FindClose(ASearch);
  end;
end;

{en
   Reads a framebuffer size in device pixels, returns smaller side.
}
function GetFrameBufferWidth: Integer;
const
  FB_SIZE = '/sys/class/graphics/fb0/virtual_size';
var
  S: String;
  P: Integer;
  ASize: TStringList;
begin
  Result:= 0;
  if FileExists(FB_SIZE) then
  try
    ASize:= TStringList.Create;
    try
      ASize.LoadFromFile(FB_SIZE);
      if ASize.Count > 0 then
      begin
        S:= Trim(ASize[0]);
        P:= Pos(',', S);
        if P > 0 then
        begin
          Result:= Min(StrToIntDef(Copy(S, 1, P - 1), 0),
                       StrToIntDef(Copy(S, P + 1, MaxInt), 0));
        end;
      end;
    finally
      ASize.Free;
    end;
  except
    Result:= 0;
  end;
end;
{$ENDIF}

function IsSailfishOS: Boolean;
begin
{$IF DEFINED(LINUX)}
  Result:= FileExists('/etc/sailfish-release');
{$ELSE}
  Result:= False;
{$ENDIF}
end;

function MobileDarkTheme: Boolean;
const
  FDarkTheme: Integer = -1;
var
  AValue: String;
begin
  if FDarkTheme < 0 then
  begin
    FDarkTheme:= 1;
    AValue:= LowerCase(GetEnvironmentVariable('DC_MOBILE_THEME'));
    if (AValue = EmptyStr) and IsSailfishOS then
    try
      // Color scheme of the current ambience
      if not RunCommand('dconf', ['read', '/desktop/jolla/theme/color_scheme'], AValue) then
        AValue:= EmptyStr;
    except
      AValue:= EmptyStr;
    end;
    if Pos('light', LowerCase(AValue)) > 0 then FDarkTheme:= 0;
  end;
  Result:= (FDarkTheme = 1);
end;

procedure InitializeMobileEnvironment;
const
  FInitialized: Boolean = False;
var
  AValue: String;
{$IF DEFINED(UNIX)}
  ADpi, AWidth: Integer;
{$ENDIF}
begin
  if FInitialized then Exit;
  FInitialized:= True;

  AValue:= GetEnvironmentVariable('DC_MOBILE');
  if AValue = '1' then
    gMobileMode:= True
  else if AValue = '0' then
    gMobileMode:= False
  else begin
    gMobileMode:= IsSailfishOS;
  end;

{$IF DEFINED(UNIX)}
  if gMobileMode and IsSailfishOS then
  begin
    // Sailfish OS compositor (Lipstick) is a Wayland compositor
    // which draws all the window decorations by itself
    SetEnvironmentDefault('QT_QPA_PLATFORM', 'wayland');
    SetEnvironmentDefault('QT_WAYLAND_DISABLE_WINDOWDECORATION', '1');
    // Qt Widgets does not scale by itself there, so report a logical
    // DPI which corresponds to the screen density, LCL will do the rest.
    // The session sets its own value for Silica applications which
    // are scaled differently, so it is always replaced.
    ADpi:= StrToIntDef(GetEnvironmentVariable('DC_MOBILE_DPI'), 0);
    if ADpi <= 0 then
    begin
      AWidth:= GetDrmScreenWidth;
      if AWidth <= 0 then AWidth:= GetFrameBufferWidth;
      if AWidth <= 0 then AWidth:= 1080;
      ADpi:= Max(96, (AWidth * 96) div PHONE_WIDTH_DP);
    end;
    SetEnvironment('QT_WAYLAND_FORCE_DPI', IntToStr(ADpi));
  end;
{$ENDIF}
end;

function MobileScale: Double;
begin
  Result:= Screen.PixelsPerInch / 96.0;
  if Result < 1.0 then Result:= 1.0;
end;

function MobilePx(Value: Integer): Integer;
begin
  Result:= Round(Value * MobileScale);
end;

function MobileIconSize(Value: Integer): Integer;
const
  ICON_SIZES: array[0..5] of Integer = (16, 24, 32, 48, 64, 96);
var
  I, ASize: Integer;
begin
  ASize:= MobilePx(Value);
  Result:= ICON_SIZES[0];
  for I:= Low(ICON_SIZES) to High(ICON_SIZES) do
  begin
    if Abs(ICON_SIZES[I] - ASize) <= Abs(Result - ASize) then
      Result:= ICON_SIZES[I];
  end;
end;

{$IF DEFINED(LCLQT5)}
procedure ApplyQtStyle;
const
  // Dark palette close to the Sailfish OS ambiences
  clWindowBack   = $2D2D2D;
  clBaseBack     = $232323;
  clTextFore     = $EEEEEE;
  clDisabledFore = $808080;
  clSelection    = $3D7BD9;

  procedure SetColor(APalette: QPaletteH; ARole: QPaletteColorRole; AColor: Cardinal);
  var
    AQColor: TQColor;
  begin
    QColor_fromRgb(@AQColor, (AColor shr 16) and $FF, (AColor shr 8) and $FF, AColor and $FF);
    QPalette_setColor(APalette, ARole, @AQColor);
  end;

  procedure SetDisabled(APalette: QPaletteH; ARole: QPaletteColorRole);
  var
    AQColor: TQColor;
  begin
    QColor_fromRgb(@AQColor, (clDisabledFore shr 16) and $FF,
                   (clDisabledFore shr 8) and $FF, clDisabledFore and $FF);
    QPalette_setColor(APalette, QPaletteDisabled, ARole, @AQColor);
  end;

var
  AStyle: QStyleH;
  AName: WideString;
  APalette: QPaletteH;
  AStyleSheet: WideString;
begin
  // There is no native widget style, so use the built-in one
  AName:= 'Fusion';
  AStyle:= QStyleFactory_create(@AName);
  if Assigned(AStyle) then QApplication_setStyle(AStyle);

  if MobileDarkTheme then
  begin
  APalette:= QPalette_Create();
  try
    SetColor(APalette, QPaletteWindow, clWindowBack);
    SetColor(APalette, QPaletteWindowText, clTextFore);
    SetColor(APalette, QPaletteBase, clBaseBack);
    SetColor(APalette, QPaletteAlternateBase, clWindowBack);
    SetColor(APalette, QPaletteToolTipBase, clWindowBack);
    SetColor(APalette, QPaletteToolTipText, clTextFore);
    SetColor(APalette, QPaletteText, clTextFore);
    SetColor(APalette, QPaletteButton, $3A3A3A);
    SetColor(APalette, QPaletteButtonText, clTextFore);
    SetColor(APalette, QPaletteBrightText, $FF5555);
    SetColor(APalette, QPaletteLight, $505050);
    SetColor(APalette, QPaletteMidlight, $454545);
    SetColor(APalette, QPaletteMid, $303030);
    SetColor(APalette, QPaletteDark, $202020);
    SetColor(APalette, QPaletteShadow, $101010);
    SetColor(APalette, QPaletteLink, $6CA8FF);
    SetColor(APalette, QPaletteHighlight, clSelection);
    SetColor(APalette, QPaletteHighlightedText, $FFFFFF);
    SetDisabled(APalette, QPaletteWindowText);
    SetDisabled(APalette, QPaletteText);
    SetDisabled(APalette, QPaletteButtonText);
    QApplication_setPalette(APalette);
  finally
    QPalette_Destroy(APalette);
  end;
  end;

  // Make the standard widgets big enough for a finger
  AStyleSheet:= WideString(Format(
    'QMenu::item { padding: %0:dpx %1:dpx %0:dpx %1:dpx; }' +
    'QMenu::item:selected { background: palette(highlight); color: palette(highlighted-text); }' +
    'QMenu::item:disabled { color: palette(mid); }' +
    'QMenu::separator { height: 1px; background: palette(mid); margin: %2:dpx 0px; }' +
    'QMenuBar::item { padding: %2:dpx %0:dpx; }' +
    'QScrollBar:vertical { width: %3:dpx; }' +
    'QScrollBar:horizontal { height: %3:dpx; }' +
    'QPushButton { min-height: %4:dpx; padding: 0px %2:dpx; }' +
    'QLineEdit, QComboBox, QAbstractSpinBox { min-height: %4:dpx; }' +
    'QTabBar::tab { min-height: %4:dpx; padding: 0px %1:dpx; }',
    [MobilePx(9), MobilePx(22), MobilePx(4), MobilePx(14), MobilePx(30)]));
  QApplication_setStyleSheet(QApplicationH(QCoreApplication_instance()), @AStyleSheet);
end;
{$ENDIF}

procedure InitializeMobileStyle;
begin
  if not gMobileMode then Exit;
{$IF DEFINED(LCLQT5)}
  ApplyQtStyle;
{$ENDIF}
end;

initialization
  // The environment must be ready before the widgetset creates
  // the Qt application object (in the initialization of Interfaces)
  InitializeMobileEnvironment;

end.
