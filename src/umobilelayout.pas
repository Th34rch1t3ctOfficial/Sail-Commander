{
   Sail Commander
   -------------------------------------------------------------------------
   Main window layout for the mobile mode: the tool bar with the main menu
   button at the top, one file panel at a time with the side bar (switch
   panel, target equals source) and the main file commands at the bottom

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

unit uMobileLayout;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types;

{en
   Applies mobile layout to the main window,
   should be called when the main window view has been updated.
}
procedure MobileApplyLayout;
{en
   Shows the selected file panel and hides the opposite one.
}
procedure MobileUpdatePanels;
implementation

uses
  Controls, Graphics, Buttons, Forms, Menus, ExtCtrls, Math, LCLType, uGlobs, uMobile, uFilePanelSelect,
  uPixMapManager, fMain
{$IF DEFINED(LCLQT5)}
  , qtwidgets
{$ENDIF}
  ;

const
  // Commands which are shown at the bottom of the main window
  MOBILE_COMMANDS: array[0..3] of String = ('cm_Edit', 'cm_Copy', 'cm_Rename', 'cm_Delete');

  KEYS_HEIGHT = 56;

  // Side bar buttons from the top to the bottom
  SIDE_BUTTONS: array[0..4] of (sbSwitch, sbEqual) = (sbSwitch, sbSwitch, sbSwitch, sbEqual, sbEqual);

type

  { TMobileSideBar }

  {en
     Narrow bar next to the file panel: an arrow switches to the opposite
     panel, an equals sign shows the current directory in the opposite panel
  }
  TMobileSideBar = class(TCustomControl)
  private
    FPressed: Integer;
    function GetButtonAt(X, Y: Integer): Integer;
    function GetButtonRect(AIndex: Integer): TRect;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { TLayoutHelper }

  TLayoutHelper = class
  private
    FMenu: TPopupMenu;
    FTopPanel: TPanel;
    FMenuButton: TSpeedButton;
    FSideBar: TMobileSideBar;
    procedure CloneMenuItems(ASource, ATarget: TMenuItem);
    procedure MenuButtonClick(Sender: TObject);
  public
    FMenuHidden: Boolean;
    procedure HideMainMenu(Data: PtrInt);
    destructor Destroy; override;
    procedure KeysResize(Sender: TObject);
    procedure ShowMainMenu(const APoint: TPoint);
    procedure UpdateTopPanel;
    procedure UpdateSideBar;
  end;

var
  LayoutHelper: TLayoutHelper = nil;

procedure TLayoutHelper.KeysResize(Sender: TObject);
begin
  with TControl(Sender) do
  begin
    if Height <> MobilePx(KEYS_HEIGHT) then Height:= MobilePx(KEYS_HEIGHT);
  end;
end;

{ TMobileSideBar }

constructor TMobileSideBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Align:= alRight;
  TabStop:= False;
  DoubleBuffered:= True;
  ControlStyle:= ControlStyle + [csOpaque];
  FPressed:= -1;
end;

function TMobileSideBar.GetButtonRect(AIndex: Integer): TRect;
var
  AHeight: Integer;
begin
  AHeight:= Min(MobilePx(44), ClientHeight div Length(SIDE_BUTTONS));
  Result:= Classes.Rect(0, AIndex * AHeight, ClientWidth, (AIndex + 1) * AHeight);
end;

function TMobileSideBar.GetButtonAt(X, Y: Integer): Integer;
var
  I: Integer;
begin
  for I:= Low(SIDE_BUTTONS) to High(SIDE_BUTTONS) do
  begin
    if PtInRect(GetButtonRect(I), Classes.Point(X, Y)) then Exit(I);
  end;
  Result:= -1;
end;

procedure TMobileSideBar.Paint;
var
  R: TRect;
  I, W, H, CX, CY, D: Integer;
  ABackColor, ATextColor: TColor;
begin
  ABackColor:= gColors.FilePanel^.BackColor;
  ATextColor:= gColors.FilePanel^.ForeColor;

  Canvas.Brush.Style:= bsSolid;
  Canvas.Brush.Color:= ABackColor;
  Canvas.FillRect(ClientRect);

  Canvas.AntialiasingMode:= amOn;
  Canvas.Pen.Style:= psSolid;
  Canvas.Pen.Color:= ATextColor;
  Canvas.Pen.Width:= Max(1, MobilePx(3) div 2);

  // Half of a symbol width and height
  W:= (ClientWidth * 3) div 8;
  H:= Max(2, W div 2);

  for I:= Low(SIDE_BUTTONS) to High(SIDE_BUTTONS) do
  begin
    R:= GetButtonRect(I);
    if FPressed = I then
    begin
      Canvas.Brush.Color:= RGBToColor(
        (Red(ColorToRGB(ABackColor)) * 4 + Red(ColorToRGB(ATextColor))) div 5,
        (Green(ColorToRGB(ABackColor)) * 4 + Green(ColorToRGB(ATextColor))) div 5,
        (Blue(ColorToRGB(ABackColor)) * 4 + Blue(ColorToRGB(ATextColor))) div 5);
      Canvas.FillRect(R);
    end;
    CX:= (R.Left + R.Right) div 2;
    CY:= (R.Top + R.Bottom) div 2;
    case SIDE_BUTTONS[I] of
      sbSwitch:
        begin
          // The arrow points to the opposite panel
          if frmMain.SelectedPanel = fpLeft then D:= 1 else D:= -1;
          Canvas.Line(CX - W, CY, CX + W, CY);
          Canvas.Line(CX + D * W, CY, CX + D * (W - H), CY - H);
          Canvas.Line(CX + D * W, CY, CX + D * (W - H), CY + H);
        end;
      sbEqual:
        begin
          D:= Max(2, H div 2);
          Canvas.Line(CX - W, CY - D, CX + W, CY - D);
          Canvas.Line(CX - W, CY + D, CX + W, CY + D);
        end;
    end;
  end;
end;

procedure TMobileSideBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then
  begin
    FPressed:= GetButtonAt(X, Y);
    Invalidate;
  end;
end;

procedure TMobileSideBar.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  APressed: Integer;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button = mbLeft then
  begin
    APressed:= FPressed;
    FPressed:= -1;
    Invalidate;
    if (APressed >= 0) and (APressed = GetButtonAt(X, Y)) then
    begin
      case SIDE_BUTTONS[APressed] of
        sbSwitch: frmMain.Commands.cm_FocusSwap([]);
        sbEqual:  frmMain.Commands.cm_TargetEqualSource([]);
      end;
    end;
  end;
end;

procedure TLayoutHelper.UpdateSideBar;
begin
  if not Assigned(FSideBar) then
  begin
    FSideBar:= TMobileSideBar.Create(frmMain);
    FSideBar.Parent:= frmMain.pnlMain;
  end;
  FSideBar.Width:= MulDiv(MobilePx(32), frmMain.PixelsPerInch, Screen.PixelsPerInch);
  FSideBar.Invalidate;
end;

destructor TLayoutHelper.Destroy;
begin
  FreeAndNil(FMenu);
  inherited Destroy;
end;

procedure TLayoutHelper.CloneMenuItems(ASource, ATarget: TMenuItem);
var
  I: Integer;
  AItem, ANewItem: TMenuItem;
begin
  for I:= 0 to ASource.Count - 1 do
  begin
    AItem:= ASource.Items[I];
    if not AItem.Visible then Continue;

    ANewItem:= TMenuItem.Create(FMenu);
    if Assigned(AItem.Action) then
      ANewItem.Action:= AItem.Action
    else begin
      ANewItem.Caption:= AItem.Caption;
      ANewItem.Enabled:= AItem.Enabled;
      ANewItem.RadioItem:= AItem.RadioItem;
      ANewItem.Checked:= AItem.Checked;
      ANewItem.Hint:= AItem.Hint;
      ANewItem.Tag:= AItem.Tag;
      // A submenu is opened by the menu itself
      if AItem.Count = 0 then ANewItem.OnClick:= AItem.OnClick;
    end;
    ATarget.Add(ANewItem);

    if AItem.Count > 0 then CloneMenuItems(AItem, ANewItem);
  end;
end;

procedure TLayoutHelper.ShowMainMenu(const APoint: TPoint);
begin
  // The main menu changes at runtime, so mirror it each time
  FreeAndNil(FMenu);
  FMenu:= TPopupMenu.Create(nil);
  CloneMenuItems(frmMain.mnuMain.Items, FMenu.Items);
  FMenu.PopUp(APoint.X, APoint.Y);
end;

procedure TLayoutHelper.HideMainMenu(Data: PtrInt);
begin
  if not Assigned(frmMain) then Exit;
  if not frmMain.HandleAllocated then
  begin
    // Try again when the window is created
    Application.QueueAsyncCall(@HideMainMenu, 0);
    Exit;
  end;
  FMenuHidden:= True;
{$IF DEFINED(LCLQT5)}
  // The widgetset keeps the menu bar of the window visible
  if TQtWidget(frmMain.Handle) is TQtMainWindow then
  begin
    with TQtMainWindow(frmMain.Handle) do
    begin
      if Assigned(MenuBar) then MenuBar.setVisible(False);
    end;
  end;
{$ENDIF}
end;

procedure TLayoutHelper.MenuButtonClick(Sender: TObject);
begin
  // Show the menu below the button, aligned to the right edge of the screen
  with FMenuButton do
    ShowMainMenu(ClientToScreen(Classes.Point(0, Height)));
end;

procedure TLayoutHelper.UpdateTopPanel;
var
  X, Y, I, D, ASize: Integer;
  ABitmap: TBitmap;
begin
  with frmMain do
  begin
    if not Assigned(FTopPanel) then
    begin
      // The tool bar and the main menu button (three dots) after it
      FTopPanel:= TPanel.Create(frmMain);
      FTopPanel.Parent:= frmMain;
      FTopPanel.Align:= alTop;
      FTopPanel.BevelOuter:= bvNone;
      FTopPanel.Caption:= EmptyStr;
      FTopPanel.AutoSize:= True;

      FMenuButton:= TSpeedButton.Create(FTopPanel);
      FMenuButton.Parent:= FTopPanel;
      FMenuButton.Flat:= True;
      FMenuButton.OnClick:= @MenuButtonClick;
      FMenuButton.Anchors:= [akTop, akRight];
      FMenuButton.AnchorSideTop.Control:= FTopPanel;
      FMenuButton.AnchorSideRight.Control:= FTopPanel;
      FMenuButton.AnchorSideRight.Side:= asrRight;

      MainToolBar.Parent:= FTopPanel;
      MainToolBar.Align:= alNone;
      MainToolBar.Anchors:= [akTop, akLeft, akRight];
      MainToolBar.AnchorSideTop.Control:= FTopPanel;
      MainToolBar.AnchorSideLeft.Control:= FTopPanel;
      MainToolBar.AnchorSideRight.Control:= FMenuButton;
      MainToolBar.AnchorSideRight.Side:= asrLeft;
    end;

    // Three dots
    ASize:= gToolBarIconSize;
    ABitmap:= TBitmap.Create;
    try
      ABitmap.SetSize(ASize, ASize);
      ABitmap.Canvas.Brush.Color:= clFuchsia;
      ABitmap.Canvas.FillRect(0, 0, ASize, ASize);
      ABitmap.Canvas.Pen.Style:= psClear;
      ABitmap.Canvas.Brush.Color:= ColorToRGB(clBtnText);
      D:= Max(1, ASize div 12);
      X:= ASize div 2;
      for I:= -1 to 1 do
      begin
        Y:= ASize div 2 + I * (ASize div 3);
        ABitmap.Canvas.Ellipse(X - D, Y - D, X + D + 1, Y + D + 1);
      end;
      ABitmap.TransparentColor:= clFuchsia;
      ABitmap.Transparent:= True;
      FMenuButton.Glyph.Assign(ABitmap);
    finally
      ABitmap.Free;
    end;
    FMenuButton.Width:= gToolBarButtonSize;
    FMenuButton.Height:= gToolBarButtonSize;

    MainToolBar.Visible:= True;
    FTopPanel.Top:= -1;
  end;
end;

function IsMobileCommand(const ACommand: String): Boolean;
var
  I: Integer;
begin
  for I:= Low(MOBILE_COMMANDS) to High(MOBILE_COMMANDS) do
  begin
    if MOBILE_COMMANDS[I] = ACommand then Exit(True);
  end;
  Result:= False;
end;

procedure MobileUpdatePanels;
begin
  if not Assigned(frmMain) then Exit;

  with frmMain do
  begin
    DisableAutoSizing;
    try
      if SelectedPanel = fpLeft then
      begin
        pnlRight.Visible:= False;
        pnlLeft.BorderSpacing.Right:= 0;
        pnlLeft.BorderSpacing.Bottom:= 0;
        pnlLeft.Align:= alClient;
        pnlLeft.Visible:= True;
      end
      else begin
        pnlLeft.Visible:= False;
        pnlRight.Visible:= True;
      end;
    finally
      EnableAutoSizing;
    end;
  end;

  // The arrows point to the opposite panel
  if Assigned(LayoutHelper.FSideBar) then LayoutHelper.FSideBar.Invalidate;
end;

procedure UpdateFunctionButtons;
var
  I: Integer;
  ACommand: String;
  ABitmap: TBitmap;
  AButton: TSpeedButton;
begin
  with frmMain do
  begin
    for I:= 0 to pnlKeys.ControlCount - 1 do
    begin
      if not (pnlKeys.Controls[I] is TSpeedButton) then Continue;

      AButton:= TSpeedButton(pnlKeys.Controls[I]);
      ACommand:= GetFunctionButtonCommand(I);
      AButton.Visible:= IsMobileCommand(ACommand);

      if AButton.Visible then
      begin
        // There is no keyboard, so do not show a shortcut
        AButton.Caption:= GetFunctionButtonCaption(I);
        AButton.Flat:= True;
        AButton.Layout:= blGlyphTop;
        AButton.Spacing:= MobilePx(2);
        AButton.Margin:= MobilePx(4);
        ABitmap:= PixMapManager.GetThemeIcon(LowerCase(ACommand), MobilePx(24));
        if Assigned(ABitmap) then
        try
          AButton.Glyph.Assign(ABitmap);
        finally
          ABitmap.Free;
        end;
      end;
    end;
    // The form is scaled when it is shown for the first time,
    // so keep the height which is already in the device pixels
    pnlKeys.OnResize:= @LayoutHelper.KeysResize;
    pnlKeys.Height:= MobilePx(KEYS_HEIGHT);
    pnlKeys.Top:= Height * 2;
    pnlKeys.Visible:= True;
  end;
end;

procedure MobileApplyLayout;
begin
  if not Assigned(frmMain) then Exit;

  with frmMain do
  begin
    // The main menu is shown as a popup menu by the three dots button
    if Assigned(frmMain.Menu) then frmMain.Menu:= nil;
    // The menu bar can be hidden only when the window exists
    Application.QueueAsyncCall(@LayoutHelper.HideMainMenu, 0);

    // A phone application always occupies the whole screen
    if (Width <> Screen.Width) or (Height <> Screen.Height) then
      SetBounds(0, 0, Screen.Width, Screen.Height);

    // No place for these on a small screen
    MiddleToolbar.Visible:= False;
    MainSplitter.Visible:= False;
    pnlDisk.Visible:= False;
    pnlLeftTools.Visible:= False;
    pnlRightTools.Visible:= False;
    pnlCommand.Visible:= False;
    ConsoleSplitter.Visible:= False;
    seLogWindow.Visible:= False;
    LogSplitter.Visible:= False;

    // A single tab does not need a header
    LeftTabs.ShowTabs:= (LeftTabs.PageCount > 1);
    RightTabs.ShowTabs:= (RightTabs.PageCount > 1);
  end;

  LayoutHelper.UpdateTopPanel;
  LayoutHelper.UpdateSideBar;
  UpdateFunctionButtons;
  MobileUpdatePanels;
end;

initialization
  LayoutHelper:= TLayoutHelper.Create;

finalization
  FreeAndNil(LayoutHelper);

end.
