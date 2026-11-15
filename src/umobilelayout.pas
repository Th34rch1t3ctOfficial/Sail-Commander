{
   Sail Commander
   -------------------------------------------------------------------------
   Main window layout for the mobile mode: main menu at the top,
   one file panel at a time and the main file commands at the bottom

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
  Classes, SysUtils;

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
  Controls, Graphics, Buttons, Forms, LCLType, LCLIntf, uGlobs, uMobile, uFilePanelSelect,
  uPixMapManager, fMain;

const
  // Commands which are shown at the bottom of the main window
  MOBILE_COMMANDS: array[0..3] of String = ('cm_Edit', 'cm_Copy', 'cm_Rename', 'cm_Delete');

  KEYS_HEIGHT = 56;

type

  { TLayoutHelper }

  TLayoutHelper = class
    procedure KeysResize(Sender: TObject);
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
var
  AHeight: Integer;
begin
  if not Assigned(frmMain) then Exit;

  with frmMain do
  begin
    // The main menu is the only way how to get to the most of commands
    if not Assigned(Menu) then Menu:= mnuMain;

    // A phone application always occupies the whole screen,
    // the main menu is not a part of the form client area
    AHeight:= Screen.Height - GetSystemMetrics(SM_CYMENU);
    if (Width <> Screen.Width) or (Height <> AHeight) then
      SetBounds(0, 0, Screen.Width, AHeight);

    // No place for these on a small screen
    MainToolBar.Visible:= False;
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

  UpdateFunctionButtons;
  MobileUpdatePanels;
end;

initialization
  LayoutHelper:= TLayoutHelper.Create;

finalization
  FreeAndNil(LayoutHelper);

end.
