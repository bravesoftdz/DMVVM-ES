unit MVVM.ViewFactory;

interface

uses
  System.Rtti,
  System.UITypes,
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,

  MVVM.Interfaces.Architectural;

type
  { A factory for creating views based on their names.
    View models can create a view by calling TViewFactory.CreateView. }
  TViewFactory = class
{$REGION 'Internal Declarations'}
  private
    class var FRegisteredViews: TDictionary<String, TRttiInstanceType>;
  public
    class destructor Destroy;
{$ENDREGION 'Internal Declarations'}
  public
    class procedure Register(const AViewClass: TRttiInstanceType; const AViewName: String; const APlatform: String = ''); static;

    { Creates a view using a previously registered view class.
      Returns:
      A newly created view that represents AViewName.
      Raises:
      EListError if there is no view registered with the given AViewName. }
    class function CreateView<TVM: IViewModel>(const APlatform: string; const AViewName: String; const AOwner: TComponent; AViewModel: TVM): IView<TVM>; static;
  end;

  TViewFactoryClass = class of TViewFactory;

type
  { Internal class used to manage lifetimes of views. }
  TViewProxy<TVM: IViewModel> = class(TInterfacedObject, IView, IView<TVM>)
{$REGION 'Internal Declarations'}
  private type
    TViewFreeListener = class(TComponent)
    strict private
      FActualView: IView<TVM>;
      [unsafe]
      FActualViewObject: TComponent;
    protected
      procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    public
      constructor Create(AView: IView<TVM>); reintroduce;
      destructor Destroy; override;

      property ActualView: IView<TVM> read FActualView;
    end;
  private
    FViewFreeListener: TViewFreeListener;
  protected
    function GetViewModel: TVM;
    { IView }
    procedure ExecuteModal(const AResultProc: TProc<TModalResult>);
  protected
    { IView<TVM> }
    procedure InitView(AViewModel: TVM);
{$ENDREGION 'Internal Declarations'}
  public
    constructor Create(AActualView: IView<TVM>);
    destructor Destroy; override;

    function GetAsObject: TObject;

    procedure SetupView;
    property ViewModel: TVM read GetViewModel;
  end;

  TFormViewProxy<TVM: IViewModel> = class(TInterfacedObject, IView, IView<TVM>, IViewForm<TVM>)
{$REGION 'Internal Declarations'}
  private type
    TViewFreeListener = class(TComponent)
    strict private
      FActualView: IViewForm<TVM>;
      [unsafe]
      FActualViewObject: TComponent;
    protected
      procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    public
      constructor Create(AView: IViewForm<TVM>); reintroduce;
      destructor Destroy; override;

      property ActualView: IViewForm<TVM> read FActualView;
    end;
  private
    FViewFreeListener: TViewFreeListener;
  protected
    function GetViewModel: TVM;
    { IViewForm }
    procedure Execute;
    procedure ExecuteModal(const AResultProc: TProc<TModalResult>);
  protected
    { IView<TVM> }
    procedure InitView(AViewModel: TVM);
{$ENDREGION 'Internal Declarations'}
  public
    constructor Create(AActualView: IViewForm<TVM>);
    destructor Destroy; override;

    function GetAsObject: TObject;

    procedure SetupView;
    property ViewModel: TVM read GetViewModel;
  end;

implementation

uses
  System.Generics.Defaults,

  MVVM.Utils;

{ TViewProxy<TVM> }

constructor TViewProxy<TVM>.Create(AActualView: IView<TVM>);
begin
  Assert(Assigned(AActualView));
  inherited Create;
  { Executing a view may free it (for example, when the view is a form and its
    CloseAction is set to caFree). When that happens, the IView interface
    will contain an invalid reference, and you may get an access violation when
    it goes out of scope. To avoid this, we use a view proxy. This proxy
    subscribes to a free notification of the view, so it can set the IView
    interface to nil BEFORE the view is destroyed. }
  FViewFreeListener := TViewFreeListener.Create(AActualView);
end;

destructor TViewProxy<TVM>.Destroy;
begin
  FViewFreeListener.Free;
  inherited;
end;

procedure TViewProxy<TVM>.ExecuteModal(const AResultProc: TProc<TModalResult>);
var
  [weak]LViewForm: IViewForm<TVM>;
begin
  if Assigned(FViewFreeListener.ActualView) then
  begin
    if Supports(FViewFreeListener.ActualView, IViewForm<TVM>, LViewForm) then
      LViewForm.ExecuteModal(AResultProc);
  end;
end;

function TViewProxy<TVM>.GetAsObject: TObject;
begin
  Result := Self
end;

function TViewProxy<TVM>.GetViewModel: TVM;
begin
  if Assigned(FViewFreeListener.ActualView) then
    Result := FViewFreeListener.ActualView.ViewModel
  else
    Result := nil;
end;

procedure TViewProxy<TVM>.InitView(AViewModel: TVM);
begin
  if Assigned(FViewFreeListener.ActualView) then
    FViewFreeListener.ActualView.InitView(AViewModel);
end;

procedure TViewProxy<TVM>.SetupView;
begin
  if Assigned(FViewFreeListener.ActualView) then
    FViewFreeListener.ActualView.SetupView;
end;

{ TViewProxy<TVM>.TViewFreeListener }

constructor TViewProxy<TVM>.TViewFreeListener.Create(AView: IView<TVM>);
var
  Instance: TObject;
begin
  inherited Create(nil);
  FActualView := AView;
  Instance    := TObject(AView);
  if (Instance is TComponent) then
  begin
    FActualViewObject := TComponent(Instance);
    FActualViewObject.FreeNotification(Self);
  end;
end;

destructor TViewProxy<TVM>.TViewFreeListener.Destroy;
begin
  if (FActualViewObject <> nil) then
    FActualViewObject.RemoveFreeNotification(Self);
  inherited;
end;

procedure TViewProxy<TVM>.TViewFreeListener.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (AComponent = FActualViewObject) and (Operation = opRemove) then
  begin
    FActualView       := nil;
    FActualViewObject := nil;
  end;
end;

{ TViewFactory }

class function TViewFactory.CreateView<TVM>(const APlatform: string; const AViewName: String; const AOwner: TComponent; AViewModel: TVM): IView<TVM>;
var
  ViewClass: TRttiInstanceType;
  ViewClassComp: TComponentClass;
  ViewComp: TComponent;
  [weak]
  LView: IView<TVM>;
  [weak]
  LViewForm: IViewForm<TVM>;
  LName : string;
  LParams: array of TValue;
begin
  LName := APlatform + '.' + AViewName;
  try
    ViewClass := nil;
    if Assigned(FRegisteredViews) then
      FRegisteredViews.TryGetValue(LName, ViewClass);

    if (ViewClass = nil) then
      raise EListError.CreateFmt('Cannot create view. View "%s" is not registered.', [LName]);

  SetLength(LParams, 1);
  LParams[0] := AOwner;
  ViewComp := Utils.CreateComponent_From_RttiInstance(ViewClass, LParams);
    //ViewClassComp := ViewClass as TComponentClass;
   // ViewComp := ViewClass.Create(AOwner);
    if Supports(ViewComp, IViewForm<TVM>, LViewForm) then
    begin
      Result := TFormViewProxy<TVM>.Create(LViewForm);
    end
    else
    begin
      LView  := ViewComp as IView<TVM>;
      Result := TViewProxy<TVM>.Create(LView);
    end;
    Result.InitView(AViewModel);
  except
    AViewModel := nil;
    raise;
  end;
end;

{ TFormViewProxy<TVM> }

constructor TFormViewProxy<TVM>.Create(AActualView: IViewForm<TVM>);
begin
  Assert(Assigned(AActualView));
  inherited Create;
  { Executing a view may free it (for example, when the view is a form and its
    CloseAction is set to caFree). When that happens, the IView interface
    will contain an invalid reference, and you may get an access violation when
    it goes out of scope. To avoid this, we use a view proxy. This proxy
    subscribes to a free notification of the view, so it can set the IView
    interface to nil BEFORE the view is destroyed. }
  FViewFreeListener := TViewFreeListener.Create(AActualView);
end;

destructor TFormViewProxy<TVM>.Destroy;
begin
FViewFreeListener.Free;
  inherited;
end;

procedure TFormViewProxy<TVM>.Execute;
begin
  FViewFreeListener.ActualView.Execute;
end;

procedure TFormViewProxy<TVM>.ExecuteModal(const AResultProc: TProc<TModalResult>);
var
  [weak]LViewForm: IViewForm<TVM>;
begin
  if Assigned(FViewFreeListener.ActualView) then
  begin
    if Supports(FViewFreeListener.ActualView, IViewForm<TVM>, LViewForm) then
      LViewForm.ExecuteModal(AResultProc);
  end;
end;

function TFormViewProxy<TVM>.GetAsObject: TObject;
begin
  if Assigned(FViewFreeListener.ActualView) then
    Result := FViewFreeListener.ActualView.GetAsObject
  else
    Result := nil;
end;

function TFormViewProxy<TVM>.GetViewModel: TVM;
begin
  if Assigned(FViewFreeListener.ActualView) then
    Result := FViewFreeListener.ActualView.ViewModel
  else
    Result := nil;
end;

procedure TFormViewProxy<TVM>.InitView(AViewModel: TVM);
begin
  if Assigned(FViewFreeListener.ActualView) then
    FViewFreeListener.ActualView.InitView(AViewModel);
end;

procedure TFormViewProxy<TVM>.SetupView;
begin
  if Assigned(FViewFreeListener.ActualView) then
    FViewFreeListener.ActualView.SetupView;
end;

{ TFormViewProxy<TVM>.TViewFreeListener }

constructor TFormViewProxy<TVM>.TViewFreeListener.Create(AView: IViewForm<TVM>);
var
  Instance: TObject;
begin
  inherited Create(nil);
  FActualView := AView;
  Instance    := TObject(AView);
  if (Instance is TComponent) then
  begin
    FActualViewObject := TComponent(Instance);
    FActualViewObject.FreeNotification(Self);
  end;
end;

destructor TFormViewProxy<TVM>.TViewFreeListener.Destroy;
begin
  if (FActualViewObject <> nil) then
    FActualViewObject.RemoveFreeNotification(Self);
  inherited;
end;

procedure TFormViewProxy<TVM>.TViewFreeListener.Notification(
  AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (AComponent = FActualViewObject) and (Operation = opRemove) then
  begin
    FActualView       := nil;
    FActualViewObject := nil;
  end;
end;


class destructor TViewFactory.Destroy;
begin
  FreeAndNil(FRegisteredViews);
end;

class procedure TViewFactory.Register(const AViewClass: TRttiInstanceType; const AViewName: String; const APlatform: String);
var
  LAlias: string;
begin
  if (not Supports(AViewClass.MetaclassType, IView)) then
    raise EInvalidOperation.CreateFmt('View class %s must implement the IView interface', [AViewClass.MetaclassType.QualifiedClassName]);
  if not AViewClass.MetaclassType.InheritsFrom(TComponent) then
    raise EInvalidOperation.CreateFmt('View class %s must inherit from TComponent', [AViewClass.MetaclassType.QualifiedClassName]);
  if AViewName.IsEmpty then
    raise EInvalidOperation.CreateFmt('View class %s must have a ViewName not empty', [AViewClass.MetaclassType.QualifiedClassName]);

  if (FRegisteredViews = nil) then
    FRegisteredViews := TDictionary<String, TRttiInstanceType>.Create(TIStringComparer.Ordinal);

  LALias := Utils.iif<String>(APlatform.IsEmpty, AViewName, APlatform + '.' + AViewName);

  FRegisteredViews.AddOrSetValue(LAlias, AViewClass);
end;

end.
