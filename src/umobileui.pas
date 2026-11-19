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
  Classes, SysUtils, Types, Menus, Forms, ActnList, Controls, SynEdit;

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
{en
   Hides the menu bar of a window, Qt keeps it visible otherwise.
}
procedure MobileHideMenuBar(AForm: TCustomForm);
{en
   Changes the editor window to look like a phone application: a header
   with the file name, save, find, find next and menu buttons, wrapped
   text without line numbers, no menu bar, tool bar and status bar.
}
procedure MobileSetupEditor(AForm: TForm; AEditor: TSynEdit;
  ASave, ASaveAs, AFind, AFindNext: TBasicAction; AToolBar, AStatusBar: TControl);

implementation

uses
  Graphics, StdCtrls, ExtCtrls, Buttons, LCLType, LCLIntf, LCLProc,
  SynEditWrappedView, uPixMapManager,
  Math, GraphType, IntfGraphics, FPImage, LazUTF8, Process, uGlobsPaths, uGlobs, uLng, uMobile, uEarlyConfig,
  uTouchFileView, fMain
{$IF DEFINED(LCLQT5)}
  , WSLCLClasses, QtWSMenus, qtwidgets, qtobjects, qt5
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
                    saFontSize, saLog, saAdvanced);

  TSettingsPage = (spMain, spLanguage, spDateTime, spFontSize, spIgnore);

  { TMobileSettings }

  {en
     Simple settings shown inside the main window
  }
  TMobileSettings = class
  private
    FOverlay: TMobileOverlay;
    FList: TMobileList;
    FMemo: TMemo;
    FPage: TSettingsPage;
    FValues: TStringList;
    procedure Fill;
    procedure FillMain;
    procedure FillLanguage;
    procedure FillDateTime;
    procedure FillFontSize;
    procedure FillIgnore;
    procedure ShowPage(APage: TSettingsPage);
    procedure Back;
    procedure ChoiceClick(AIndex: Integer);
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
  // Not dimmed overlay covers the window completely
  if not FDim then ControlStyle:= ControlStyle + [csOpaque];
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
{$IF DEFINED(LCLQT5)}
var
  AColor: TQColor;
{$ENDIF}
begin
{$IF DEFINED(LCLQT5)}
  if FDim then
  begin
    // The window stays visible under a translucent shade
    QColor_fromRgb(@AColor, 0, 0, 0, 140);
    QPainter_fillRect(TQtDeviceContext(Canvas.Handle).Widget, 0, 0, Width, Height, @AColor);
    Exit;
  end;
{$ENDIF}
  begin
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

{en
   Starts the application again, settings which are applied
   when the controls are created need it.
}
procedure MobileRestart;
var
  I: Integer;
  AProcess: TProcess;
begin
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

procedure MobileToggleTheme;
begin
  if MobileDarkTheme then
    gMobileTheme:= 2
  else
    gMobileTheme:= 1;
  SaveEarlyConfig;
  // Colors of every control are set when it is created, so the simplest
  // reliable way is to start again, the tabs are saved and restored
  MobileRestart;
end;

{ TMobileSettings }

const
  DATE_TIME_FORMATS: array[0..6] of String = (
    'dd.mm.yy hh:nn', 'dd.mm.yyyy hh:nn', 'dd.mm.yyyy hh:nn:ss', 'd.m.yyyy hh:nn',
    'yyyy-mm-dd hh:nn', 'yyyy-mm-dd hh:nn:ss', 'mm/dd/yy hh:nn');
  FONT_SIZES: array[0..7] of Integer = (8, 9, 10, 11, 12, 14, 16, 18);

constructor TMobileSettings.Create;
begin
  FValues:= TStringList.Create;
  FOverlay:= TMobileOverlay.CreateFor(frmMain, False);
  FList:= TMobileList.Create(FOverlay);
  FList.Parent:= FOverlay;
  FList.Align:= alClient;
  FList.OnRowClick:= @RowClick;
  FMemo:= TMemo.Create(FOverlay);
  FMemo.Parent:= FOverlay;
  FMemo.Align:= alClient;
  FMemo.ScrollBars:= ssAutoVertical;
  FMemo.Visible:= False;
  ShowPage(spMain);
  FOverlay.Show;
  FOverlay.BringToFront;
end;

destructor TMobileSettings.Destroy;
begin
  FOverlay.Free;
  FValues.Free;
  inherited Destroy;
end;

procedure TMobileSettings.ShowPage(APage: TSettingsPage);
begin
  FPage:= APage;
  FList.FOffset:= 0;
  // The ignore list is a text, the other pages are lists
  if APage = spIgnore then
  begin
    FList.Align:= alTop;
    FList.Height:= MobilePx(48 + 66);
    FMemo.Visible:= True;
  end
  else begin
    FMemo.Visible:= False;
    FList.Align:= alClient;
  end;
  Fill;
end;

procedure TMobileSettings.Fill;
begin
  FList.Clear;
  FValues.Clear;
  case FPage of
    spMain:     FillMain;
    spLanguage: FillLanguage;
    spDateTime: FillDateTime;
    spFontSize: FillFontSize;
    spIgnore:   FillIgnore;
  end;
end;

procedure TMobileSettings.FillMain;

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

begin
  FList.Add(mrkBack, '‹  ' + rsMobileSettings);
  FList.Add(mrkSection, rsMobileSettingsAbout);
  AddItem(rsMobileSettingsAboutItem, EmptyStr, saAbout);
  AddItem(rsMobileMenuHelp, EmptyStr, saHelp);
  FList.Add(mrkSection, rsMobileSettingsGeneral);
  AddItem(rsMobileSettingsLanguage, GetLanguageName(gpLngDir + gPOFileName), saLanguage);
  AddItem(rsMobileSettingsDateTime,
          FormatDateTime(gDateTimeFormat, EncodeDate(1999, 12, 31) + EncodeTime(22, 33, 0, 0)),
          saDateTime);
  AddCheck(rsMobileSettingsHidden, rsMobileSettingsHiddenHint, saHidden, gShowSystemFiles);
  AddItem(rsMobileSettingsIgnore, rsMobileSettingsIgnoreHint, saIgnore);
  AddItem(rsMobileSettingsFontSize, IntToStr(gFonts[dcfMain].Size), saFontSize);
  AddCheck(rsMobileSettingsLog, rsMobileSettingsLogHint, saLog, gLogFile);
  FList.Add(mrkSection, rsMobileSettingsMore);
  AddItem(rsMobileSettingsAllOptions, rsMobileSettingsAllOptionsHint, saAdvanced);
end;

procedure TMobileSettings.FillLanguage;
var
  I, AIndex: Integer;
  ASearch: TSearchRec;
  ANames: TStringList;
begin
  FList.Add(mrkBack, '‹  ' + rsMobileSettingsLanguage);
  ANames:= TStringList.Create;
  try
    ANames.Sorted:= True;
    if FindFirst(gpLngDir + '*.po*', faAnyFile, ASearch) = 0 then
    try
      repeat
        ANames.Add(GetLanguageName(gpLngDir + ASearch.Name) + '=' + ASearch.Name);
      until FindNext(ASearch) <> 0;
    finally
      FindClose(ASearch);
    end;
    for I:= 0 to ANames.Count - 1 do
    begin
      AIndex:= FList.Add(mrkCheck, ANames.Names[I], EmptyStr, Pointer(PtrInt(FValues.Count)));
      FList.FRows[AIndex].Checked:= (ANames.ValueFromIndex[I] = gPOFileName);
      FValues.Add(ANames.ValueFromIndex[I]);
    end;
  finally
    ANames.Free;
  end;
end;

procedure TMobileSettings.FillDateTime;
var
  I, AIndex: Integer;
begin
  FList.Add(mrkBack, '‹  ' + rsMobileSettingsDateTime);
  for I:= Low(DATE_TIME_FORMATS) to High(DATE_TIME_FORMATS) do
  begin
    AIndex:= FList.Add(mrkCheck, FormatDateTime(DATE_TIME_FORMATS[I], Now), EmptyStr,
                       Pointer(PtrInt(FValues.Count)));
    FList.FRows[AIndex].Checked:= (DATE_TIME_FORMATS[I] = gDateTimeFormat);
    FValues.Add(DATE_TIME_FORMATS[I]);
  end;
end;

procedure TMobileSettings.FillFontSize;
var
  I, AIndex: Integer;
begin
  FList.Add(mrkBack, '‹  ' + rsMobileSettingsFontSize);
  for I:= Low(FONT_SIZES) to High(FONT_SIZES) do
  begin
    AIndex:= FList.Add(mrkCheck, IntToStr(FONT_SIZES[I]), EmptyStr, Pointer(PtrInt(FValues.Count)));
    FList.FRows[AIndex].Checked:= (FONT_SIZES[I] = gFonts[dcfMain].Size);
    FValues.Add(IntToStr(FONT_SIZES[I]));
  end;
end;

procedure TMobileSettings.FillIgnore;
begin
  FList.Add(mrkBack, '‹  ' + rsMobileSettingsIgnore);
  FList.Add(mrkItem, rsMobileSettingsIgnoreEdit, rsMobileSettingsIgnoreEditHint);
  FList.FRows[High(FList.FRows)].Enabled:= False;
  FMemo.Lines.Assign(glsIgnoreList);
end;

procedure TMobileSettings.Back;
begin
  if FPage = spMain then
  begin
    Application.QueueAsyncCall(@Close, 0);
    Exit;
  end;
  if FPage = spIgnore then
  begin
    // Files are hidden as soon as the list is not empty
    glsIgnoreList.Assign(FMemo.Lines);
    gIgnoreListFileEnabled:= Length(Trim(FMemo.Text)) > 0;
    SaveGlobs;
    frmMain.FrameLeft.Reload(True);
    frmMain.FrameRight.Reload(True);
  end;
  ShowPage(spMain);
end;

procedure TMobileSettings.ChoiceClick(AIndex: Integer);
var
  AValue: String;
begin
  AValue:= FValues[AIndex];
  case FPage of
    spLanguage:
      if AValue <> gPOFileName then
      begin
        // Captions are translated when the windows are created
        gPOFileName:= AValue;
        SaveGlobs;
        MobileRestart;
        Exit;
      end;
    spDateTime:
      begin
        gDateTimeFormat:= AValue;
        SaveGlobs;
        frmMain.UpdateWindowView;
      end;
    spFontSize:
      begin
        gFonts[dcfMain].Size:= StrToInt(AValue);
        SaveGlobs;
        frmMain.UpdateWindowView;
      end;
  end;
  ShowPage(spMain);
end;

procedure TMobileSettings.Close(Data: PtrInt);
begin
  if Settings = Self then Settings:= nil;
  Free;
end;

procedure TMobileSettings.RowClick(Sender: TObject; AIndex: Integer);
begin
  if FList.FRows[AIndex].Kind = mrkBack then
  begin
    Back;
    Exit;
  end;

  if FPage <> spMain then
  begin
    if FList.FRows[AIndex].Kind = mrkCheck then
      ChoiceClick(PtrInt(FList.FRows[AIndex].Data));
    Exit;
  end;

  with frmMain.Commands do
  case TSettingAction(PtrInt(FList.FRows[AIndex].Data)) of
    saAbout:    cm_About([]);
    saHelp:     cm_HelpIndex([]);
    saLanguage: ShowPage(spLanguage);
    saDateTime: ShowPage(spDateTime);
    saFontSize: ShowPage(spFontSize);
    saIgnore:   ShowPage(spIgnore);
    saHidden:
      begin
        cm_ShowSysFiles([]);
        SaveGlobs;
        Fill;
      end;
    saLog:
      begin
        gLogFile:= not gLogFile;
        SaveGlobs;
        Fill;
      end;
    saAdvanced: cm_Options([]);
  end;
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

{ Menu bar }

type
  TMenuBarHider = class
    procedure Hide(Data: PtrInt);
  end;

var
  MenuBarHider: TMenuBarHider = nil;

procedure TMenuBarHider.Hide(Data: PtrInt);
var
  AForm: TCustomForm absolute Data;
  I: Integer;
  AFound: Boolean;
begin
  // The window could be closed in the meantime
  AFound:= False;
  for I:= 0 to Screen.CustomFormCount - 1 do
    if Screen.CustomForms[I] = AForm then AFound:= True;
  if not AFound then Exit;
  if not AForm.HandleAllocated then
  begin
    Application.QueueAsyncCall(@Hide, Data);
    Exit;
  end;
{$IF DEFINED(LCLQT5)}
  if TQtWidget(AForm.Handle) is TQtMainWindow then
  begin
    with TQtMainWindow(AForm.Handle) do
      if Assigned(MenuBar) then MenuBar.setVisible(False);
  end;
{$ENDIF}
end;

procedure MobileHideMenuBar(AForm: TCustomForm);
begin
  if not Assigned(MenuBarHider) then MenuBarHider:= TMenuBarHider.Create;
  if Assigned(AForm.Menu) then AForm.Menu:= nil;
  Application.QueueAsyncCall(@MenuBarHider.Hide, PtrInt(AForm));
end;

{ TMobileEditorHeader }

type
  TMobileEditorHeader = class(TComponent)
  private
    FForm: TForm;
    FEditor: TSynEdit;
    FSpace, FPanel: TPanel;
    FTitle: TLabel;
    FButtons: array[0..3] of TSpeedButton;
    FSaveAs: TBasicAction;
    FMenu: TPopupMenu;
    FTimer: TTimer;
    // Scrolling by a finger
    FDownY, FDownTop: Integer;
    FScrolling: Boolean;
    FOldMouseDown: TMouseEvent;
    FOldMouseMove: TMouseMoveEvent;
    FOldMouseUp: TMouseEvent;
    procedure Deselect(Data: PtrInt);
    procedure EditorMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure EditorMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure EditorMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure PanelResize(Sender: TObject);
    procedure SpaceResize(Sender: TObject);
    procedure TimerTick(Sender: TObject);
    procedure MenuClick(Sender: TObject);
    procedure ItemClick(Sender: TObject);
  public
    constructor CreateFor(AForm: TForm; AEditor: TSynEdit;
      ASave, ASaveAs, AFind, AFindNext: TBasicAction);
  end;

  // Access to the view position, it counts wrapped lines
  TSynEditAccess = class(TSynEdit);

const
  EM_SAVE_AS = 1;
  EM_CLOSE = 2;
  EM_SETTINGS = 3;

function CreateFindNextIcon(ASize: Integer): TBitmap;
var
  ABase, AArrow: TBitmap;
begin
  // There is no find next icon, so the arrow is drawn over the find icon
  Result:= TBitmap.Create;
  Result.SetSize(ASize, ASize);
  Result.Transparent:= True;
  Result.TransparentColor:= clFuchsia;
  Result.Canvas.Brush.Color:= clFuchsia;
  Result.Canvas.FillRect(0, 0, ASize, ASize);
  ABase:= PixMapManager.GetThemeIcon('edit-find', ASize);
  AArrow:= PixMapManager.GetThemeIcon('go-next', ASize div 2);
  try
    if Assigned(ABase) then Result.Canvas.Draw(0, 0, ABase);
    if Assigned(AArrow) then Result.Canvas.Draw(ASize - AArrow.Width, ASize - AArrow.Height, AArrow);
  finally
    ABase.Free;
    AArrow.Free;
  end;
end;

constructor TMobileEditorHeader.CreateFor(AForm: TForm; AEditor: TSynEdit;
  ASave, ASaveAs, AFind, AFindNext: TBasicAction);

  function AddItem(const ACaption: String; ATag: Integer): TMenuItem;
  begin
    Result:= TMenuItem.Create(FMenu);
    Result.Caption:= ACaption;
    Result.Tag:= ATag;
    Result.OnClick:= @ItemClick;
    FMenu.Items.Add(Result);
  end;

const
  ICONS: array[0..2] of String = ('document-save', 'edit-find', '');
var
  I, ASize: Integer;
  ABitmap: TBitmap;
begin
  inherited Create(AForm);
  FForm:= AForm;
  FEditor:= AEditor;
  FSaveAs:= ASaveAs;
  ASize:= MobileIconSize(24);

  // Space for the display cutout
  FSpace:= TPanel.Create(Self);
  FSpace.Parent:= AForm;
  FSpace.Align:= alTop;
  FSpace.BevelOuter:= bvNone;
  FSpace.Caption:= EmptyStr;
  FSpace.OnResize:= @SpaceResize;
  FSpace.Height:= MobileTopMargin;
  FSpace.Visible:= MobileTopMargin > 0;

  FPanel:= TPanel.Create(Self);
  FPanel.Parent:= AForm;
  FPanel.Align:= alTop;
  FPanel.BevelOuter:= bvNone;
  FPanel.Caption:= EmptyStr;
  FPanel.OnResize:= @PanelResize;
  FPanel.Top:= FSpace.Top + FSpace.Height;

  FTitle:= TLabel.Create(Self);
  FTitle.Parent:= FPanel;
  FTitle.AutoSize:= False;
  FTitle.Layout:= tlCenter;
  FTitle.Font.Style:= [fsBold];

  for I:= 0 to High(FButtons) do
  begin
    FButtons[I]:= TSpeedButton.Create(Self);
    FButtons[I].Parent:= FPanel;
    FButtons[I].Flat:= True;
  end;
  FButtons[0].Action:= ASave;
  FButtons[1].Action:= AFind;
  FButtons[2].Action:= AFindNext;
  FButtons[3].OnClick:= @MenuClick;
  for I:= 0 to High(FButtons) do
  begin
    FButtons[I].Caption:= EmptyStr;
    FButtons[I].ShowCaption:= False;
  end;

  // Icons of Double Commander
  for I:= 0 to 1 do
  begin
    ABitmap:= PixMapManager.GetThemeIcon(ICONS[I], ASize);
    if Assigned(ABitmap) then
    try
      FButtons[I].Glyph.Assign(ABitmap);
    finally
      ABitmap.Free;
    end;
  end;
  ABitmap:= CreateFindNextIcon(ASize);
  try
    FButtons[2].Glyph.Assign(ABitmap);
  finally
    ABitmap.Free;
  end;
  // Three dots
  ABitmap:= TBitmap.Create;
  try
    ABitmap.SetSize(ASize, ASize);
    ABitmap.Canvas.Brush.Color:= clFuchsia;
    ABitmap.Canvas.FillRect(0, 0, ASize, ASize);
    ABitmap.Canvas.Pen.Style:= psClear;
    ABitmap.Canvas.Brush.Color:= ColorToRGB(clBtnText);
    for I:= -1 to 1 do
      ABitmap.Canvas.Ellipse(ASize div 2 - ASize div 12, ASize div 2 + I * (ASize div 3) - ASize div 12,
                             ASize div 2 + ASize div 12 + 1, ASize div 2 + I * (ASize div 3) + ASize div 12 + 1);
    ABitmap.TransparentColor:= clFuchsia;
    ABitmap.Transparent:= True;
    FButtons[3].Glyph.Assign(ABitmap);
  finally
    ABitmap.Free;
  end;

  FMenu:= TPopupMenu.Create(Self);
  AddItem(rsMobileEditorSaveAs, EM_SAVE_AS);
  AddItem(rsMobileEditorCloseNoSave, EM_CLOSE);
  AddItem(rsMobileMenuSettings, EM_SETTINGS);

  FOldMouseDown:= AEditor.OnMouseDown;
  FOldMouseMove:= AEditor.OnMouseMove;
  AEditor.OnMouseDown:= @EditorMouseDown;
  AEditor.OnMouseMove:= @EditorMouseMove;
  FOldMouseUp:= AEditor.OnMouseUp;
  AEditor.OnMouseUp:= @EditorMouseUp;

  FTimer:= TTimer.Create(Self);
  FTimer.Interval:= 300;
  FTimer.OnTimer:= @TimerTick;
  TimerTick(nil);

  PanelResize(FPanel);
end;

procedure TMobileEditorHeader.EditorMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FDownY:= Y;
  FDownTop:= TSynEditAccess(FEditor).TopView;
  FScrolling:= False;
  if Assigned(FOldMouseDown) then FOldMouseDown(Sender, Button, Shift, X, Y);
end;

procedure TMobileEditorHeader.EditorMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
begin
  if ssLeft in Shift then
  begin
    // A finger moves the text instead of selecting it
    if (not FScrolling) and (Abs(Y - FDownY) > MobilePx(10)) then
      FScrolling:= True;
    if FScrolling then
    begin
      TSynEditAccess(FEditor).TopView:= Max(1, FDownTop - (Y - FDownY) div Max(1, FEditor.LineHeight));
      FEditor.BlockBegin:= FEditor.LogicalCaretXY;
    end;
  end;
  if Assigned(FOldMouseMove) then FOldMouseMove(Sender, Shift, X, Y);
end;

procedure TMobileEditorHeader.Deselect(Data: PtrInt);
begin
  FEditor.BlockBegin:= FEditor.LogicalCaretXY;
end;

procedure TMobileEditorHeader.EditorMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Assigned(FOldMouseUp) then FOldMouseUp(Sender, Button, Shift, X, Y);
  // The editor finishes the selection after this event
  if FScrolling then
  begin
    FScrolling:= False;
    Application.QueueAsyncCall(@Deselect, 0);
  end;
end;

procedure TMobileEditorHeader.SpaceResize(Sender: TObject);
begin
  // Size in the device pixels, the form scaling should not change it
  if FSpace.Height <> MobileTopMargin then FSpace.Height:= MobileTopMargin;
end;

procedure TMobileEditorHeader.PanelResize(Sender: TObject);
var
  I, H, X: Integer;
begin
  H:= MobilePx(56);
  if FPanel.Height <> H then
  begin
    FPanel.Height:= H;
    Exit;
  end;
  X:= FPanel.ClientWidth;
  for I:= High(FButtons) downto 0 do
  begin
    Dec(X, H);
    FButtons[I].SetBounds(X, 0, H, H);
  end;
  FTitle.SetBounds(MobilePx(12), 0, Max(0, X - MobilePx(16)), H);
end;

procedure TMobileEditorHeader.TimerTick(Sender: TObject);
var
  S: String;
begin
  // The editor shows the file name in the window caption
  S:= ExtractFileName(FForm.Caption);
  if Length(S) = 0 then S:= FForm.Caption;
  if FEditor.Modified then S:= '* ' + S;
  if FTitle.Caption <> S then FTitle.Caption:= S;
end;

procedure TMobileEditorHeader.MenuClick(Sender: TObject);
var
  P: TPoint;
begin
  P:= FButtons[3].ClientToScreen(Classes.Point(FButtons[3].Width, FButtons[3].Height));
  MobileHookPopupMenus;
  FMenu.PopUp(P.X, P.Y);
end;

procedure TMobileEditorHeader.ItemClick(Sender: TObject);
begin
  case TMenuItem(Sender).Tag of
    EM_SAVE_AS: FSaveAs.Execute;
    EM_CLOSE:
      begin
        // Do not ask to save the changes
        FEditor.Modified:= False;
        FForm.Close;
      end;
    EM_SETTINGS: frmMain.Commands.cm_Options(['TfrmOptionsEditor']);
  end;
end;

procedure MobileSetupEditor(AForm: TForm; AEditor: TSynEdit;
  ASave, ASaveAs, AFind, AFindNext: TBasicAction; AToolBar, AStatusBar: TControl);
begin
  if not gMobileMode then Exit;
  MobileHideMenuBar(AForm);
  AToolBar.Visible:= False;
  AStatusBar.Visible:= False;
  // Like a phone notepad: no line numbers, wrapped lines
  AEditor.Gutter.Visible:= False;
  AEditor.RightEdge:= -1;
  TLazSynEditLineWrapPlugin.Create(AEditor);
  TMobileEditorHeader.CreateFor(AForm, AEditor, ASave, ASaveAs, AFind, AFindNext);
end;

finalization
  FreeAndNil(MenuBarHider);
  FreeAndNil(MainMenuHandler);

end.
