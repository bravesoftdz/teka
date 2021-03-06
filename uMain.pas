{
    This file is part of Teka, a drawing game for very young children who
    will discover mouse moving.

    Copyright (C) 2011-2012 João Marcelo S. Vaz

    Teka is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Teka is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
}

unit uMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ComCtrls,
  ExtCtrls, ActnList, uUtil, uColors;

type

  { TfmMain }

  TfmMain = class(TForm)
    acAbout: TAction;
    acClear: TAction;
    acClose: TAction;
    acShowOptions: TAction;
    acToggleFullscreen: TAction;
    ActionList: TActionList;
    PaintBox: TPaintBox;
    StatusBar: TStatusBar;
    procedure acAboutExecute(Sender: TObject);
    procedure acClearExecute(Sender: TObject);
    procedure acCloseExecute(Sender: TObject);
    procedure acShowOptionsExecute(Sender: TObject);
    procedure acToggleFullscreenExecute(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure PaintBoxMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PaintBoxMouseEnter(Sender: TObject);
    procedure PaintBoxMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
  private
    { private declarations }
    Images: TFPList;
    fLastPoint: TPoint;
    fOptions: TOptions;
    fPathColor: TColorPallete;
    fStarColor: TColorPallete;
    MyCanvas: TCanvas;
    OriginalBounds: TRect;
    OriginalWindowState: TWindowState;
    ScreenBounds: TRect;
    procedure SwitchFullScreen;
    procedure GetImages;
    procedure OnFileFound(FileIterator: TFileIterator);
  public
    { public declarations }
    procedure LoadOptions;
    procedure DrawStar(Center: TPoint; spike_count: Integer);
    procedure DrawImage(Center: TPoint; ImageNumber: Integer);
    procedure DrawPath(LastPoint,CurrentPoint: TPoint);
    procedure Test;
  end;

var
  fmMain: TfmMain;

implementation

{$R *.lfm}

uses uOptions, uStrings;

function GetAColorPallete(APalleteType: TColorPalleteType): TColorPallete;
begin
  case APalleteType of
    cptRandomRainbowColorPallete:
      Result:= TRandomRainbowColorPallete.Create;
    cptRainbowColorPallete:
      Result:= TRainbowColorPallete.Create;
    cptRandomWebSafeColorPallete:
      Result:= TRandomWebSafeColorPallete.Create;
  end;
end;

{ TfmMain }

procedure TfmMain.acAboutExecute(Sender: TObject);
begin
  ShowMessage(Application.Title);
end;

procedure TfmMain.acClearExecute(Sender: TObject);
begin
  with PaintBox.Canvas do
    begin
      Brush.Color:= fOptions.BackgroundColor;
      Clear;
    end;
end;

procedure TfmMain.acCloseExecute(Sender: TObject);
begin
  Close;
end;

procedure TfmMain.acShowOptionsExecute(Sender: TObject);
begin
  with TfmOptions.Create(nil) do
    try
      StarReciprocalRadius:= fOptions.StarReciprocalRadius;
      OuterRadius:= fOptions.OuterRadius;
      StarSpikes:= fOptions.StarSpikes;
      BackgroundColor:= fOptions.BackgroundColor;
      PathWidth:= fOptions.PathWidth;
      PathType:= fOptions.PathType;
      PathColorType:= fOptions.PathColorType;
      StampColorType:= fOptions.StampColorType;
      ImagePaths:= fOptions.ImagePaths;
      if Execute then
        begin
         fOptions.StarReciprocalRadius:= StarReciprocalRadius;
         fOptions.OuterRadius:= OuterRadius;
         fOptions.StarSpikes:= StarSpikes;
         fOptions.BackgroundColor:= BackgroundColor;
         fOptions.PathWidth:= PathWidth;
         fOptions.PathType:= PathType;
         fOptions.PathColorType:= PathColorType;
         fOptions.StampColorType:= StampColorType;
//          fOptions.ImagePaths.Assign(ImagePaths);
         LoadOptions;
        end;
    finally
      Release;
    end;
end;

procedure TfmMain.acToggleFullscreenExecute(Sender: TObject);
begin
  if BorderStyle <> bsNone then begin
    // To full screen
    OriginalWindowState := WindowState;
    OriginalBounds := BoundsRect;

    BorderStyle := bsNone;
    ScreenBounds := Screen.MonitorFromWindow(Handle).BoundsRect;
    with ScreenBounds do
      SetBounds(Left, Top, Right - Left, Bottom - Top) ;
  end else begin
    // From full screen
    {$IFDEF MSWINDOWS}
    BorderStyle := bsSizeable;
    {$ENDIF}
    if OriginalWindowState = wsMaximized then
      WindowState := wsMaximized
    else
      with OriginalBounds do
        SetBounds(Left, Top, Right - Left, Bottom - Top) ;
    {$IFDEF LINUX}
    BorderStyle := bsSizeable;
    {$ENDIF}
  end;
end;

procedure TfmMain.Test;
var
  i: Integer;
  Center: TPoint;
begin
  for i:= 1 to 20 do
    begin
      Center.X:= i*30;
      Center.Y:= Center.X;
      DrawStar(Center, i);
    end;
end;

procedure TfmMain.FormCreate(Sender: TObject);
begin
  Caption:= Application.Title;
  Randomize;
  Images:= TFPList.Create;
  fLastPoint:= Point(0,0);
  fOptions:= TOptions.Create(GetAppConfigFile(False));
  fOptions.AddImagePath(ExtractFilePath(Application.EXEName) + 'images');
  fOptions.AddImagePath(ExtractFilePath(Application.EXEName) + 'img');
  MyCanvas:= PaintBox.Canvas;
  StatusBar.SimpleText:= Format('%s : ESC | %s : %s | %s : Ctrl+F9 | %s : F11 | %s : F1',[s_Quit,s_Clear,Upcase(s_SpaceKey),s_Options,s_ToggleFullscreen, s_About]);
  LoadOptions;
end;

procedure TfmMain.FormDestroy(Sender: TObject);
begin
  if fOptions.Changed then
    fOptions.SaveToFile(GetAppConfigFile(False));
  fPathColor.Free;
  fStarColor.Free;
  Images.Free;
end;

procedure TfmMain.FormShow(Sender: TObject);
begin
// WindowState:= wsFullScreen;
end;

procedure TfmMain.GetImages;
var
  fs: TFileSearcher;
  i: Integer;
begin
  fs:= TFileSearcher.Create;
  try
    fs.OnFileFound:= @OnFileFound;
    Images.Clear;
    for i:= 0 to (fOptions.ImagePaths.Count - 1) do
      fs.Search(fOptions.ImagePaths[i]);     //TODO: search only image files -> image extensions
  finally
    fs.Free;
  end;
end;

procedure TfmMain.LoadOptions;
begin
  fPathColor:= GetAColorPallete(fOptions.PathColorType);
  fStarColor:= GetAColorPallete(fOptions.StampColorType);
  with MyCanvas do
    begin
      Color:= fOptions.BackgroundColor;
      Brush.Style:= bsSolid;
      Brush.Color:= fOptions.BackgroundColor;
      Pen.Color:= fOptions.BackgroundColor;
      Pen.Mode:= pmCopy;
      Pen.Style:= psSolid;
      Pen.Width:= 1;
    end;
  GetImages;
end;

procedure TfmMain.OnFileFound(FileIterator: TFileIterator);
var
  APicture: TPicture;
begin
  APicture:= TPicture.Create;
  try
    APicture.LoadFromFile(FileIterator.FileName);
    Images.Add(APicture);
  except
    //ignore exception -> dont add this file to the list
  end;
end;

procedure TfmMain.PaintBoxMouseEnter(Sender: TObject);
begin
  fLastPoint:= PaintBox.ScreenToClient(Mouse.CursorPos);
end;

procedure TfmMain.PaintBoxMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  DrawPath(fLastPoint, Point(X,Y));
  fLastPoint:= Point(X,Y);
end;

procedure TfmMain.SwitchFullScreen;
begin

end;


procedure TfmMain.PaintBoxMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  nStarTypes, nImageTypes: Integer;
  DrawingType: Integer;
begin
  nStarTypes:= fOptions.StarSpikes - 2;
  nImageTypes:= Images.Count;
  DrawingType:= Random(nStarTypes + nImageTypes); //every star and image has the same probability
  if DrawingType < nStarTypes then
    DrawStar(Point(X,Y), Random(nStarTypes) + 3)
  else
    DrawImage(Point(X,Y), Random(nImageTypes));
end;

procedure TfmMain.DrawPath(LastPoint, CurrentPoint: TPoint);
var
  c: TColor;
  radius: Integer;
begin
  c:= fPathColor.GetColor;
  case fOptions.PathType of
    ptCircle:
      begin
        radius:= Trunc(fOptions.PathWidth/2);
        with MyCanvas do
          begin
            Brush.Color:= c;
            Pen.Color:= c;
            Pen.Width:= 1;
            Ellipse (CurrentPoint.X-radius,CurrentPoint.Y-radius,
                     CurrentPoint.X+radius,CurrentPoint.Y+radius);
          end;
      end;
    ptLine:
      begin
        with MyCanvas do
          begin
            Brush.Color:= c;
            Pen.Color:= c;
            Pen.Width:= fOptions.PathWidth;
            MoveTo(LastPoint);
            LineTo(CurrentPoint);
          end;
      end;
  end;
end;

procedure TfmMain.DrawStar(Center: TPoint; spike_count: Integer);
const
  RadConvert = PI/180;
var
  c: TColor;
  Points: array of TPoint;
  i: Integer;
  radius: Integer;
  angle, rotation: Extended;
begin
  SetLength(Points,2*spike_count);
  rotation:= 360/spike_count;
  for i:= 0 to (2*spike_count-1) do begin
      if (i mod 2) = 0 then
        radius:= Round(fOptions.OuterRadius/fOptions.StarReciprocalRadius)
      else
        radius:= fOptions.OuterRadius;
    angle:= ((i * rotation) + 90) * RadConvert;
    Points[i].X:= Center.X + Round(cos(angle) * radius);
    Points[i].Y:= Center.Y - Round(sin(angle) * radius);
  end;

  c:= fStarColor.GetColor;
  with MyCanvas do
    begin
      Brush.Color:= c;
      Pen.Color:= c;
      Pen.Width:= 9*Random(2) + 1;
      Polygon(Points);
    end;
end;


procedure TfmMain.DrawImage(Center: TPoint; ImageNumber: Integer);
var
  DestRect: TRect;
begin
  DestRect.Left:= Center.X - fOptions.OuterRadius;
  DestRect.Right:= Center.X + fOptions.OuterRadius;
  DestRect.Top:= Center.Y - fOptions.OuterRadius;
  DestRect.Bottom:= Center.Y + fOptions.OuterRadius;
  MyCanvas.StretchDraw(DestRect,TPicture(Images[ImageNumber]).Bitmap);
end;


end.

