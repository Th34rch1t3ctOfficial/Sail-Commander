{
   Sail Commander
   -------------------------------------------------------------------------
   Touch file view - single column list with two-line items which
   is controlled by a finger (tap, long press, flick), used in mobile mode

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

unit uTouchFileView;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, ExtCtrls, LMessages, LCLType, Types, Menus,
  uDisplayFile, DCXmlConfig, uTypes, uFileView, uFileViewWithMainCtrl,
  uFile, uFileSource, uFileProperty;

type

  TTouchFileView = class;

  THeaderZone = (hzNone, hzPath, hzCount, hzParent, hzHome, hzRefresh);

  TPlaceKind = (pkFolder, pkBookmarks);

  TMarkMode = (mmSelect, mmUnselect, mmInvert);

  {en
     Item of the places list which is shown above the root directory
  }
  TPlace = record
    Name: String;
    Path: String;
    Space: String;
    Kind: TPlaceKind;
    Icon: TBitmap;
  end;

  { TTouchHeader }

  {en
     Current path, selection counter and navigation buttons
  }
  TTouchHeader = class(TCustomControl)
  private
    FFileView: TTouchFileView;
    FPressed: THeaderZone;
    function GetZone(X, Y: Integer): THeaderZone;
    function GetButtonRect(AZone: THeaderZone): TRect;
    function GetPathHeight: Integer;
  protected
    procedure DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
                const AXProportion, AYProportion: Double); override;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent; AFileView: TTouchFileView); reintroduce;
    procedure UpdateView;
  end;

  { TTouchList }

  {en
     File list with pixel precise kinetic scrolling
  }
  TTouchList = class(TCustomControl)
  private
    FFileView: TTouchFileView;
    FOffset: Integer;
    // Finger tracking
    FPressed: Boolean;
    FPressedRow: Integer;
    FScrolling: Boolean;
    FLongPress: Boolean;
    FDownPoint: TPoint;
    FDownOffset: Integer;
    FLastY: Integer;
    FLastTime: QWord;
    FVelocity: Double; // pixels per millisecond
    FKineticTime: QWord;
    FKineticOffset: Double;
    tmKinetic: TTimer;
    tmLongPress: TTimer;
    function GetMaxOffset: Integer;
    function GetRowCount: Integer;
    function GetRowRect(ARow: Integer): TRect;
    function GetRowAt(Y: Integer): Integer;
    procedure SetOffset(AValue: Integer);
    procedure StopKinetic;
    procedure tmKineticTimer(Sender: TObject);
    procedure tmLongPressTimer(Sender: TObject);
    procedure DrawRow(ARow: Integer; const ARect: TRect);
    procedure DrawPlace(ARow: Integer; const ARect: TRect);
    procedure WMGetDlgCode(var Msg: TLMNoParams); message LM_GETDLGCODE;
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent; AFileView: TTouchFileView); reintroduce;
    procedure MakeVisible(ARow: Integer);
    procedure UpdateScroll;
    procedure DetachMouseHandlers;
    property Offset: Integer read FOffset write SetOffset;
    property RowCount: Integer read GetRowCount;
  end;

  { TTouchFileView }

  TTouchFileView = class(TFileViewWithMainCtrl)
  private
    FHeader: TTouchHeader;
    FList: TTouchList;
    FActiveIndex: PtrInt;
    {en
       Index of the first file shown in the list. Parent directory item ('..')
       is not shown in the list, the header has a button for it instead.
    }
    FFirstIndex: Integer;
    FTotalCount: Integer;
    // Free space
    FFreeSize, FTotalSize: Int64;
    FFreeSpaceKnown: Boolean;
    // Metrics in pixels
    FMargin: Integer;
    FRowHeight: Integer;
    FIconColumn: Integer;
    FNameHeight: Integer;
    FDetailHeight: Integer;
    // Double Commander icons of the header buttons
    FIcons: array[THeaderZone] of TBitmap;
    // Places
    FPlaces: array of TPlace;
    FPlacesMode: Boolean;
    FOpenMenu: TPopupMenu;
    FOpenIndex: PtrInt;
    procedure ClearPlaces;
    procedure LoadPlaces;
    procedure ShowPlaces;
    procedure HidePlaces;
    procedure OpenPlace(AIndex: Integer);
    procedure ClearIcons;
    procedure LoadIcons;
    procedure DrawIcon(ACanvas: TCanvas; const ARect: TRect; AIcon: TBitmap);
    procedure SetNameFont(AFont: TFont);
    procedure SetDetailFont(AFont: TFont);
    function GetDetails(AFile: TDisplayFile): String;
    function GetSeparatorColor: TColor;
    function IndexToRow(AIndex: PtrInt): Integer; inline;
    function RowToIndex(ARow: Integer): PtrInt; inline;
    procedure SetFilesDisplayItems;
    procedure MoveActiveFile(ADelta: Integer);
    procedure UpdateMetrics;
    procedure UpdateFreeSpace;
    // Finger actions
    procedure TapFile(AIndex: PtrInt; AtIcon: Boolean);
    procedure ShowOpenMenu(AIndex: PtrInt);
    procedure OpenMenuClick(Sender: TObject);
    function IsTextFile(AFile: TDisplayFile): Boolean;
    procedure LongPressFile(AIndex: PtrInt; const APoint: TPoint);
    procedure HeaderClick(AZone: THeaderZone);
  protected
    procedure CreateDefault(AOwner: TWinControl); override;
    procedure AfterChangePath; override;
    procedure DisplayFileListChanged; override;
    procedure DoFileUpdated(AFile: TDisplayFile; UpdatedProperties: TFilePropertiesTypes = []); override;
    procedure DoHandleKeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoUpdateView; override;
    procedure FileSourceFileListLoaded; override;
    function GetActiveFileIndex: PtrInt; override;
    function GetFileIndexFromCursor(X, Y: Integer; out AtFileList: Boolean): PtrInt; override;
    function GetFileRect(FileIndex: PtrInt): TRect; override;
    function GetIconRect(FileIndex: PtrInt): TRect; override;
    function GetVisibleFilesIndexes: TRange; override;
    procedure MouseScrollTimer(Sender: TObject); override;
    procedure RedrawFile(FileIndex: PtrInt); override;
    procedure RedrawFile(DisplayFile: TDisplayFile); override;
    procedure RedrawFiles; override;
    procedure SetActiveFile(FileIndex: PtrInt; ScrollTo: Boolean; aLastTopRowIndex: PtrInt = -1); override;
    procedure ShowRenameFileEdit(var aFile: TFile; const withExt: Boolean); override;
    procedure UpdateRenameFileEditPosition(const withExt: Boolean); override;
    procedure UpdateInfoPanel; override;
  public
    destructor Destroy; override;
    function Clone(NewParent: TWinControl): TTouchFileView; override;
    procedure ChangePathToParent(AllowChangingFileSource: Boolean); override;
    {en
       Marks files and/or directories which match the mask.
    }
    procedure MarkByMask(const AMask: String; AFiles, AFolders: Boolean; AMode: TMarkMode);
    procedure SaveConfiguration(AConfig: TXmlConfig; ANode: TXmlNode; ASaveHistory: Boolean); override;
    procedure UpdateColor; override;
  end;

implementation

uses
  LCLIntf, LCLProc, Forms, Math, StdCtrls,
  DCOSUtils, DCStrUtils, uGlobs, uLng, uPixmapManager, uDCUtils, uFileFunctions,
  uFileSourceProperty, uFileViewWithGrid, uOrderedFileView, uMobile, uDrive,
  uOSUtils, uSysFolders, uKeyboard, uHotDir, uMasks, uMobileUI, uOSForms, fMain
{$IF DEFINED(UNIX)}
  , uMimeType
{$ENDIF}
  ;

const
  // Names of the Double Commander theme icons
  HEADER_ICONS: array[THeaderZone] of String =
    ('', '', '', 'go-up', 'cm_visithomepage', 'cm_refresh');

  KINETIC_INTERVAL = 15;    // milliseconds
  KINETIC_FRICTION = 0.0025; // velocity loss per millisecond
  KINETIC_MINIMUM  = 0.03;  // pixels per millisecond
  KINETIC_MAXIMUM  = 6.0;   // pixels per millisecond
  LONG_PRESS_TIME  = 550;   // milliseconds

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

{ TTouchHeader }

constructor TTouchHeader.Create(AOwner: TComponent; AFileView: TTouchFileView);
begin
  FFileView:= AFileView;
  inherited Create(AOwner);
  Parent:= AFileView;
  Align:= alTop;
  TabStop:= False;
  DoubleBuffered:= True;
  ControlStyle:= ControlStyle + [csOpaque];
end;

procedure TTouchHeader.DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
  const AXProportion, AYProportion: Double);
begin
  // Height is calculated from the font size, so it is already scaled
end;

function TTouchHeader.GetPathHeight: Integer;
begin
  Result:= FFileView.FNameHeight + FFileView.FMargin;
end;

function TTouchHeader.GetButtonRect(AZone: THeaderZone): TRect;
var
  V: TTouchFileView;
  AWidth: Integer;
begin
  V:= FFileView;
  AWidth:= gIconsSize + V.FMargin * 2;
  Result.Top:= GetPathHeight;
  Result.Bottom:= Result.Top + V.FRowHeight;
  case AZone of
    hzRefresh:
      Result.Right:= ClientWidth - V.FMargin;
    hzHome:
      Result.Right:= ClientWidth - V.FMargin - AWidth;
    else
      begin
        // Parent directory button occupies all the remaining space
        Result.Left:= 0;
        Result.Right:= ClientWidth - V.FMargin - AWidth * 2;
        Exit;
      end;
  end;
  Result.Left:= Result.Right - AWidth;
end;

function TTouchHeader.GetZone(X, Y: Integer): THeaderZone;
var
  AZone: THeaderZone;
begin
  if Y < GetPathHeight then
  begin
    // The right quarter is the selection counter
    if X > (ClientWidth * 3) div 4 then
      Result:= hzCount
    else
      Result:= hzPath;
  end
  else begin
    Result:= hzNone;
    for AZone:= hzParent to hzRefresh do
    begin
      if PtInRect(GetButtonRect(AZone), Classes.Point(X, Y)) then
        Exit(AZone);
    end;
  end;
end;

procedure TTouchHeader.Paint;
var
  S: String;
  ARect: TRect;
  AWidth: Integer;
  V: TTouchFileView;
  AZone: THeaderZone;
  ATextColor, ABackColor: TColor;
begin
  V:= FFileView;
  ABackColor:= V.DimColor(gColors.FilePanel^.BackColor);
  ATextColor:= gColors.FilePanel^.ForeColor;

  Canvas.Brush.Style:= bsSolid;
  Canvas.Brush.Color:= ABackColor;
  Canvas.FillRect(ClientRect);

  // Feedback for a finger
  Canvas.Brush.Color:= BlendColor(ABackColor, ATextColor, 18);
  case FPressed of
    hzPath, hzCount:
      Canvas.FillRect(Classes.Rect(0, 0, ClientWidth, GetPathHeight));
    hzParent, hzHome, hzRefresh:
      Canvas.FillRect(GetButtonRect(FPressed));
  end;

  Canvas.Brush.Style:= bsClear;
  V.SetNameFont(Canvas.Font);
  Canvas.Font.Color:= ATextColor;

  // Selection counter
  S:= IntToStr(V.FSelectedCount) + '/' + IntToStr(V.FTotalCount);
  AWidth:= Canvas.TextWidth(S);
  Canvas.TextOut(ClientWidth - V.FMargin - AWidth, V.FMargin div 2, S);

  // Current path
  if V.FileSourcesCount > 0 then
  begin
    S:= MinimizeFilePath(V.CurrentPath, Canvas, ClientWidth - AWidth - V.FMargin * 4);
    Canvas.TextOut(V.FMargin, V.FMargin div 2, S);
  end;

  // Parent directory
  ARect:= GetButtonRect(hzParent);
  ARect.Right:= V.FIconColumn;
  V.DrawIcon(Canvas, ARect, V.FIcons[hzParent]);
  Canvas.Brush.Style:= bsClear;
  Canvas.TextOut(V.FIconColumn, ARect.Top + V.FMargin div 4, '..');

  // Free space
  if V.FFreeSpaceKnown then
  begin
    V.SetDetailFont(Canvas.Font);
    Canvas.Font.Color:= ATextColor;
    S:= cnvFormatFileSize(V.FFreeSize, uoscHeader) + ' / ' +
        cnvFormatFileSize(V.FTotalSize, uoscHeader);
    ARect:= GetButtonRect(hzParent);
    Canvas.TextOut(ARect.Right - V.FMargin - Canvas.TextWidth(S),
                   ARect.Bottom - V.FDetailHeight - V.FMargin div 2, S);
  end;

  // Buttons
  for AZone:= hzHome to hzRefresh do
    V.DrawIcon(Canvas, GetButtonRect(AZone), V.FIcons[AZone]);

  // Separator
  Canvas.Pen.Style:= psSolid;
  Canvas.Pen.Width:= Max(1, MobilePx(1));
  Canvas.Pen.Color:= V.GetSeparatorColor;
  Canvas.Line(V.FMargin, ClientHeight - 1, ClientWidth - V.FMargin, ClientHeight - 1);
end;

procedure TTouchHeader.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then
  begin
    FPressed:= GetZone(X, Y);
    Invalidate;
  end;
end;

procedure TTouchHeader.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  AZone: THeaderZone;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button = mbLeft then
  begin
    AZone:= FPressed;
    FPressed:= hzNone;
    Invalidate;
    if (AZone <> hzNone) and (AZone = GetZone(X, Y)) then
      FFileView.HeaderClick(AZone);
  end;
end;

procedure TTouchHeader.UpdateView;
begin
  Height:= GetPathHeight + FFileView.FRowHeight + 1;
  Invalidate;
end;

{ TTouchList }

constructor TTouchList.Create(AOwner: TComponent; AFileView: TTouchFileView);
begin
  FFileView:= AFileView;
  inherited Create(AOwner);
  Parent:= AFileView;
  Align:= alClient;
  TabStop:= False;
  DoubleBuffered:= True;
  ControlStyle:= ControlStyle + [csOpaque];
  FPressedRow:= -1;

  tmKinetic:= TTimer.Create(Self);
  tmKinetic.Enabled:= False;
  tmKinetic.Interval:= KINETIC_INTERVAL;
  tmKinetic.OnTimer:= @tmKineticTimer;

  tmLongPress:= TTimer.Create(Self);
  tmLongPress.Enabled:= False;
  tmLongPress.Interval:= LONG_PRESS_TIME;
  tmLongPress.OnTimer:= @tmLongPressTimer;
end;

procedure TTouchList.WMGetDlgCode(var Msg: TLMNoParams);
begin
  Msg.Result:= DLGC_WANTARROWS or DLGC_WANTCHARS or DLGC_WANTTAB;
end;

function TTouchList.GetRowCount: Integer;
begin
  if FFileView.FPlacesMode then
    Result:= Length(FFileView.FPlaces)
  else if Assigned(FFileView.FFiles) then
    Result:= Max(0, FFileView.FFiles.Count - FFileView.FFirstIndex)
  else
    Result:= 0;
end;

function TTouchList.GetMaxOffset: Integer;
begin
  Result:= Max(0, GetRowCount * FFileView.FRowHeight - ClientHeight);
end;

function TTouchList.GetRowRect(ARow: Integer): TRect;
begin
  Result.Left:= 0;
  Result.Right:= ClientWidth;
  Result.Top:= ARow * FFileView.FRowHeight - FOffset;
  Result.Bottom:= Result.Top + FFileView.FRowHeight;
end;

function TTouchList.GetRowAt(Y: Integer): Integer;
begin
  if (Y < 0) or (FFileView.FRowHeight <= 0) then Exit(-1);
  Result:= (Y + FOffset) div FFileView.FRowHeight;
  if Result >= GetRowCount then Result:= -1;
end;

procedure TTouchList.SetOffset(AValue: Integer);
var
  V: TTouchFileView;
begin
  V:= FFileView;
  AValue:= EnsureRange(AValue, 0, GetMaxOffset);
  if FOffset <> AValue then
  begin
    FOffset:= AValue;
    Invalidate;
    if not V.FUpdatingActiveFile then
      V.FLastTopRowIndex:= FOffset div Max(1, V.FRowHeight);
    if V.edtRename.Visible then
      V.UpdateRenameFileEditPosition(V.FRenFile.WithExt);
    V.Notify([fvnVisibleFilePropertiesChanged]);
  end;
end;

procedure TTouchList.DetachMouseHandlers;
begin
  OnMouseDown:= nil;
  OnMouseMove:= nil;
  OnMouseUp:= nil;
  OnDblClick:= nil;
  OnQuadClick:= nil;
end;

procedure TTouchList.UpdateScroll;
begin
  if FOffset > GetMaxOffset then
    SetOffset(GetMaxOffset)
  else
    Invalidate;
end;

procedure TTouchList.MakeVisible(ARow: Integer);
var
  ARect: TRect;
begin
  if (ARow < 0) or (ARow >= GetRowCount) then Exit;
  ARect:= GetRowRect(ARow);
  if ARect.Top < 0 then
    SetOffset(FOffset + ARect.Top)
  else if ARect.Bottom > ClientHeight then
    SetOffset(FOffset + ARect.Bottom - ClientHeight);
end;

procedure TTouchList.StopKinetic;
begin
  tmKinetic.Enabled:= False;
  FVelocity:= 0;
end;

procedure TTouchList.tmKineticTimer(Sender: TObject);
var
  ATime: QWord;
  AElapsed: Integer;
begin
  ATime:= GetTickCount64;
  AElapsed:= EnsureRange(Integer(ATime - FKineticTime), 1, 100);
  FKineticTime:= ATime;

  FKineticOffset:= FKineticOffset + FVelocity * AElapsed;
  FVelocity:= FVelocity * Max(0.0, 1.0 - KINETIC_FRICTION * AElapsed);
  SetOffset(Round(FKineticOffset));

  // Stop at the edge or when slow enough
  if (Abs(FVelocity) < KINETIC_MINIMUM) or (FOffset <> Round(FKineticOffset)) then
    StopKinetic;
end;

procedure TTouchList.tmLongPressTimer(Sender: TObject);
var
  ARow: Integer;
begin
  tmLongPress.Enabled:= False;
  if FPressed and not FScrolling then
  begin
    ARow:= FPressedRow;
    FLongPress:= True;
    FPressed:= False;
    FPressedRow:= -1;
    Invalidate;
    if GetCaptureControl = Self then SetCaptureControl(nil);
    if FFileView.FPlacesMode then
      Exit;
    if ARow < 0 then
      FFileView.LongPressFile(InvalidFileIndex, FDownPoint)
    else
      FFileView.LongPressFile(FFileView.RowToIndex(ARow), FDownPoint);
  end;
end;

procedure TTouchList.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  StopKinetic;

  if CanSetFocus and not Focused then SetFocus;

  if FFileView.IsLoadingFileList then Exit;

  case Button of
    mbLeft:
      begin
        FPressed:= True;
        FScrolling:= False;
        FLongPress:= False;
        FDownPoint:= Classes.Point(X, Y);
        FDownOffset:= FOffset;
        FPressedRow:= GetRowAt(Y);
        FLastY:= Y;
        FLastTime:= GetTickCount64;
        FVelocity:= 0;
        tmLongPress.Enabled:= False;
        tmLongPress.Enabled:= True;
        Invalidate;
      end;
    mbRight:
      begin
        // A mouse is connected, behave like a desktop application
        FDownPoint:= Classes.Point(X, Y);
        if FFileView.FPlacesMode then
          Exit;
        if GetRowAt(Y) < 0 then
          FFileView.LongPressFile(InvalidFileIndex, FDownPoint)
        else
          FFileView.LongPressFile(FFileView.RowToIndex(GetRowAt(Y)), FDownPoint);
      end;
  end;
end;

procedure TTouchList.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  ATime: QWord;
  AElapsed: Integer;
begin
  if not FPressed then Exit;

  if not FScrolling then
  begin
    if (Abs(Y - FDownPoint.Y) > MobilePx(8)) or (Abs(X - FDownPoint.X) > MobilePx(16)) then
    begin
      // The finger moved too far, it is not a tap anymore
      tmLongPress.Enabled:= False;
      FScrolling:= True;
      FPressedRow:= -1;
      Invalidate;
    end;
  end;

  if FScrolling then
  begin
    ATime:= GetTickCount64;
    AElapsed:= Integer(ATime - FLastTime);
    if AElapsed > 0 then
    begin
      // Low-pass filter makes flick velocity stable
      FVelocity:= 0.6 * ((FLastY - Y) / AElapsed) + 0.4 * FVelocity;
      FLastTime:= ATime;
      FLastY:= Y;
    end;
    SetOffset(FDownOffset - (Y - FDownPoint.Y));
  end;
end;

procedure TTouchList.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  ARow: Integer;
begin
  if Button <> mbLeft then Exit;

  tmLongPress.Enabled:= False;

  if not FPressed then Exit;

  FPressed:= False;
  ARow:= FPressedRow;
  FPressedRow:= -1;
  Invalidate;

  if FScrolling then
  begin
    FScrolling:= False;
    // The finger rested before it was lifted
    if GetTickCount64 - FLastTime > 120 then FVelocity:= 0;
    FVelocity:= EnsureRange(FVelocity, -KINETIC_MAXIMUM, KINETIC_MAXIMUM);
    if Abs(FVelocity) > KINETIC_MINIMUM * 4 then
    begin
      FKineticOffset:= FOffset;
      FKineticTime:= GetTickCount64;
      tmKinetic.Enabled:= True;
    end;
  end
  else if (ARow >= 0) and (ARow = GetRowAt(Y)) then
  begin
    if FFileView.FPlacesMode then
      FFileView.OpenPlace(ARow)
    else
      FFileView.TapFile(FFileView.RowToIndex(ARow), X < FFileView.FIconColumn);
  end;
end;

function TTouchList.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  StopKinetic;
  SetOffset(FOffset - (WheelDelta * FFileView.FRowHeight) div 120);
  Result:= True;
end;

procedure TTouchList.Resize;
begin
  inherited Resize;
  if FOffset > GetMaxOffset then SetOffset(GetMaxOffset);
  FFileView.Notify([fvnVisibleFilePropertiesChanged]);
end;

procedure TTouchList.DrawRow(ARow: Integer; const ARect: TRect);
var
  S: String;
  AIndex: PtrInt;
  AWidth, X, Y: Integer;
  V: TTouchFileView;
  AFile: TDisplayFile;
  ATextColor, ABackColor: TColor;
begin
  V:= FFileView;
  AIndex:= V.RowToIndex(ARow);
  AFile:= V.FFiles[AIndex];

  // Colors
  with gColors.FilePanel^ do
  begin
    ABackColor:= V.DimColor(BackColor);
    ATextColor:= AFile.TextColor;
    if (ATextColor = clDefault) or (ATextColor = clNone) then
      ATextColor:= ForeColor;
    if AFile.Selected then
    begin
      ATextColor:= MarkColor;
      ABackColor:= BlendColor(ABackColor, MarkColor, 22);
    end;
    if (AIndex = V.FActiveIndex) and V.Active and Focused then
      ABackColor:= BlendColor(ABackColor, ForeColor, 10);
    if (ARow = FPressedRow) then
      ABackColor:= BlendColor(ABackColor, ForeColor, 18);
  end;

  Canvas.Brush.Style:= bsSolid;
  Canvas.Brush.Color:= ABackColor;
  Canvas.FillRect(ARect);

  // Icon
  if gShowIcons <> sim_none then
  begin
    X:= ARect.Left + (V.FIconColumn - gIconsSize) div 2;
    Y:= ARect.Top + (V.FRowHeight - gIconsSize) div 2;
    if gShowHiddenDimmed and V.FileSource.IsHiddenFile(AFile.FSFile) then
      PixMapManager.DrawBitmapAlpha(AFile, Canvas, X, Y)
    else begin
      PixMapManager.DrawBitmap(AFile, Canvas, X, Y);
    end;
    PixMapManager.DrawBitmapOverlay(AFile, fspDirectAccess in V.FileSource.Properties,
                                    Canvas, X, Y);
  end;

  AWidth:= ARect.Right - V.FIconColumn - V.FMargin * 2;
  Canvas.Brush.Style:= bsClear;

  // File name
  V.SetNameFont(Canvas.Font);
  Canvas.Font.Color:= ATextColor;
  S:= FitFileName(AFile.DisplayName, Canvas, AFile.FSFile, AWidth);
  Canvas.TextOut(V.FIconColumn, ARect.Top + V.FMargin div 4, S);

  // File size and modification time
  S:= V.GetDetails(AFile);
  if Length(S) > 0 then
  begin
    V.SetDetailFont(Canvas.Font);
    Canvas.Font.Color:= ATextColor;
    Canvas.TextOut(ARect.Right - V.FMargin * 2 - Canvas.TextWidth(S),
                   ARect.Bottom - V.FDetailHeight - V.FMargin div 2, S);
  end;

  // Separator
  Canvas.Pen.Style:= psSolid;
  Canvas.Pen.Width:= Max(1, MobilePx(1));
  Canvas.Pen.Color:= V.GetSeparatorColor;
  Canvas.Line(V.FMargin, ARect.Bottom - 1, ARect.Right - V.FMargin, ARect.Bottom - 1);
end;

procedure TTouchList.DrawPlace(ARow: Integer; const ARect: TRect);
var
  S: String;
  AWidth: Integer;
  V: TTouchFileView;
  ATextColor, ABackColor: TColor;
begin
  V:= FFileView;
  ABackColor:= V.DimColor(gColors.FilePanel^.BackColor);
  ATextColor:= gColors.FilePanel^.ForeColor;
  if (ARow = FPressedRow) then
    ABackColor:= BlendColor(ABackColor, ATextColor, 18);

  Canvas.Brush.Style:= bsSolid;
  Canvas.Brush.Color:= ABackColor;
  Canvas.FillRect(ARect);

  with V.FPlaces[ARow] do
  begin
    V.DrawIcon(Canvas, Classes.Rect(ARect.Left, ARect.Top, V.FIconColumn, ARect.Bottom), Icon);

    Canvas.Brush.Style:= bsClear;

    V.SetNameFont(Canvas.Font);
    Canvas.Font.Color:= ATextColor;
    Canvas.TextOut(V.FIconColumn, ARect.Top + V.FMargin div 4, Name);

    V.SetDetailFont(Canvas.Font);
    Canvas.Font.Color:= ATextColor;
    // Free and total space on the left
    AWidth:= ARect.Right - V.FIconColumn - V.FMargin * 3;
    if Length(Space) > 0 then
    begin
      Canvas.TextOut(V.FIconColumn + V.FMargin div 2,
                     ARect.Bottom - V.FDetailHeight - V.FMargin div 2, Space);
      AWidth:= AWidth - Canvas.TextWidth(Space) - V.FMargin * 2;
    end;
    // Path on the right
    if Length(Path) > 0 then
    begin
      S:= MinimizeFilePath(Path, Canvas, AWidth);
      Canvas.TextOut(ARect.Right - V.FMargin * 2 - Canvas.TextWidth(S),
                     ARect.Bottom - V.FDetailHeight - V.FMargin div 2, S);
    end;
  end;

  // Separator
  Canvas.Pen.Style:= psSolid;
  Canvas.Pen.Width:= Max(1, MobilePx(1));
  Canvas.Pen.Color:= V.GetSeparatorColor;
  Canvas.Line(V.FMargin, ARect.Bottom - 1, ARect.Right - V.FMargin, ARect.Bottom - 1);
end;

procedure TTouchList.Paint;
var
  S: String;
  ARect: TRect;
  V: TTouchFileView;
  ARow, AFirst, ALast: Integer;
  AHeight, AContent: Integer;
  ABackColor, ATextColor: TColor;
begin
  V:= FFileView;
  ABackColor:= V.DimColor(gColors.FilePanel^.BackColor);
  ATextColor:= gColors.FilePanel^.ForeColor;

  Canvas.Brush.Style:= bsSolid;
  Canvas.Brush.Color:= ABackColor;
  Canvas.FillRect(ClientRect);

  if (GetRowCount = 0) or (V.FRowHeight <= 0) then
  begin
    // Explain why the list is empty
    if V.IsLoadingFileList then
      S:= rsMsgLoadingFileList
    else begin
      S:= rsMsgNoFiles;
    end;
    V.SetDetailFont(Canvas.Font);
    Canvas.Font.Color:= BlendColor(ABackColor, ATextColor, 60);
    Canvas.Brush.Style:= bsClear;
    Canvas.TextOut((ClientWidth - Canvas.TextWidth(S)) div 2, V.FRowHeight div 2, S);
    Exit;
  end;

  AFirst:= FOffset div V.FRowHeight;
  ALast:= Min(GetRowCount - 1, (FOffset + ClientHeight - 1) div V.FRowHeight);

  for ARow:= AFirst to ALast do
  begin
    if V.FPlacesMode then
      DrawPlace(ARow, GetRowRect(ARow))
    else
      DrawRow(ARow, GetRowRect(ARow));
  end;

  // Scroll position indicator
  AContent:= GetRowCount * V.FRowHeight;
  if AContent > ClientHeight then
  begin
    AHeight:= Max(MobilePx(24), Int64(ClientHeight) * ClientHeight div AContent);
    ARect.Right:= ClientWidth;
    ARect.Left:= ARect.Right - Max(2, MobilePx(3));
    ARect.Top:= Int64(ClientHeight - AHeight) * FOffset div GetMaxOffset;
    ARect.Bottom:= ARect.Top + AHeight;
    Canvas.Brush.Style:= bsSolid;
    Canvas.Brush.Color:= BlendColor(ABackColor, ATextColor, 40);
    Canvas.FillRect(ARect);
  end;
end;

{ TTouchFileView }

procedure TTouchFileView.CreateDefault(AOwner: TWinControl);
begin
  inherited CreateDefault(AOwner);

  FActiveIndex:= InvalidFileIndex;

  FList:= TTouchList.Create(Self, Self);
  MainControl:= FList;
  // Taps, scrolling and the long press are handled by the list itself,
  // the mouse handlers of the file view would start dragging of files
  FList.DetachMouseHandlers;

  FHeader:= TTouchHeader.Create(Self, Self);

  // By default always use some properties.
  FilePropertiesNeeded:= [fpName,
                          fpSize,            // For info panel (total size, selected size)
                          fpAttributes,      // For distinguishing directories
                          fpLink,            // For distinguishing directories (link to dir) and link icons
                          fpModificationTime // For selecting/coloring files (by SearchTemplate)
                         ];

  UpdateMetrics;
end;

destructor TTouchFileView.Destroy;
begin
  ClearPlaces;
  ClearIcons;
  inherited Destroy;
end;

procedure TTouchFileView.ClearIcons;
var
  AZone: THeaderZone;
begin
  for AZone:= Low(THeaderZone) to High(THeaderZone) do
    FreeAndNil(FIcons[AZone]);
end;

procedure TTouchFileView.LoadIcons;
var
  AZone: THeaderZone;
begin
  ClearIcons;
  for AZone:= Low(THeaderZone) to High(THeaderZone) do
  begin
    if Length(HEADER_ICONS[AZone]) > 0 then
      FIcons[AZone]:= PixMapManager.GetThemeIcon(HEADER_ICONS[AZone], gIconsSize);
  end;
  // The refresh icon has a different look in the big sizes,
  // use the green one which is on the tool bar of a desktop
  FreeAndNil(FIcons[hzRefresh]);
  FIcons[hzRefresh]:= PixMapManager.GetThemeIcon(HEADER_ICONS[hzRefresh], 24);
  if Assigned(FIcons[hzRefresh]) and (gIconsSize > 24) then
    FIcons[hzRefresh]:= StretchBitmap(FIcons[hzRefresh], gIconsSize,
                                      DimColor(gColors.FilePanel^.BackColor), True);
end;

procedure TTouchFileView.DrawIcon(ACanvas: TCanvas; const ARect: TRect; AIcon: TBitmap);
begin
  if not Assigned(AIcon) then Exit;
  // Not all the icons are available in a big size, such an icon
  // is shown in its original size, so it is as sharp as on a desktop
  ACanvas.Draw(ARect.Left + (ARect.Width - AIcon.Width) div 2,
               ARect.Top + (ARect.Height - AIcon.Height) div 2, AIcon);
end;

procedure TTouchFileView.ClearPlaces;
var
  I: Integer;
begin
  for I:= 0 to High(FPlaces) do
    FreeAndNil(FPlaces[I].Icon);
  SetLength(FPlaces, 0);
end;

procedure TTouchFileView.LoadPlaces;
var
  AHome: String;
  ABackColor: TColor;

  function GetSpace(const APath: String): String;
  var
    AFree, ATotal: Int64;
  begin
    Result:= EmptyStr;
    try
      if GetDiskFreeSpace(APath, AFree, ATotal) then
        Result:= cnvFormatFileSize(AFree, uoscHeader) + ' / ' +
                 cnvFormatFileSize(ATotal, uoscHeader);
    except
      // Not available
    end;
  end;

  procedure Add(const AName, APath: String; AKind: TPlaceKind; AIcon: TBitmap; ASpace: Boolean);
  var
    I: Integer;
  begin
    I:= Length(FPlaces);
    SetLength(FPlaces, I + 1);
    FPlaces[I].Name:= AName;
    FPlaces[I].Path:= APath;
    FPlaces[I].Kind:= AKind;
    FPlaces[I].Icon:= AIcon;
    if ASpace then
      FPlaces[I].Space:= GetSpace(APath)
    else
      FPlaces[I].Space:= EmptyStr;
  end;

  procedure AddUserFolder(const AName, AFolder, AIcon: String);
  var
    APath: String;
    ABitmap: TBitmap;
  begin
    APath:= AHome + AFolder;
    if mbDirectoryExists(APath) then
    begin
      ABitmap:= PixMapManager.GetThemeIcon(AIcon, gIconsSize);
      if ABitmap = nil then ABitmap:= PixMapManager.GetFolderIcon(gIconsSize, ABackColor);
      Add(AName, APath, pkFolder, ABitmap, False);
    end;
  end;

var
  I: Integer;
  AValue: String;
  ADrive: PDrive;
begin
  ClearPlaces;

  ABackColor:= DimColor(gColors.FilePanel^.BackColor);
  AHome:= IncludeTrailingPathDelimiter(GetHomeDir);

  // Device memory
  Add(rsMobilePlaceDevice, ExcludeTrailingPathDelimiter(AHome), pkFolder,
      PixMapManager.GetThemeIcon('media-flash', gIconsSize), True);

  // Memory cards, USB drives and other mounted file systems
  if Assigned(frmMain) and Assigned(frmMain.Drives) then
  begin
    for I:= 0 to frmMain.Drives.Count - 1 do
    begin
      ADrive:= frmMain.Drives[I];
      if ADrive^.IsMounted and (ADrive^.DriveType <> dtVirtual) and
         StrBegins(ADrive^.Path, PathDelim) and (ADrive^.Path <> PathDelim) and
         (IncludeTrailingPathDelimiter(ADrive^.Path) <> AHome) then
      begin
        Add(ADrive^.DisplayName, ADrive^.Path, pkFolder,
            PixMapManager.GetDriveIcon(ADrive, gIconsSize, ABackColor), True);
      end;
    end;
  end;

  // Well known user directories
  AddUserFolder(rsMobilePlacePictures, 'Pictures', 'image-x-generic');
  AddUserFolder(rsMobilePlaceDownloads, 'Downloads', 'go-down');
  AddUserFolder(rsMobilePlaceDocuments, 'Documents', 'x-office-document');
  AddUserFolder(rsMobilePlaceMusic, 'Music', 'audio-x-generic');
  AddUserFolder(rsMobilePlaceVideos, 'Videos', 'video-x-generic');
  AddUserFolder(rsMobilePlaceAndroid, 'android_storage', 'drive-removable-media');

  // File system root
  Add(rsMobilePlaceRoot, PathDelim, pkFolder,
      PixMapManager.GetThemeIcon('drive-harddisk', gIconsSize), True);

  // Directories from the hotlist (favorites)
  if Assigned(gDirectoryHotlist) then
  begin
    for I:= 0 to gDirectoryHotlist.Count - 1 do
    begin
      with gDirectoryHotlist.HotDir[I] do
      begin
        if (Dispatcher = hd_CHANGEPATH) and (Length(HotDirPath) > 0) then
        begin
          AValue:= ExcludeBackPathDelimiter(mbExpandFileName(HotDirPath));
          Add(HotDirName, AValue, pkFolder,
              PixMapManager.GetThemeIcon('cm_dirhotlist', gIconsSize), False);
        end;
      end;
    end;
  end;
  // Editing of the favorites
  Add(rsMobilePlaceBookmarks, EmptyStr, pkBookmarks,
      PixMapManager.GetThemeIcon('cm_configdirhotlist', gIconsSize), False);
end;

procedure TTouchFileView.ShowPlaces;
begin
  if FPlacesMode or IsLoadingFileList then Exit;

  // File commands should not find anything to work with
  MarkFiles(False);

  LoadPlaces;
  FPlacesMode:= True;
  FHeader.Visible:= False;

  FUpdatingActiveFile:= True;
  FList.StopKinetic;
  FList.Offset:= 0;
  FUpdatingActiveFile:= False;
  FList.Invalidate;
end;

procedure TTouchFileView.HidePlaces;
begin
  if not FPlacesMode then Exit;

  FPlacesMode:= False;
  FHeader.Visible:= True;
  ClearPlaces;

  FUpdatingActiveFile:= True;
  FList.StopKinetic;
  FList.Offset:= 0;
  FUpdatingActiveFile:= False;
  FList.Invalidate;

  Notify([fvnVisibleFilePropertiesChanged]);
end;

procedure TTouchFileView.OpenPlace(AIndex: Integer);
var
  APath: String;
begin
  if (AIndex < 0) or (AIndex > High(FPlaces)) then Exit;

  case FPlaces[AIndex].Kind of
    pkBookmarks:
      frmMain.Commands.cm_ConfigDirHotList([]);
    pkFolder:
      begin
        APath:= IncludeTrailingPathDelimiter(FPlaces[AIndex].Path);
        HidePlaces;
        if APath <> CurrentPath then CurrentPath:= APath;
      end;
  end;
end;

procedure TTouchFileView.ChangePathToParent(AllowChangingFileSource: Boolean);
begin
  if FPlacesMode then Exit;

  // There is a list of places above the root directory
  if (FileSourcesCount = 1) and FileSource.IsPathAtRoot(CurrentPath) and
     (fspDirectAccess in FileSource.Properties) then
    ShowPlaces
  else begin
    inherited ChangePathToParent(AllowChangingFileSource);
  end;
end;

procedure TTouchFileView.SetNameFont(AFont: TFont);
begin
  // Metrics are calculated before the control is scaled
  AFont.PixelsPerInch:= Screen.PixelsPerInch;
  FontOptionsToFont(gFonts[dcfMain], AFont);
end;

procedure TTouchFileView.SetDetailFont(AFont: TFont);
begin
  AFont.PixelsPerInch:= Screen.PixelsPerInch;
  FontOptionsToFont(gFonts[dcfMain], AFont);
  AFont.Size:= Max(6, (gFonts[dcfMain].Size * 3 + 2) div 4);
end;

function TTouchFileView.GetSeparatorColor: TColor;
begin
  with gColors.FilePanel^ do
    Result:= BlendColor(DimColor(BackColor), ForeColor, 22);
end;

function TTouchFileView.GetDetails(AFile: TDisplayFile): String;
var
  S: String;
  AShowSize: Boolean;
begin
  // Formatted details are cached in the display strings
  if AFile.DisplayStrings.Count > 0 then
    Exit(AFile.DisplayStrings[0]);

  Result:= EmptyStr;

  with AFile.FSFile do
  begin
    if fpSize in AssignedProperties then
    begin
      // Show size of a directory only when it has been calculated
      AShowSize:= not (IsDirectory or IsLinkToDirectory) or (Size > 0);
      if AShowSize then
        Result:= Trim(FormatFileFunction('DC().GETFILESIZE{}', AFile, Self.FileSource));
    end;
    if fpModificationTime in AssignedProperties then
    begin
      S:= Trim(FormatFileFunction('DC().GETFILETIME{}', AFile, Self.FileSource));
      if Length(S) > 0 then
      begin
        if Length(Result) > 0 then Result:= Result + '  ';
        Result:= Result + S;
      end;
    end;
  end;

  AFile.DisplayStrings.Add(Result);
end;

function TTouchFileView.IndexToRow(AIndex: PtrInt): Integer;
begin
  Result:= AIndex - FFirstIndex;
end;

function TTouchFileView.RowToIndex(ARow: Integer): PtrInt;
begin
  Result:= ARow + FFirstIndex;
end;

procedure TTouchFileView.SetFilesDisplayItems;
var
  I: Integer;
begin
  for I:= 0 to FFiles.Count - 1 do
    FFiles[I].DisplayItem:= Pointer(PtrInt(I));
end;

procedure TTouchFileView.UpdateMetrics;
var
  AFont: TFont;
  ACanvas: TCanvas;
begin
  FMargin:= MobilePx(8);

  ACanvas:= FList.Canvas;
  AFont:= TFont.Create;
  try
    AFont.Assign(ACanvas.Font);

    SetNameFont(ACanvas.Font);
    FNameHeight:= ACanvas.TextHeight('Wg');
    SetDetailFont(ACanvas.Font);
    FDetailHeight:= ACanvas.TextHeight('Wg');

    ACanvas.Font:= AFont;
  finally
    AFont.Free;
  end;

  FRowHeight:= FNameHeight + FDetailHeight + FMargin + FMargin div 2;
  if gShowIcons <> sim_none then
  begin
    FRowHeight:= Max(FRowHeight, gIconsSize + FMargin);
    FIconColumn:= gIconsSize + FMargin * 3;
  end
  else begin
    FIconColumn:= FMargin * 2;
  end;
  FRowHeight:= FRowHeight + gExtraLineSpan;
end;

procedure TTouchFileView.UpdateFreeSpace;
begin
  FFreeSpaceKnown:= False;
  if (FileSourcesCount > 0) and (fspDirectAccess in FileSource.Properties) then
  try
    FFreeSpaceKnown:= FileSource.GetFreeSpace(CurrentPath, FFreeSize, FTotalSize);
  except
    FFreeSpaceKnown:= False;
  end;
end;

procedure TTouchFileView.TapFile(AIndex: PtrInt; AtIcon: Boolean);
var
  AFile: TDisplayFile;
begin
  if IsLoadingFileList or not IsFileIndexInRange(AIndex) then Exit;

  AFile:= FFiles[AIndex];
  SetActiveFile(AIndex, False);

  if AtIcon then
  begin
    // Tap on the icon selects a file
    if IsItemValid(AFile) then
    begin
      InvertFileSelection(AFile, False);
      DoSelectionChanged(AIndex);
    end;
  end
  else if IsTextFile(AFile) then
  begin
    // Text files are opened by the editor of Double Commander
    frmMain.Commands.cm_Edit([]);
  end
  else if AFile.FSFile.IsDirectory or AFile.FSFile.IsLinkToDirectory or
          (AFile.FSFile.Name = '..') then
  begin
    ChooseFile(AFile);
  end
  else begin
    // Ask how to open the file
    ShowOpenMenu(AIndex);
  end;
end;

procedure TTouchFileView.ShowOpenMenu(AIndex: PtrInt);

  procedure AddItem(const ACaption: String; ATag: Integer);
  var
    AItem: TMenuItem;
  begin
    AItem:= TMenuItem.Create(FOpenMenu);
    AItem.Caption:= ACaption;
    AItem.Tag:= ATag;
    AItem.OnClick:= @OpenMenuClick;
    FOpenMenu.Items.Add(AItem);
  end;

var
  P: TPoint;
begin
  if not Assigned(FOpenMenu) then
  begin
    FOpenMenu:= TPopupMenu.Create(Self);
    AddItem(rsMobileOpen, 1);
    AddItem(rsMobileOpenWith, 2);
    AddItem(rsMobileOpenView, 3);
    AddItem(rsMobileOpenEdit, 4);
  end;
  FOpenIndex:= AIndex;
  with GetFileRect(AIndex) do
    P:= FList.ClientToScreen(Classes.Point(FIconColumn, Bottom - FRowHeight div 3));
  MobileHookPopupMenus;
  FOpenMenu.PopUp(P.X, P.Y);
end;

procedure TTouchFileView.OpenMenuClick(Sender: TObject);
var
  AFiles: TStringList;
begin
  if not IsFileIndexInRange(FOpenIndex) then Exit;
  SetActiveFile(FOpenIndex, False);
  case TMenuItem(Sender).Tag of
    1: ChooseFile(FFiles[FOpenIndex]);
    2:
      begin
        AFiles:= TStringList.Create;
        try
          AFiles.Add(FFiles[FOpenIndex].FSFile.FullPath);
          ShowOpenWithDialog(frmMain, AFiles);
        finally
          AFiles.Free;
        end;
      end;
    3: frmMain.Commands.cm_View([]);
    4: frmMain.Commands.cm_Edit([]);
  end;
end;

function TTouchFileView.IsTextFile(AFile: TDisplayFile): Boolean;
const
  TEXT_EXTENSIONS = ';txt;log;ini;conf;cfg;md;json;xml;csv;tsv;sh;py;pl;pas;pp;inc;lpr;' +
                    'c;h;cpp;hpp;js;ts;css;qml;yml;yaml;toml;desktop;spec;srt;nfo;lua;' +
                    'm3u;m3u8;sql;diff;patch;rst;tex;properties;';
var
  AMime: String;
begin
  Result:= False;
  with AFile.FSFile do
  begin
    if IsDirectory or IsLinkToDirectory then Exit;
    if not (fspDirectAccess in FileSource.Properties) then Exit;
    if Pos(';' + LowerCase(Extension) + ';', TEXT_EXTENSIONS) > 0 then Exit(True);
{$IF DEFINED(UNIX)}
    try
      AMime:= GetFileMimeType(FullPath);
      Result:= StrBegins(AMime, 'text/');
    except
      Result:= False;
    end;
{$ENDIF}
  end;
end;

procedure TTouchFileView.MarkByMask(const AMask: String; AFiles, AFolders: Boolean; AMode: TMarkMode);
var
  I: Integer;
  AFile: TDisplayFile;
  AFolder: Boolean;
begin
  if FPlacesMode or IsLoadingFileList then Exit;
  for I:= 0 to FFiles.Count - 1 do
  begin
    AFile:= FFiles[I];
    if not IsItemValid(AFile) then Continue;
    AFolder:= AFile.FSFile.IsDirectory or AFile.FSFile.IsLinkToDirectory;
    if AFolder and not AFolders then Continue;
    if (not AFolder) and not AFiles then Continue;
    if not MatchesMaskList(AFile.FSFile.Name, AMask, ';,') then Continue;
    case AMode of
      mmSelect:   MarkFile(AFile, True, False);
      mmUnselect: MarkFile(AFile, False, False);
      mmInvert:   InvertFileSelection(AFile, False);
    end;
  end;
  DoSelectionChanged;
end;

procedure TTouchFileView.LongPressFile(AIndex: PtrInt; const APoint: TPoint);
var
  P: TPoint;
  ABackground: Boolean;
begin
  if IsLoadingFileList then Exit;

  ABackground:= not IsFileIndexInRange(AIndex);
  if not ABackground then SetActiveFile(AIndex, False);

  P:= FList.ClientToScreen(APoint);
  MobileHookPopupMenus;
  frmMain.Commands.DoContextMenu(Self, P.X, P.Y, ABackground);
end;

procedure TTouchFileView.HeaderClick(AZone: THeaderZone);
begin
  if FList.CanSetFocus then FList.SetFocus;

  case AZone of
    hzPath:
      frmMain.Commands.cm_DirHotList([]);
    hzCount:
      begin
        if IsLoadingFileList then Exit;
        // Select all files or clear the selection
        MarkFiles(FSelectedCount = 0);
      end;
    hzParent:
      ChangePathToParent(True);
    hzHome:
      // Device memory, memory cards and favorites
      ShowPlaces;
    hzRefresh:
      frmMain.Commands.cm_Refresh([]);
  end;
end;

procedure TTouchFileView.AfterChangePath;
begin
  inherited AfterChangePath;

  HidePlaces;

  if not IsLoadingFileList then
  begin
    FUpdatingActiveFile:= True;
    FList.StopKinetic;
    FList.Offset:= 0;
    FUpdatingActiveFile:= False;
  end;

  UpdateFreeSpace;
  FHeader.Invalidate;
end;

procedure TTouchFileView.FileSourceFileListLoaded;
begin
  inherited FileSourceFileListLoaded;

  FUpdatingActiveFile:= True;
  FList.StopKinetic;
  FList.Offset:= 0;
  FUpdatingActiveFile:= False;
end;

procedure TTouchFileView.DisplayFileListChanged;
var
  ScrollTo: Boolean;
begin
  ScrollTo:= IsActiveFileVisible;

  // Parent directory item is replaced by the header button
  if (FFiles.Count > 0) and (FFiles[0].FSFile.Name = '..') then
    FFirstIndex:= 1
  else begin
    FFirstIndex:= 0;
  end;

  SetFilesDisplayItems;

  if FFiles.Count = 0 then
    FActiveIndex:= InvalidFileIndex
  else begin
    FActiveIndex:= EnsureRange(FActiveIndex, 0, FFiles.Count - 1);
  end;

  FList.UpdateScroll;

  if SetActiveFileNow(RequestedActiveFile, True, FLastTopRowIndex) then
    RequestedActiveFile:= ''
  else
    // Requested file was not found, restore position to last active file.
    SetActiveFileNow(LastActiveFile, ScrollTo, FLastTopRowIndex);

  Notify([fvnVisibleFilePropertiesChanged]);

  inherited DisplayFileListChanged;

  UpdateFreeSpace;
  FHeader.Invalidate;
end;

procedure TTouchFileView.DoFileUpdated(AFile: TDisplayFile; UpdatedProperties: TFilePropertiesTypes);
begin
  // Details should be formatted again
  AFile.DisplayStrings.Clear;
  inherited DoFileUpdated(AFile, UpdatedProperties);
end;

procedure TTouchFileView.MoveActiveFile(ADelta: Integer);
var
  AIndex: PtrInt;
begin
  if FPlacesMode or (FList.RowCount = 0) then Exit;
  AIndex:= EnsureRange(Max(FActiveIndex, FFirstIndex - 1) + ADelta,
                       FFirstIndex, FFiles.Count - 1);
  SetActiveFile(AIndex, True);
end;

procedure TTouchFileView.DoHandleKeyDown(var Key: Word; Shift: TShiftState);
var
  AFile: TDisplayFile;
  APage: Integer;
begin
  APage:= Max(1, FList.ClientHeight div Max(1, FRowHeight) - 1);

  case Key of
    VK_UP:
      begin
        MoveActiveFile(-1);
        Key:= 0;
      end;
    VK_DOWN:
      begin
        MoveActiveFile(1);
        Key:= 0;
      end;
    VK_PRIOR:
      begin
        MoveActiveFile(-APage);
        Key:= 0;
      end;
    VK_NEXT:
      begin
        MoveActiveFile(APage);
        Key:= 0;
      end;
    VK_HOME:
      begin
        MoveActiveFile(-MaxInt div 2);
        Key:= 0;
      end;
    VK_END:
      begin
        MoveActiveFile(MaxInt div 2);
        Key:= 0;
      end;
    VK_INSERT:
      begin
        AFile:= GetActiveDisplayFile;
        if IsItemValid(AFile) then
        begin
          InvertFileSelection(AFile, False);
          DoSelectionChanged(FActiveIndex);
        end;
        MoveActiveFile(1);
        Key:= 0;
      end;
    VK_SPACE:
      if Shift * KeyModifiersShortcut = [] then
      begin
        AFile:= GetActiveDisplayFile;
        if IsItemValid(AFile) then
        begin
          if (AFile.FSFile.IsDirectory or AFile.FSFile.IsLinkToDirectory) and
             not AFile.Selected then
          begin
            CalculateSpace(AFile);
          end;
          InvertFileSelection(AFile, False);
          DoSelectionChanged(FActiveIndex);
        end;
        if gSpaceMovesDown then MoveActiveFile(1);
        Key:= 0;
      end;
  end;

  inherited DoHandleKeyDown(Key, Shift);
end;

procedure TTouchFileView.DoUpdateView;
var
  I: Integer;
begin
  inherited DoUpdateView;

  // Size and date format could be changed
  if Assigned(FFiles) then
    for I:= 0 to FFiles.Count - 1 do FFiles[I].DisplayStrings.Clear;

  // The header of this view shows all the information
  pnlHeader.Visible:= False;
  pnlFooter.Visible:= False;

  UpdateMetrics;
  LoadIcons;
  if FPlacesMode then LoadPlaces;
  FHeader.UpdateView;
  FList.UpdateScroll;

  Notify([fvnVisibleFilePropertiesChanged]);
end;

function TTouchFileView.GetActiveFileIndex: PtrInt;
begin
  if (not FPlacesMode) and Assigned(FFiles) and InRange(FActiveIndex, 0, FFiles.Count - 1) then
    Result:= FActiveIndex
  else
    Result:= InvalidFileIndex;
end;

function TTouchFileView.GetFileIndexFromCursor(X, Y: Integer; out AtFileList: Boolean): PtrInt;
var
  ARow: Integer;
begin
  AtFileList:= True;
  ARow:= FList.GetRowAt(Y);
  if (ARow < 0) or FPlacesMode then
    Result:= InvalidFileIndex
  else
    Result:= RowToIndex(ARow);
end;

function TTouchFileView.GetFileRect(FileIndex: PtrInt): TRect;
begin
  Result:= FList.GetRowRect(IndexToRow(FileIndex));
end;

function TTouchFileView.GetIconRect(FileIndex: PtrInt): TRect;
begin
  Result:= GetFileRect(FileIndex);
  Result.Left:= Result.Left + (FIconColumn - gIconsSize) div 2;
  Result.Top:= Result.Top + (FRowHeight - gIconsSize) div 2;
  Result.Right:= Result.Left + gIconsSize;
  Result.Bottom:= Result.Top + gIconsSize;
end;

function TTouchFileView.GetVisibleFilesIndexes: TRange;
begin
  if FPlacesMode or (FRowHeight <= 0) or (FList.RowCount = 0) or (csLoading in ComponentState) then
  begin
    Result.First:= 0;
    Result.Last:= -1;
  end
  else begin
    Result.First:= RowToIndex(FList.Offset div FRowHeight);
    Result.Last:= RowToIndex((FList.Offset + FList.ClientHeight - 1) div FRowHeight);
    if Result.Last >= FFiles.Count then Result.Last:= FFiles.Count - 1;
    if Result.First > Result.Last then Result.First:= Result.Last;
  end;
end;

procedure TTouchFileView.MouseScrollTimer(Sender: TObject);
begin
  // Scrolling is fully handled by the list itself
end;

procedure TTouchFileView.RedrawFile(FileIndex: PtrInt);
begin
  FList.Invalidate;
end;

procedure TTouchFileView.RedrawFile(DisplayFile: TDisplayFile);
begin
  FList.Invalidate;
end;

procedure TTouchFileView.RedrawFiles;
begin
  FList.Invalidate;
end;

procedure TTouchFileView.SetActiveFile(FileIndex: PtrInt; ScrollTo: Boolean; aLastTopRowIndex: PtrInt);
begin
  if not IsFileIndexInRange(FileIndex) then Exit;

  FActiveIndex:= FileIndex;

  if ScrollTo then
  begin
    if aLastTopRowIndex <> -1 then
      FList.Offset:= aLastTopRowIndex * FRowHeight;
    FList.MakeVisible(IndexToRow(FileIndex));
  end;

  FList.Invalidate;

  DoFileIndexChanged(FileIndex, FList.Offset div Max(1, FRowHeight));
end;

procedure TTouchFileView.ShowRenameFileEdit(var aFile: TFile; const withExt: Boolean);
begin
  if aFile.Name = EmptyStr then Exit;

  if not edtRename.Visible then
  begin
    SetNameFont(edtRename.Font);
    FList.StopKinetic;
    FList.MakeVisible(IndexToRow(FActiveIndex));
    UpdateRenameFileEditPosition(withExt);
  end;

  inherited ShowRenameFileEdit(aFile, withExt);
end;

procedure TTouchFileView.UpdateRenameFileEditPosition(const withExt: Boolean);
var
  ARect: TRect;
begin
  inherited UpdateRenameFileEditPosition(withExt);

  ARect:= GetFileRect(FActiveIndex);
  ARect.Left:= FIconColumn - MobilePx(2);
  ARect.Right:= ARect.Right - FMargin;
  ARect.Bottom:= ARect.Top + FNameHeight + FMargin;

  edtRename.SetBounds(ARect.Left, ARect.Top, ARect.Width, ARect.Height);
end;

procedure TTouchFileView.UpdateInfoPanel;
var
  I: Integer;
begin
  inherited UpdateInfoPanel;

  FTotalCount:= 0;
  if Assigned(FFiles) then
  begin
    for I:= 0 to FFiles.Count - 1 do
    begin
      if FFiles[I].FSFile.Name <> '..' then Inc(FTotalCount);
    end;
  end;

  if Assigned(FHeader) then FHeader.Invalidate;
end;

function TTouchFileView.Clone(NewParent: TWinControl): TTouchFileView;
begin
  Result:= TTouchFileView.Create(NewParent, Self);
end;

procedure TTouchFileView.SaveConfiguration(AConfig: TXmlConfig; ANode: TXmlNode; ASaveHistory: Boolean);
begin
  inherited SaveConfiguration(AConfig, ANode, ASaveHistory);

  AConfig.SetAttr(ANode, 'Type', 'touch');
end;

procedure TTouchFileView.UpdateColor;
begin
  inherited UpdateColor;
  if Assigned(FHeader) then FHeader.Invalidate;
end;

end.
