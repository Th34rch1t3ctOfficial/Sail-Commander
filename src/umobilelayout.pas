{
   Sail Commander
   -------------------------------------------------------------------------
   Main window layout for the mobile mode: the tool bar with the main menu
   button at the top, one file panel at a time and the main file commands
   at the bottom

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
  Controls, Graphics, Buttons, Forms, Menus, ExtCtrls, Math, uGlobs, uMobile, uFilePanelSelect,
  uPixMapManager, fMain
{$IF DEFINED(LCLQT5)}
  , qtwidgets
{$ENDIF}
  ;

const
  // Commands which are shown at the bottom of the main window
  MOBILE_COMMANDS: array[0..3] of String = ('cm_Edit', 'cm_Copy', 'cm_Rename', 'cm_Delete');

  KEYS_HEIGHT = 56;

type

  { TLayoutHelper }

  TLayoutHelper = class
  private
    FMenu: TPopupMenu;
    FTopPanel: TPanel;
    FMenuButton: TSpeedButton;
    procedure CloneMenuItems(ASource, ATarget: TMenuItem);
    procedure MenuButtonClick(Sender: TObject);
  public
    FMenuHidden: Boolean;
    procedure HideMainMenu(Data: PtrInt);
    destructor Destroy; override;
    procedure KeysResize(Sender: TObject);
    procedure ShowMainMenu(const APoint: TPoint);
    procedure UpdateTopPanel;
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
  UpdateFunctionButtons;
  MobileUpdatePanels;
end;

initialization
  LayoutHelper:= TLayoutHelper.Create;

finalization
  FreeAndNil(LayoutHelper);

end.
