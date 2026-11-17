{
   Sail Commander
   -------------------------------------------------------------------------
   Touch user interface pieces for the mobile mode: menus drawn inside
   the window (popup windows do not work on Sailfish OS), the main menu,
   the settings page and the mark files dialog

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

unit uMobileUI;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Menus;

{en
   Shows a popup menu inside the window and waits until it is closed.
}
procedure MobileShowPopupMenu(APopupMenu: TPopupMenu; X, Y: Integer);
{en
   Shows the main menu (three dots) at the given screen position.
}
procedure MobileShowMainMenu(const APoint: TPoint);
{en
   Shows the settings page.
}
procedure MobileShowSettings;
{en
   Shows the mark/unmark files dialog.
}
procedure MobileShowMarkDialog;
{en
   Switches between the dark and the light appearance.
}
procedure MobileToggleTheme;
{en
   Shows all the popup menus inside the window. Should be called again when
   new menu classes are created, they reset the hook.
}
procedure MobileHookPopupMenus;

implementation

uses
  Controls, Graphics, Forms, StdCtrls, ExtCtrls, LCLType, LCLIntf, LCLProc,
  Math, GraphType, IntfGraphics, FPImage, LazUTF8, Process, uGlobs, uLng, uMobile, uEarlyConfig,
  uTouchFileView, fMain
{$IF DEFINED(LCLQT5)}
  , WSLCLClasses, QtWSMenus
{$ENDIF}
  ;

type

  { TMobileOverlay }

  {en
     Covers the whole window, shows the dimmed window content
     under the menus and dialogs, a tap outside closes them
  }
  TMobileOverlay = class(TCustomControl)
  private
    FImage: TBitmap;
    FDim: Boolean;
    FOnOutsideClick: TNotifyEvent;
  protected
    procedure Paint; override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor CreateFor(AForm: TCustomForm; ADim: Boolean);
    destructor Destroy; override;
    property OnOutsideClick: TNotifyEvent read FOnOutsideClick write FOnOutsideClick;
  end;

  TMobileRowKind = (mrkItem, mrkCheck, mrkSection, mrkSeparator, mrkBack);

  TMobileRow = record
    Kind: TMobileRowKind;
    Title: String;
    Subtitle: String;
    Checked: Boolean;
    Enabled: Boolean;
    HasSubmenu: Boolean;
    Data: Pointer;
  end;

  TMobileRowEvent = procedure(Sender: TObject; AIndex: Integer) of object;

  { TMobileList }

  {en
     List of big rows controlled by a finger
  }
  TMobileList = class(TCustomControl)
  private
    FRows: array of TMobileRow;
    FOffset: Integer;
    FPressed: Integer;
    FDragging: Boolean;
    FDownY, FDownOffset: Integer;
    FCard: Boolean;
    FOnRowClick: TMobileRowEvent;
    function RowHeight(AIndex: Integer): Integer;
    function RowTop(AIndex: Integer): Integer;
    function RowAt(Y: Integer): Integer;
    function ContentHeight: Integer;
    procedure SetOffset(AValue: Integer);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Clear;
    function Add(AKind: TMobileRowKind; const ATitle: String; const ASubtitle: String = '';
                 AData: Pointer = nil): Integer;
    function PreferredWidth: Integer;
    property Card: Boolean read FCard write FCard;
    property OnRowClick: TMobileRowEvent read FOnRowClick write FOnRowClick;
  end;

  { TMobileMenu }

  {en
     Popup menu shown inside the window
  }
  TMobileMenu = class
  private
    FOverlay: TMobileOverlay;
    FList: TMobileList;
    FRoot, FCurrent: TMenuItem;
    FPoint: TPoint;
    FSelected: TMenuItem;
    FDone: Boolean;
    procedure Fill;
    procedure Place;
    procedure OutsideClick(Sender: TObject);
    procedure RowClick(Sender: TObject; AIndex: Integer);
  public
    constructor Create(AForm: TCustomForm; ARoot: TMenuItem; const APoint: TPoint);
    destructor Destroy; override;
    function Execute: TMenuItem;
  end;

  TSettingAction = (saAbout, saHelp, saLanguage, saDateTime, saHidden, saIgnore,
                    saFonts, saAssoc, saPlugins, saLog, saAllCommands, saAllOptions);

  { TMobileSettings }

  TMobileSettings = class
  private
    FOverlay: TMobileOverlay;
    FList: TMobileList;
    procedure Fill;
    procedure RowClick(Sender: TObject; AIndex: Integer);
    procedure Close(Data: PtrInt);
  public
    constructor Create;
    destructor Destroy; override;
  end;

  { TMobileMarkDialog }

  TMobileMarkDialog = class
  private
    FOverlay: TMobileOverlay;
    FPanel: TPanel;
    FMask: TEdit;
    FFiles, FFolders: TCheckBox;
    procedure ButtonClick(Sender: TObject);
    procedure OutsideClick(Sender: TObject);
    procedure Close(Data: PtrInt);
  public
    constructor Create;
    destructor Destroy; override;
  end;

var
  MainMenu: TPopupMenu = nil;
  Settings: TMobileSettings = nil;
  MarkDialog: TMobileMarkDialog = nil;

function GetHostForm: TCustomForm;
begin
  Result:= Screen.ActiveCustomForm;
  if (Result = nil) or (not Result.Visible) or (Result.ClassName = 'TfrmHackForm') then
    Result:= frmMain;
end;

function BlendColor(AColor, BColor: TColor; APercent: Integer): TColor;
var
  A, B: LongInt;
begin
  A:= ColorToRGB(AColor);
  B:= ColorToRGB(BColor);
  Result:= RGBToColor(
    Red(A) + (Red(B) - Red(A)) * APercent div 100,
    Green(A) + (Green(B) - Green(A)) * APercent div 100,
    Blue(A) + (Blue(B) - Blue(A)) * APercent div 100);
end;

function FitText(const AText: String; ACanvas: TCanvas; AWidth: Integer): String;
var
  ALength: Integer;
begin
  Result:= AText;
  if ACanvas.TextWidth(Result) <= AWidth then Exit;
  ALength:= UTF8Length(AText);
  while (ALength > 1) and (ACanvas.TextWidth(Result) > AWidth) do
  begin
    Dec(ALength);
    Result:= UTF8Copy(AText, 1, ALength) + '…';
  end;
end;

{en
   Makes the picture darker, each color channel is halved.
}
procedure DarkenBitmap(ABitmap: TBitmap);
var
  I, ACount: PtrInt;
  AAlpha: Cardinal;
  APixel: PCardinal;
  AImage: TLazIntfImage;
begin
  // Change a copy of the picture, then load it back,
  // so the picture handle surely follows the change
  AImage:= ABitmap.CreateIntfImage;
  try
    with AImage.DataDescription do
    begin
      if BitsPerPixel <> 32 then Exit;
      if AlphaPrec > 0 then
        AAlpha:= Cardinal($FF) shl AlphaShift
      else
        AAlpha:= 0;
      ACount:= (PtrInt(BytesPerLine) * Height) div 4;
    end;
    APixel:= PCardinal(AImage.PixelData);
    for I:= 0 to ACount - 1 do
    begin
      APixel^:= ((APixel^ shr 1) and $7F7F7F7F) or AAlpha;
      Inc(APixel);
    end;
    ABitmap.LoadFromIntfImage(AImage);
  finally
    AImage.Free;
  end;
end;

{ TMobileOverlay }

constructor TMobileOverlay.CreateFor(AForm: TCustomForm; ADim: Boolean);
begin
  inherited Create(AForm);
  FDim:= ADim;
  ControlStyle:= ControlStyle + [csOpaque];
  if FDim then
  try
    // The overlay cannot be transparent, so show a picture of the window
    FImage:= AForm.GetFormImage;
    DarkenBitmap(FImage);
  except
    FreeAndNil(FImage);
  end;
  Parent:= AForm;
  SetBounds(0, 0, AForm.ClientWidth, AForm.ClientHeight);
  Anchors:= [akLeft, akTop, akRight, akBottom];
  BringToFront;
end;

destructor TMobileOverlay.Destroy;
begin
  FImage.Free;
  inherited Destroy;
end;

procedure TMobileOverlay.Paint;
begin
  if Assigned(FImage) then
  begin
    Canvas.Draw(0, 0, FImage);
  end
  else begin
    if FDim then
      Canvas.Brush.Color:= BlendColor(clWindow, clBlack, 60)
    else
      Canvas.Brush.Color:= clWindow;
    Canvas.FillRect(ClientRect);
  end;
end;

procedure TMobileOverlay.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Assigned(FOnOutsideClick) then FOnOutsideClick(Self);
end;

{ TMobileList }

constructor TMobileList.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle:= ControlStyle + [csOpaque];
  DoubleBuffered:= True;
  FPressed:= -1;
end;

procedure TMobileList.Clear;
begin
  SetLength(FRows, 0);
  FOffset:= 0;
  FPressed:= -1;
  Invalidate;
end;

function TMobileList.Add(AKind: TMobileRowKind; const ATitle: String;
  const ASubtitle: String; AData: Pointer): Integer;
begin
  Result:= Length(FRows);
  SetLength(FRows, Result + 1);
  FRows[Result].Kind:= AKind;
  FRows[Result].Title:= ATitle;
  FRows[Result].Subtitle:= ASubtitle;
  FRows[Result].Checked:= False;
  FRows[Result].Enabled:= True;
  FRows[Result].HasSubmenu:= False;
  FRows[Result].Data:= AData;
  Invalidate;
end;

function TMobileList.RowHeight(AIndex: Integer): Integer;
begin
  case FRows[AIndex].Kind of
    mrkSeparator: Result:= MobilePx(9);
    mrkSection: Result:= MobilePx(40);
    else begin
      if Length(FRows[AIndex].Subtitle) > 0 then
        Result:= MobilePx(66)
      else
        Result:= MobilePx(48);
    end;
  end;
end;

function TMobileList.RowTop(AIndex: Integer): Integer;
var
  I: Integer;
begin
  Result:= -FOffset;
  for I:= 0 to AIndex - 1 do Inc(Result, RowHeight(I));
end;

function TMobileList.RowAt(Y: Integer): Integer;
var
  I, ATop: Integer;
begin
  ATop:= -FOffset;
  for I:= 0 to High(FRows) do
  begin
    if (Y >= ATop) and (Y < ATop + RowHeight(I)) then Exit(I);
    Inc(ATop, RowHeight(I));
  end;
  Result:= -1;
end;

function TMobileList.ContentHeight: Integer;
var
  I: Integer;
begin
  Result:= 0;
  for I:= 0 to High(FRows) do Inc(Result, RowHeight(I));
end;

procedure TMobileList.SetOffset(AValue: Integer);
begin
  AValue:= EnsureRange(AValue, 0, Max(0, ContentHeight - ClientHeight));
  if AValue <> FOffset then
  begin
    FOffset:= AValue;
    Invalidate;
  end;
end;

function TMobileList.PreferredWidth: Integer;
var
  I, W: Integer;
begin
  Canvas.Font.Assign(Font);
  Result:= MobilePx(160);
  for I:= 0 to High(FRows) do
  begin
    W:= Canvas.TextWidth(FRows[I].Title) + MobilePx(64);
    if W > Result then Result:= W;
  end;
end;

procedure TMobileList.Paint;
var
  R: TRect;
  I, ATop, AHeight, AMargin, ABox: Integer;
  ABack, AText, AAccent, ADim: TColor;
begin
  if FCard then
  begin
    ABack:= clBtnFace;
    AText:= clBtnText;
  end
  else begin
    ABack:= clWindow;
    AText:= clWindowText;
  end;
  AAccent:= clHighlight;
  ADim:= BlendColor(ABack, AText, 55);
  AMargin:= MobilePx(16);

  Canvas.Brush.Style:= bsSolid;
  Canvas.Brush.Color:= ABack;
  Canvas.FillRect(ClientRect);
  Canvas.Font.Assign(Font);

  ATop:= -FOffset;
  for I:= 0 to High(FRows) do
  begin
    AHeight:= RowHeight(I);
    if (ATop + AHeight > 0) and (ATop < ClientHeight) then
    with FRows[I] do
    begin
      R:= Classes.Rect(0, ATop, ClientWidth, ATop + AHeight);
      if (I = FPressed) and not (Kind in [mrkSection, mrkSeparator]) then
      begin
        Canvas.Brush.Color:= BlendColor(ABack, AText, 15);
        Canvas.FillRect(R);
      end;
      Canvas.Brush.Style:= bsClear;
      case Kind of
        mrkSeparator:
          begin
            Canvas.Pen.Color:= BlendColor(ABack, AText, 25);
            Canvas.Line(AMargin, R.Top + AHeight div 2, R.Right - AMargin, R.Top + AHeight div 2);
          end;
        mrkSection:
          begin
            Canvas.Font.Color:= AAccent;
            Canvas.Font.Style:= [];
            Canvas.TextOut(AMargin, R.Bottom - Canvas.TextHeight('Wg') - MobilePx(6), Title);
          end;
        else
          begin
            if Enabled then
              Canvas.Font.Color:= AText
            else
              Canvas.Font.Color:= ADim;
            if Kind = mrkBack then
              Canvas.Font.Style:= [fsBold]
            else
              Canvas.Font.Style:= [];
            if Length(Subtitle) = 0 then
              Canvas.TextOut(AMargin, R.Top + (AHeight - Canvas.TextHeight('Wg')) div 2, Title)
            else begin
              Canvas.TextOut(AMargin, R.Top + MobilePx(8), Title);
              Canvas.Font.Color:= ADim;
              Canvas.Font.Size:= Max(6, (Font.Size * 4) div 5);
              Canvas.TextOut(AMargin, R.Bottom - Canvas.TextHeight('Wg') - MobilePx(8),
                             FitText(Subtitle, Canvas, R.Right - AMargin * 3 - MobilePx(24)));
              Canvas.Font.Assign(Font);
            end;
            // Check box
            if Kind = mrkCheck then
            begin
              ABox:= MobilePx(22);
              R.Left:= R.Right - AMargin - ABox;
              R.Top:= R.Top + (AHeight - ABox) div 2;
              R.Right:= R.Left + ABox;
              R.Bottom:= R.Top + ABox;
              Canvas.Pen.Width:= Max(1, MobilePx(2));
              if Checked then
              begin
                Canvas.Brush.Style:= bsSolid;
                Canvas.Brush.Color:= AAccent;
                Canvas.Pen.Color:= AAccent;
                Canvas.Rectangle(R);
                Canvas.Pen.Color:= clHighlightText;
                Canvas.Polyline([Classes.Point(R.Left + ABox div 5, R.Top + ABox div 2),
                                 Classes.Point(R.Left + ABox * 2 div 5, R.Bottom - ABox div 4),
                                 Classes.Point(R.Right - ABox div 5, R.Top + ABox div 4)]);
              end
              else begin
                Canvas.Pen.Color:= ADim;
                Canvas.Rectangle(R);
              end;
              Canvas.Pen.Width:= 1;
            end
            // Submenu
            else if HasSubmenu then
            begin
              Canvas.Font.Color:= ADim;
              Canvas.TextOut(R.Right - AMargin - Canvas.TextWidth('›'),
                             R.Top + (AHeight - Canvas.TextHeight('Wg')) div 2, '›');
            end;
          end;
      end;
      // Separator under the items of the settings page
      if (not FCard) and (Kind in [mrkItem, mrkCheck]) then
      begin
        Canvas.Pen.Color:= BlendColor(ABack, AText, 15);
        Canvas.Line(0, ATop + AHeight - 1, ClientWidth, ATop + AHeight - 1);
      end;
      Canvas.Brush.Style:= bsSolid;
    end;
    Inc(ATop, AHeight);
  end;

  if FCard then
  begin
    Canvas.Brush.Style:= bsClear;
    Canvas.Pen.Color:= BlendColor(ABack, AText, 25);
    Canvas.Rectangle(ClientRect);
    Canvas.Brush.Style:= bsSolid;
  end;
end;

procedure TMobileList.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  FDragging:= False;
  FDownY:= Y;
  FDownOffset:= FOffset;
  FPressed:= RowAt(Y);
  if (FPressed >= 0) and ((FRows[FPressed].Kind in [mrkSection, mrkSeparator]) or
                          not FRows[FPressed].Enabled) then
    FPressed:= -1;
  Invalidate;
end;

procedure TMobileList.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if not (ssLeft in Shift) then Exit;
  if (not FDragging) and (Abs(Y - FDownY) > MobilePx(8)) then
  begin
    FDragging:= True;
    FPressed:= -1;
    Invalidate;
  end;
  if FDragging then SetOffset(FDownOffset - (Y - FDownY));
end;

procedure TMobileList.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  AIndex: Integer;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  AIndex:= FPressed;
  FPressed:= -1;
  Invalidate;
  if (not FDragging) and (AIndex >= 0) and (AIndex = RowAt(Y)) then
  begin
    if Assigned(FOnRowClick) then FOnRowClick(Self, AIndex);
  end;
  FDragging:= False;
end;

function TMobileList.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  SetOffset(FOffset - (WheelDelta * MobilePx(48)) div 120);
  Result:= True;
end;

{ TMobileMenu }

constructor TMobileMenu.Create(AForm: TCustomForm; ARoot: TMenuItem; const APoint: TPoint);
begin
  FRoot:= ARoot;
  FCurrent:= ARoot;
  FOverlay:= TMobileOverlay.CreateFor(AForm, True);
  FOverlay.OnOutsideClick:= @OutsideClick;
  FPoint:= FOverlay.ScreenToClient(APoint);
  FList:= TMobileList.Create(FOverlay);
  FList.Card:= True;
  FList.Parent:= FOverlay;
  FList.OnRowClick:= @RowClick;
  Fill;
end;

destructor TMobileMenu.Destroy;
begin
  FOverlay.Free;
  inherited Destroy;
end;

procedure TMobileMenu.Fill;
var
  I: Integer;
  AItem: TMenuItem;
  ALastLine: Boolean;
  AIndex: Integer;
begin
  FList.Clear;
  if FCurrent <> FRoot then
    FList.Add(mrkBack, '‹  ' + StripHotkey(FCurrent.Caption));

  ALastLine:= True;
  for I:= 0 to FCurrent.Count - 1 do
  begin
    AItem:= FCurrent.Items[I];
    if not AItem.Visible then Continue;
    if AItem.IsLine then
    begin
      // No doubled separators
      if not ALastLine then FList.Add(mrkSeparator, EmptyStr);
      ALastLine:= True;
      Continue;
    end;
    ALastLine:= False;
    if AItem.Checked then
      AIndex:= FList.Add(mrkItem, '✓ ' + StripHotkey(AItem.Caption), EmptyStr, AItem)
    else
      AIndex:= FList.Add(mrkItem, StripHotkey(AItem.Caption), EmptyStr, AItem);
    FList.FRows[AIndex].Enabled:= AItem.Enabled;
    FList.FRows[AIndex].HasSubmenu:= AItem.Count > 0;
  end;
  // No separator at the end
  if (Length(FList.FRows) > 0) and (FList.FRows[High(FList.FRows)].Kind = mrkSeparator) then
    SetLength(FList.FRows, Length(FList.FRows) - 1);
  Place;
end;

procedure TMobileMenu.Place;
var
  W, H, X, Y, AMargin: Integer;
begin
  AMargin:= MobilePx(8);
  W:= Min(FList.PreferredWidth, FOverlay.ClientWidth - AMargin * 2);
  H:= Min(FList.ContentHeight, FOverlay.ClientHeight - AMargin * 2);
  // Menus opened at the right side grow to the left
  if FPoint.X > FOverlay.ClientWidth div 2 then
    X:= FPoint.X - W
  else
    X:= FPoint.X;
  X:= EnsureRange(X, AMargin, FOverlay.ClientWidth - W - AMargin);
  Y:= EnsureRange(FPoint.Y, AMargin, FOverlay.ClientHeight - H - AMargin);
  FList.SetBounds(X, Y, W, H);
  FList.Invalidate;
end;

procedure TMobileMenu.OutsideClick(Sender: TObject);
begin
  FSelected:= nil;
  FDone:= True;
end;

procedure TMobileMenu.RowClick(Sender: TObject; AIndex: Integer);
var
  AItem: TMenuItem;
begin
  if FList.FRows[AIndex].Kind = mrkBack then
  begin
    FCurrent:= FCurrent.Parent;
    Fill;
    Exit;
  end;
  AItem:= TMenuItem(FList.FRows[AIndex].Data);
  if not Assigned(AItem) then Exit;
  if AItem.Count > 0 then
  begin
    FCurrent:= AItem;
    Fill;
  end
  else begin
    FSelected:= AItem;
    FDone:= True;
  end;
end;

function TMobileMenu.Execute: TMenuItem;
begin
  FDone:= False;
  FOverlay.Show;
  FOverlay.BringToFront;
  // Popup menus are modal, the caller expects the menu to be closed
  while not FDone do
  begin
    Application.HandleMessage;
    if Application.Terminated then Break;
  end;
  FOverlay.Hide;
  Result:= FSelected;
end;

function ShowMenuItems(ARoot: TMenuItem; X, Y: Integer): TMenuItem;
var
  AMenu: TMobileMenu;
begin
  AMenu:= TMobileMenu.Create(GetHostForm, ARoot, Classes.Point(X, Y));
  try
    Result:= AMenu.Execute;
  finally
    AMenu.Free;
  end;
end;

procedure MobileShowPopupMenu(APopupMenu: TPopupMenu; X, Y: Integer);
var
  AItem: TMenuItem;
begin
  AItem:= ShowMenuItems(APopupMenu.Items, X, Y);
  if Assigned(AItem) then AItem.Click;
  APopupMenu.Close;
end;

{$IF DEFINED(LCLQT5)}
type

  { TMobileWSPopupMenu }

  TMobileWSPopupMenu = class(TQtWSPopupMenu)
  published
    class procedure Popup(const APopupMenu: TPopupMenu; const X, Y: Integer); override;
  end;

class procedure TMobileWSPopupMenu.Popup(const APopupMenu: TPopupMenu; const X, Y: Integer);
begin
  if gMobileMode then
    MobileShowPopupMenu(APopupMenu, X, Y)
  else
    inherited Popup(APopupMenu, X, Y);
end;

{en
   Popup windows do not work on Sailfish OS, so all the popup menus
   are shown inside the window. The widgetset class cannot be registered
   for the second time (its memory is freed twice at the exit), so only
   the popup method of the already registered class is replaced.
   Registration of a parent class (TMenu) copies the methods again.
}
procedure HookPopupMenus;
var
  I: Integer;
  AVmt: PPointer;
  AOld, ANew: Pointer;
  AClass: TWSLCLComponentClass;
begin
  // Do not register the class here, an early registration (before its
  // parent class) corrupts the memory, wait until LCL registers it
  AClass:= FindWSRegistered(TPopupMenu);
  if AClass = nil then Exit;
  AOld:= TQtWSPopupMenu.MethodAddress('Popup');
  ANew:= TMobileWSPopupMenu.MethodAddress('Popup');
  if (AOld = nil) or (ANew = nil) then Exit;
  AVmt:= PPointer(Pointer(AClass) + vmtMethodStart);
  for I:= 0 to 1023 do
  begin
    if AVmt[I] = nil then Break;
    if AVmt[I] = AOld then
    begin
      AVmt[I]:= ANew;
      Break;
    end;
  end;
end;
{$ENDIF}

procedure MobileHookPopupMenus;
begin
{$IF DEFINED(LCLQT5)}
  if gMobileMode then HookPopupMenus;
{$ENDIF}
end;

{ Main menu }

type
  TMainMenuHandler = class
    procedure ItemClick(Sender: TObject);
  end;

var
  MainMenuHandler: TMainMenuHandler = nil;

const
  MM_EXIT = 1;
  MM_SETTINGS = 2;
  MM_THEME = 3;
  MM_HELP = 4;

procedure TMainMenuHandler.ItemClick(Sender: TObject);
begin
  case TMenuItem(Sender).Tag of
    MM_EXIT:     frmMain.Commands.cm_Exit([]);
    MM_SETTINGS: MobileShowSettings;
    MM_THEME:    MobileToggleTheme;
    MM_HELP:     frmMain.Commands.cm_HelpIndex([]);
  end;
end;

procedure MobileShowMainMenu(const APoint: TPoint);

  procedure AddItem(const ACaption: String; ATag: Integer);
  var
    AItem: TMenuItem;
  begin
    AItem:= TMenuItem.Create(MainMenu);
    AItem.Caption:= ACaption;
    AItem.Tag:= ATag;
    AItem.OnClick:= @MainMenuHandler.ItemClick;
    MainMenu.Items.Add(AItem);
  end;

begin
  if not Assigned(MainMenuHandler) then MainMenuHandler:= TMainMenuHandler.Create;
  // Owned by the main window, so it is freed together with it
  if Assigned(MainMenu) then MainMenu.Items.Clear
  else MainMenu:= TPopupMenu.Create(frmMain);
  AddItem(rsMobileMenuExit, MM_EXIT);
  AddItem(rsMobileMenuSettings, MM_SETTINGS);
  if MobileDarkTheme then
    AddItem(rsMobileMenuDarkToLight, MM_THEME)
  else
    AddItem(rsMobileMenuLightToDark, MM_THEME);
  AddItem(rsMobileMenuHelp, MM_HELP);
  MobileHookPopupMenus;
  MainMenu.PopUp(APoint.X, APoint.Y);
end;

{ Theme }

procedure MobileToggleTheme;
var
  I: Integer;
  AProcess: TProcess;
begin
  if MobileDarkTheme then
    gMobileTheme:= 2
  else
    gMobileTheme:= 1;
  SaveEarlyConfig;
  // Colors of every control are set when it is created, so the simplest
  // reliable way is to start again, the tabs are saved and restored
  AProcess:= TProcess.Create(nil);
  try
    AProcess.Executable:= '/bin/sh';
    AProcess.Parameters.Add('-c');
    AProcess.Parameters.Add('sleep 1; exec "$0" "$@"');
    for I:= 0 to ParamCount do
      AProcess.Parameters.Add(ParamStr(I));
    AProcess.Options:= [];
    AProcess.Execute;
  finally
    AProcess.Free;
  end;
  frmMain.Commands.cm_Exit([]);
end;

{ TMobileSettings }

constructor TMobileSettings.Create;
begin
  FOverlay:= TMobileOverlay.CreateFor(frmMain, False);
  FList:= TMobileList.Create(FOverlay);
  FList.Parent:= FOverlay;
  FList.Align:= alClient;
  FList.OnRowClick:= @RowClick;
  Fill;
  FOverlay.Show;
  FOverlay.BringToFront;
end;

destructor TMobileSettings.Destroy;
begin
  FOverlay.Free;
  inherited Destroy;
end;

procedure TMobileSettings.Fill;

  procedure AddItem(const ATitle, ASubtitle: String; AAction: TSettingAction);
  begin
    FList.Add(mrkItem, ATitle, ASubtitle, Pointer(PtrInt(Ord(AAction))));
  end;

  procedure AddCheck(const ATitle, ASubtitle: String; AAction: TSettingAction; AChecked: Boolean);
  var
    AIndex: Integer;
  begin
    AIndex:= FList.Add(mrkCheck, ATitle, ASubtitle, Pointer(PtrInt(Ord(AAction))));
    FList.FRows[AIndex].Checked:= AChecked;
  end;

var
  AOffset: Integer;
begin
  AOffset:= FList.FOffset;
  FList.Clear;
  FList.Add(mrkBack, '‹  ' + rsMobileSettings, EmptyStr, Pointer(-1));
  FList.Add(mrkSection, rsMobileSettingsAbout);
  AddItem(rsMobileSettingsAboutItem, EmptyStr, saAbout);
  AddItem(rsMobileMenuHelp, EmptyStr, saHelp);
  FList.Add(mrkSection, rsMobileSettingsGeneral);
  AddItem(rsMobileSettingsLanguage, ExtractFileName(gPOFileName), saLanguage);
  AddItem(rsMobileSettingsDateTime,
          FormatDateTime(gDateTimeFormat, EncodeDate(1999, 12, 31) + EncodeTime(22, 33, 0, 0)),
          saDateTime);
  AddCheck(rsMobileSettingsHidden, rsMobileSettingsHiddenHint, saHidden, gShowSystemFiles);
  AddItem(rsMobileSettingsIgnore, rsMobileSettingsIgnoreHint, saIgnore);
  AddItem(rsMobileSettingsFonts, rsMobileSettingsFontsHint, saFonts);
  AddItem(rsMobileSettingsAssoc, rsMobileSettingsAssocHint, saAssoc);
  AddItem(rsMobileSettingsPlugins, rsMobileSettingsPluginsHint, saPlugins);
  AddCheck(rsMobileSettingsLog, gLogFileName, saLog, gLogFile);
  FList.Add(mrkSection, rsMobileSettingsMore);
  AddItem(rsMobileSettingsAllCommands, rsMobileSettingsAllCommandsHint, saAllCommands);
  AddItem(rsMobileSettingsAllOptions, rsMobileSettingsAllOptionsHint, saAllOptions);
  FList.SetOffset(AOffset);
end;

procedure TMobileSettings.Close(Data: PtrInt);
begin
  if Settings = Self then Settings:= nil;
  Free;
end;

procedure TMobileSettings.RowClick(Sender: TObject; AIndex: Integer);
var
  P: TPoint;
  AItem: TMenuItem;
begin
  if FList.FRows[AIndex].Kind = mrkBack then
  begin
    Application.QueueAsyncCall(@Close, 0);
    Exit;
  end;

  with frmMain.Commands do
  case TSettingAction(PtrInt(FList.FRows[AIndex].Data)) of
    saAbout:    cm_About([]);
    saHelp:     cm_HelpIndex([]);
    saLanguage: cm_Options(['TfrmOptionsLanguage']);
    saDateTime: cm_Options(['TfrmOptionsFilesViews']);
    saHidden:
      begin
        cm_ShowSysFiles([]);
        SaveGlobs;
      end;
    saIgnore:   cm_Options(['TfrmOptionsIgnoreList']);
    saFonts:    cm_Options(['TfrmOptionsFonts']);
    saAssoc:    cm_Options(['TfrmOptionsFileAssoc']);
    saPlugins:  cm_Options(['TfrmOptionsPluginsGroup']);
    saLog:
      begin
        gLogFile:= not gLogFile;
        SaveGlobs;
      end;
    saAllCommands:
      begin
        // The whole main menu of Double Commander
        P:= FList.ClientToScreen(Classes.Point(0, 0));
        AItem:= ShowMenuItems(frmMain.mnuMain.Items, P.X, P.Y);
        if Assigned(AItem) then AItem.Click;
      end;
    saAllOptions: cm_Options([]);
  end;
  Fill;
end;

procedure MobileShowSettings;
begin
  if Assigned(Settings) then Exit;
  Settings:= TMobileSettings.Create;
end;

{ TMobileMarkDialog }

constructor TMobileMarkDialog.Create;
var
  Y, W, AMargin: Integer;
  ALabel: TLabel;

  function AddButton(const ACaption: String; ATag: Integer): TButton;
  begin
    Result:= TButton.Create(FPanel);
    Result.Parent:= FPanel;
    Result.Caption:= ACaption;
    Result.Tag:= ATag;
    Result.OnClick:= @ButtonClick;
  end;

begin
  FOverlay:= TMobileOverlay.CreateFor(frmMain, True);
  FOverlay.OnOutsideClick:= @OutsideClick;

  AMargin:= MobilePx(16);
  W:= Min(FOverlay.ClientWidth - MobilePx(24), MobilePx(420));

  FPanel:= TPanel.Create(FOverlay);
  FPanel.Parent:= FOverlay;
  FPanel.BevelOuter:= bvNone;
  FPanel.BorderStyle:= bsSingle;
  FPanel.Color:= clBtnFace;

  Y:= AMargin;
  ALabel:= TLabel.Create(FPanel);
  ALabel.AutoSize:= False;
  ALabel.SetBounds(AMargin, Y, W - AMargin * 2, MobilePx(28));
  ALabel.Caption:= rsMobileMarkTitle;
  ALabel.Font.Style:= [fsBold];
  ALabel.Parent:= FPanel;
  Inc(Y, MobilePx(34));

  ALabel:= TLabel.Create(FPanel);
  ALabel.AutoSize:= False;
  ALabel.WordWrap:= True;
  ALabel.SetBounds(AMargin, Y, W - AMargin * 2, MobilePx(44));
  ALabel.Caption:= rsMobileMarkHint;
  ALabel.Parent:= FPanel;
  Inc(Y, MobilePx(52));

  FMask:= TEdit.Create(FPanel);
  FMask.Parent:= FPanel;
  FMask.Text:= '*';
  FMask.SetBounds(AMargin, Y, W - AMargin * 2, MobilePx(40));
  Inc(Y, MobilePx(52));

  FFiles:= TCheckBox.Create(FPanel);
  FFiles.Parent:= FPanel;
  FFiles.Caption:= rsMobileMarkFiles;
  FFiles.Checked:= True;
  FFiles.SetBounds(AMargin, Y, (W - AMargin * 2) div 2, MobilePx(36));

  FFolders:= TCheckBox.Create(FPanel);
  FFolders.Parent:= FPanel;
  FFolders.Caption:= rsMobileMarkFolders;
  FFolders.Checked:= True;
  FFolders.SetBounds(W div 2, Y, (W - AMargin * 2) div 2, MobilePx(36));
  Inc(Y, MobilePx(48));

  AddButton(rsMobileMarkSelect, Ord(mmSelect)).SetBounds(AMargin, Y, (W - AMargin * 3) div 2, MobilePx(44));
  AddButton(rsMobileMarkUnselect, Ord(mmUnselect)).SetBounds(W div 2 + AMargin div 2, Y, (W - AMargin * 3) div 2, MobilePx(44));
  Inc(Y, MobilePx(52));
  AddButton(rsMobileMarkInvert, Ord(mmInvert)).SetBounds(AMargin, Y, W - AMargin * 2, MobilePx(44));
  Inc(Y, MobilePx(44) + AMargin);

  FPanel.SetBounds((FOverlay.ClientWidth - W) div 2, (FOverlay.ClientHeight - Y) div 3, W, Y);

  FOverlay.Show;
  FOverlay.BringToFront;
end;

destructor TMobileMarkDialog.Destroy;
begin
  FOverlay.Free;
  inherited Destroy;
end;

procedure TMobileMarkDialog.Close(Data: PtrInt);
begin
  if MarkDialog = Self then MarkDialog:= nil;
  Free;
end;

procedure TMobileMarkDialog.OutsideClick(Sender: TObject);
begin
  Application.QueueAsyncCall(@Close, 0);
end;

procedure TMobileMarkDialog.ButtonClick(Sender: TObject);
var
  AView: TObject;
begin
  AView:= frmMain.ActiveFrame;
  if AView is TTouchFileView then
  begin
    TTouchFileView(AView).MarkByMask(FMask.Text, FFiles.Checked, FFolders.Checked,
                                     TMarkMode(TButton(Sender).Tag));
  end;
  Application.QueueAsyncCall(@Close, 0);
end;

procedure MobileShowMarkDialog;
begin
  if Assigned(MarkDialog) then Exit;
  MarkDialog:= TMobileMarkDialog.Create;
end;

finalization
  FreeAndNil(MainMenuHandler);

end.
