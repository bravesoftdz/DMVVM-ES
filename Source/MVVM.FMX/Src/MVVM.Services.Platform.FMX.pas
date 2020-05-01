unit MVVM.Services.Platform.FMX;

interface

uses
  FMX.Platform,
  System.Classes,
  System.SysUtils,
  System.UITypes,

  MVVM.Interfaces;

type
  TFMXPlatformServices = class(TPlatformServicesBase)
  public
    function CreatePlatformEmptyForm: TComponent; override;
    procedure AssignParent(AChild, AParent: TComponent); override;
    function MessageDlg(const ATitulo: string; const ATexto: String): Boolean; override;
    procedure ShowFormView(AComponent: TComponent); override;
    procedure ShowModalFormView(AComponent: TComponent; const AResultProc: TProc<TModalResult>); override;
    function IsMainThreadUI: Boolean; override;
    function LoadBitmap(const AFileName: String): TObject; overload; override;
    function LoadBitmap(const AStream: TStream): TObject; overload; override;
    function LoadBitmap(const AData: TBytes): TObject; overload; override;
    function LoadBitmap(const AMemory: Pointer; const ASize: Integer): TObject; overload; override;
  end;

procedure InitializePlatform;

implementation

uses
  FMX.Forms,
  FMX.Controls,
  FMX.Dialogs,
  FMX.Graphics,

  MVVM.Core;

{ TFMXServicioDialogo }

procedure TFMXPlatformServices.AssignParent(AChild, AParent: TComponent);
begin
  if AParent is TForm then
    TControl(AChild).Parent := TForm(AParent)
  else TControl(AChild).Parent := TControl(AParent)
end;

function TFMXPlatformServices.CreatePlatformEmptyForm: TComponent;
begin
  Result := TForm.Create(nil);
end;

function TFMXPlatformServices.IsMainThreadUI: Boolean;
begin
  Result := TThread.Current.ThreadID = MainThreadID;
end;

function TFMXPlatformServices.LoadBitmap(const AFileName: String): TObject;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := TBitmap.CreateFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

function TFMXPlatformServices.LoadBitmap(const AStream: TStream): TObject;
begin
  Result := TBitmap.CreateFromStream(AStream);
end;

function TFMXPlatformServices.LoadBitmap(const AData: TBytes): TObject;
var
  Stream: TBytesStream;
begin
  Stream := TBytesStream.Create(AData);
  try
    Result := TBitmap.CreateFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

function TFMXPlatformServices.LoadBitmap(const AMemory: Pointer; const ASize: Integer): TObject;
var
  Stream: TMemoryStream;
begin
  Stream := TMemoryStream.Create;
  try
    Stream.WriteBuffer(AMemory^, ASize);
    Stream.Position := 0;
    Result          := TBitmap.CreateFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

function TFMXPlatformServices.MessageDlg(const ATitulo, ATexto: String): Boolean;
begin
  Result := FMX.Dialogs.MessageDlg(ATitulo, TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) = mrYes
end;

procedure TFMXPlatformServices.ShowFormView(AComponent: TComponent);
begin
  if not (AComponent.InheritsFrom(TForm)) then
    raise Exception.Create('The component ' + AComponent.QualifiedClassName + ' must inherit from TForm');
  TForm(AComponent).Show;
end;

procedure TFMXPlatformServices.ShowModalFormView(AComponent: TComponent; const AResultProc: TProc<TModalResult>);
begin
  TForm(AComponent).ShowModal(AResultProc);
end;

procedure InitializePlatform;
begin;
end;

initialization

MVVMCore.RegisterPlatformServices(TFMXPlatformServices);

end.
