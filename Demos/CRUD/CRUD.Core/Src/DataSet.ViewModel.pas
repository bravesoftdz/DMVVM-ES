unit DataSet.ViewModel;

interface

uses
  System.Classes,
  Data.DB,

  Spring,
  Spring.Collections,

  DataSet.Interfaces,
  DataSet.Model,
  DataSet.Types,

  MVVM.Attributes,
  MVVM.Interfaces,
  MVVM.Interfaces.Architectural,
  MVVM.Bindings;

type
  [ViewModel_Implements(IDataSet_ViewModel)]
  TDataSet_ViewModel = class(TViewModel, IDataSet_ViewModel)
  private
    FModel: TDataSet_Model;
    FTableName: String;
    FNewRowView: string;
    FUpdateRowView: string;
  protected
    function GetModel: TDataSet_Model;

    function GetDataSet: TDataSet;

    function GetTableName: String;
    procedure SetTableName(const ATableName: string);

    function GetNewRowView: string;
    procedure SetNewRowView(const AViewName: string);

    function GetUpdateRowView: string;
    procedure SetUpdateRowView(const AViewName: string);

    function GetIsOpen: Boolean;

  public
    procedure SetupViewModel; override;

    procedure SetModel(AModel: TDataSet_Model);

    procedure CloseDataSet;
    procedure OpenDataSet;

    procedure MakeGetRows;
    function GetRows(const AFields: TFieldsToGet): TFieldConverters;
    procedure DeleteActiveRow;
    procedure MakeAppend;
    procedure AppendRow(const AFields: TFieldConverters);
    procedure MakeUpdate;
    procedure UpdateActiveRow(const AFields: TFieldConverters);

    property NewRowView: string read GetNewRowView write SetNewRowView;
    property UpdateRowView: string read GetUpdateRowView write SetUpdateRowView;
    property TableName: string read GetTableName write SetTableName;
    property IsOpen: Boolean read GetIsOpen;
    property DataSet: TDataSet read GetDataSet;
    property Model: TDataSet_Model read GetModel;
  end;

implementation

uses
  System.Rtti,
  System.SysUtils,
  System.Threading,
  System.Diagnostics,
  System.UITypes,

  MVVM.Utils,
  MVVM.Core,
  MVVM.Types;

{ TDataSetFile_ViewModel }

procedure TDataSet_ViewModel.OpenDataSet;
begin
  if not FModel.IsOpen then
    FModel.Open;
end;

procedure TDataSet_ViewModel.AppendRow(const AFields: TFieldConverters);
begin
  FModel.AppendRow(AFields);
end;

procedure TDataSet_ViewModel.CloseDataSet;
begin
  if FModel.IsOpen then
    FModel.Close
end;

procedure TDataSet_ViewModel.DeleteActiveRow;
begin
  if not FModel.IsOpen then
  begin
    MVVMCore.PlatformServices.MessageDlg('Warning (delete)', 'The dataset is closed');
    Exit;
  end;
  FModel.DataSet.Delete;
end;

function TDataSet_ViewModel.GetDataSet: TDataSet;
begin
  Result := FModel.DataSet;
end;

function TDataSet_ViewModel.GetIsOpen: Boolean;
begin
  Result := FModel.IsOpen
end;

function TDataSet_ViewModel.GetModel: TDataSet_Model;
begin
  Result := FModel
end;

function TDataSet_ViewModel.GetNewRowView: string;
begin
  Result := FNewRowView
end;

function TDataSet_ViewModel.GetRows(const AFields: TFieldsToGet): TFieldConverters;
begin
  Result := FModel.GetRows(AFields);
end;

function TDataSet_ViewModel.GetTableName: String;
begin
  Result := FTableName;
end;

function TDataSet_ViewModel.GetUpdateRowView: string;
begin
  Result := FUpdateRowView
end;

procedure TDataSet_ViewModel.MakeAppend;
var
  LView: IView<IDataSet_ViewModel>;
begin
  OpenDataSet;

  LView := Utils.ShowModalView<IDataSet_ViewModel>(Self, FNewRowView, procedure (AResult: TModalResult)
                                                   begin
                                                     ;
                                                   end, MVVMCore.DefaultViewPlatform);
end;

procedure TDataSet_ViewModel.MakeGetRows;
begin
  if not FModel.IsOpen then
    FModel.Open
  else FModel.DataSet.Refresh;
end;

procedure TDataSet_ViewModel.MakeUpdate;
var
  LView: IView<IDataSet_ViewModel>;
begin
  if not FModel.IsOpen then
  begin
    MVVMCore.PlatformServices.MessageDlg('Warning (update)', 'The dataset is not opened');
    Exit;
  end;

  LView := Utils.ShowModalView<IDataSet_ViewModel>(Self, FUpdateRowView, procedure (AResult: TModalResult)
                                                   begin
                                                     ;
                                                   end, MVVMCore.DefaultViewPlatform);
end;

procedure TDataSet_ViewModel.SetModel(AModel: TDataSet_Model);
begin
  if FModel <> AModel then
  begin
    FModel := AModel;
    SetupViewModel;
  end;
end;

procedure TDataSet_ViewModel.SetNewRowView(const AViewName: string);
begin
  FNewRowView := AViewName
end;

procedure TDataSet_ViewModel.SetTableName(const ATableName: string);
begin
  if FTableName <> ATableName then
  begin
    FTableName       := ATableName;
    FModel.TableName := FTableName;
  end;
end;

procedure TDataSet_ViewModel.SetUpdateRowView(const AViewName: string);
begin
  FUpdateRowView := AViewName
end;

procedure TDataSet_ViewModel.SetupViewModel;
begin
  if not FTableName.IsEmpty then
  begin
    FModel.TableName := FTableName;
    FModel.Open;
  end;
end;

procedure TDataSet_ViewModel.UpdateActiveRow(const AFields: TFieldConverters);
begin
  FModel.UpdateActiveRow(AFields);
end;

initialization
  TDataSet_ViewModel.ClassName; //as there should be no implicit create, we must do this so the rtti info of the class is included in the final exe

end.
