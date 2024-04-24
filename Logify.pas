unit Logify;

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Generics.Collections, System.SyncObjs;

type
  /// <summary>
  ///   Logging levels
  /// </summary>
  TLogLevel = (Trace, Debug, Info, Warning, Error, Critical);

const
  DEFAULT_CATEGORY = 'default';
  LOG_LEVEL_STR: array[TLogLevel] of string = ('TRACE', 'DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL');

type
  /// <summary>
  ///   Simple Logger Interface
  /// </summary>
  ILogger = interface(IInterface)
  ['{FEC81C15-3142-4ECF-AED5-4E05FB1FB882}']
    // Accessors for the Level property
    function GetLevel: TLogLevel;
    procedure SetLevel(AValue: TLogLevel);
    // Generic Log method
    procedure Log(const AMsg: string; ALevel: TLogLevel);
    // Specific Log* methods with levels
    procedure LogTrace(const AMsg: string);
    procedure LogDebug(const AMsg: string);
    procedure LogInfo(const AMsg: string);
    procedure LogWarning(const AMsg: string);
    procedure LogError(const AMsg: string);
    procedure LogCritical(const AMsg: string);
    procedure LogException(AException: Exception); overload;
    procedure LogException(AException: Exception; const ACustomMessage: string); overload;
    // Log only the message as it is
    procedure LogRawLine(const AMsg: string);
    // Properties
    property Level: TLogLevel read GetLevel write SetLevel;
  end;

  ILoggerFactory = interface(IInterface)
  ['{2D5EE776-AB98-4A1C-88AB-C76339C05D72}']
    function CreateLogger: ILogger;
  end;

  TLoggerHelper = class(TInterfacedObject)
  public const
    LOG_TEMPLATE = '%s|%d|%s|%s';
  protected
    FLevel: TLogLevel;
    function GetLevel: TLogLevel;
    procedure SetLevel(AValue: TLogLevel);

    function FormatLog(const AMsg: string; ALevel: TLogLevel): string;
    procedure InternalLog(const AMsg: string; ALevel: TLogLevel); virtual; abstract;
    procedure InternalRaw(const AMsg: string); virtual; abstract;
  public
    procedure Log(const AMsg: string; ALevel: TLogLevel);
    procedure LogTrace(const AMsg: string);
    procedure LogDebug(const AMsg: string);
    procedure LogInfo(const AMsg: string);
    procedure LogWarning(const AMsg: string);
    procedure LogError(const AMsg: string);
    procedure LogCritical(const AMsg: string);
    procedure LogException(AException: Exception); overload;
    procedure LogException(AException: Exception; const ACustomMessage: string); overload;
    procedure LogRawLine(const AMsg: string);
  public
    property Level: TLogLevel read GetLevel write SetLevel;
  end;


  TLoggerRegistry = class
  private type
    FactoryInfo = record
      Category: string;
      Factory: ILoggerFactory;
      class function New(const ACategory: string; AFactory: ILoggerFactory): FactoryInfo; static;
    end;
    LoggerInfo = record
      Category: string;
      Logger: ILogger;
      class function New(const ACategory: string; ALogger: ILogger): LoggerInfo; static;
    end;
  private class var
    FLock: TCriticalSection;
    FInstance: TLoggerRegistry;
  private
    FLoggers: TDictionary<string, LoggerInfo>;
    FRegistry: TDictionary<string, FactoryInfo>;
    class function GetInstance: TLoggerRegistry; static;
    function GetOrCreateLogger(const AName: string): ILogger;
  public
    class constructor Create;
    class destructor Destroy;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddFactory(AFactory: ILoggerFactory); overload;
    procedure AddFactory(const ACategory: string; AFactory: ILoggerFactory); overload;
    function FindFactory(const AName: string): ILoggerFactory;
    function GetFactory(const AName: string): ILoggerFactory;

    function CreateLogger(AName: string): ILogger;
    function FindLogger(const AName: string): ILogger;
    function GetLoggers(const ACategory: string): TArray<ILogger>;

    class property Instance: TLoggerRegistry read GetInstance;
  end;

  // "default" Category Logger(s)
  function Logger: ILogger;

implementation

uses
  System.Classes, System.DateUtils;

type
  TMultiLogger = class(TInterfacedObject, ILogger)
  private
    FCategory: string;
    FLevel: TLogLevel;
    function GetLevel: TLogLevel;
    procedure SetLevel(AValue: TLogLevel);
  public
    constructor Create(const ACategory: string);

    procedure Log(const AMsg: string; ALevel: TLogLevel); overload;
    procedure LogTrace(const AMsg: string); overload;
    procedure LogDebug(const AMsg: string); overload;
    procedure LogInfo(const AMsg: string); overload;
    procedure LogWarning(const AMsg: string); overload;
    procedure LogError(const AMsg: string); overload;
    procedure LogCritical(const AMsg: string); overload;
    procedure LogException(AException: Exception); overload;
    procedure LogException(AException: Exception; const ACustomMessage: string); overload;
    procedure LogRawLine(const AMsg: string);

    // Properties
    property Level: TLogLevel read GetLevel write SetLevel;
  end;

var
  _Logger: ILogger;
  _Lock: TCriticalSection;

function Logger: ILogger;
begin
  if not Assigned(_Logger) then
  begin
    _Lock.Acquire;
    try
      if not Assigned(_Logger) then
        _Logger := TMultiLogger.Create(DEFAULT_CATEGORY);
    finally
      _Lock.Release;
    end;
  end;
  Result := _Logger;
end;

{ TLoggerRegistry }

class constructor TLoggerRegistry.Create;
begin
  FLock := TCriticalSection.Create;
end;

class destructor TLoggerRegistry.Destroy;
begin
  FLock.Free;
end;

procedure TLoggerRegistry.AddFactory(AFactory: ILoggerFactory);
begin
  AddFactory(DEFAULT_CATEGORY, AFactory);
end;

constructor TLoggerRegistry.Create;
begin
  FRegistry := TDictionary<string, FactoryInfo>.Create;
  FLoggers := TDictionary<string, LoggerInfo>.Create;
end;

destructor TLoggerRegistry.Destroy;
begin
  FLoggers.Free;
  FRegistry.Free;
  inherited;
end;

class function TLoggerRegistry.GetInstance: TLoggerRegistry;
begin
  if not Assigned(FInstance) then
  begin
    FLock.Acquire;
    try
      if not Assigned(FInstance) then
        FInstance := TLoggerRegistry.Create;
    finally
      FLock.Release;
    end;
  end;
  Result := FInstance;
end;

function TLoggerRegistry.FindFactory(const AName: string): ILoggerFactory;
var
  LInfo: FactoryInfo;
begin
  Result := nil;
  if FRegistry.TryGetValue(AName, LInfo) then
    Result := LInfo.Factory;
end;

function TLoggerRegistry.FindLogger(const AName: string): ILogger;
var
  LReg: TPair<string, LoggerInfo>;
begin
  Result := nil;
  for LReg in FLoggers do
   if LReg.Key = AName then
     Result := LReg.Value.Logger;
end;

function TLoggerRegistry.GetLoggers(const ACategory: string): TArray<ILogger>;
var
  LReg: TPair<string, FactoryInfo>;
  LLogger: ILogger;
begin
  Result := [];

  for LReg in FRegistry do
    if LReg.Value.Category = ACategory then
    begin
      LLogger := GetOrCreateLogger(LReg.Key);
      Result := Result + [LLogger];
    end;
end;

function TLoggerRegistry.GetOrCreateLogger(const AName: string): ILogger;
var
  LLoggerInfo: LoggerInfo;
  LFactoryInfo: FactoryInfo;
begin
  if FLoggers.TryGetValue(AName, LLoggerInfo) then
    Exit(LLoggerInfo.Logger);

  if FRegistry.TryGetValue(AName, LFactoryInfo) then
  begin
    Result := LFactoryInfo.Factory.CreateLogger;
    FLoggers.Add(AName, LoggerInfo.New(LFactoryInfo.Category, Result));
  end;
end;

function TLoggerRegistry.GetFactory(const AName: string): ILoggerFactory;
begin
  Result := FindFactory(AName);
  if not Assigned(Result) then
    raise Exception.CreateFmt('LoggerFactory [%s] not found', [AName]);
end;

procedure TLoggerRegistry.AddFactory(const ACategory: string; AFactory: ILoggerFactory);
var
  LFactoryObj: TObject;
begin
  LFactoryObj := (AFactory as TObject);
  FRegistry.Add(LFactoryObj.ClassName, FactoryInfo.New(ACategory, AFactory));
end;

function TLoggerRegistry.CreateLogger(AName: string): ILogger;
var
  LInfo: FactoryInfo;
begin
  Result := nil;
  if FRegistry.TryGetValue(AName, LInfo) then
    Result := LInfo.Factory.CreateLogger;
end;

{ TLoggerRegistry.LoggerInfo }

class function TLoggerRegistry.LoggerInfo.New(const ACategory: string; ALogger: ILogger): LoggerInfo;
begin
  Result.Category := ACategory;
  Result.Logger := ALogger;
end;

{ TLoggerRegistry.FactoryInfo }

class function TLoggerRegistry.FactoryInfo.New(const ACategory: string;
  AFactory: ILoggerFactory): FactoryInfo;
begin
  Result.Category := ACategory;
  Result.Factory := AFactory;
end;

{ TMultiLogger }

constructor TMultiLogger.Create(const ACategory: string);
begin
  FCategory := ACategory;
end;

function TMultiLogger.GetLevel: TLogLevel;
begin
  Result := FLevel;
end;

procedure TMultiLogger.Log(const AMsg: string; ALevel: TLogLevel);
var
  LLogger: ILogger;
begin
  for LLogger in TLoggerRegistry.Instance.GetLoggers(FCategory) do
    LLogger.Log(AMsg, ALevel);
end;

procedure TMultiLogger.LogCritical(const AMsg: string);
begin
  Log(AMsg, TLogLevel.Critical);
end;

procedure TMultiLogger.LogDebug(const AMsg: string);
begin
  Log(AMsg, TLogLevel.Debug);
end;

procedure TMultiLogger.LogError(const AMsg: string);
begin
  Log(AMsg, TLogLevel.Error);
end;

procedure TMultiLogger.LogException(AException: Exception);
begin
  Log(AException.ClassName + '|' + AException.Message, TLogLevel.Error);
end;

procedure TMultiLogger.LogException(AException: Exception; const ACustomMessage: string);
begin
  Log(ACustomMessage + '|' + AException.Message, TLogLevel.Error);
end;

procedure TMultiLogger.LogInfo(const AMsg: string);
begin
  Log(AMsg, TLogLevel.Info);
end;

procedure TMultiLogger.LogRawLine(const AMsg: string);
var
  LLogger: ILogger;
begin
  for LLogger in TLoggerRegistry.Instance.GetLoggers(FCategory) do
    LLogger.LogRawLine(AMsg);
end;

procedure TMultiLogger.LogTrace(const AMsg: string);
begin
  Log(AMsg, TLogLevel.Trace);
end;

procedure TMultiLogger.LogWarning(const AMsg: string);
begin
  Log(AMsg, TLogLevel.Warning);
end;

procedure TMultiLogger.SetLevel(AValue: TLogLevel);
begin
  FLevel := AValue;
end;

{ TLoggerHelper }

function TLoggerHelper.FormatLog(const AMsg: string; ALevel: TLogLevel): string;
begin
  Result := Format(LOG_TEMPLATE, [
      DateToISO8601(Now, False),
      TThread.CurrentThread.ThreadID,
      LOG_LEVEL_STR[ALevel],
      AMsg
    ]);
end;

function TLoggerHelper.GetLevel: TLogLevel;
begin
  Result := FLevel;
end;

procedure TLoggerHelper.Log(const AMsg: string; ALevel: TLogLevel);
begin
  if ALevel < FLevel then
    Exit;

  InternalLog(AMsg, ALevel);
end;

procedure TLoggerHelper.LogCritical(const AMsg: string);
begin
  Log(AMsg, TLogLevel.Critical);
end;

procedure TLoggerHelper.LogDebug(const AMsg: string);
begin
  Log(AMsg, TLogLevel.Debug);
end;

procedure TLoggerHelper.LogError(const AMsg: string);
begin
  Log(AMsg, TLogLevel.Error);
end;

procedure TLoggerHelper.LogException(AException: Exception);
begin
  Log(AException.ClassName + '|' + AException.Message, TLogLevel.Critical);
end;

procedure TLoggerHelper.LogException(AException: Exception; const ACustomMessage: string);
begin
  Log(AException.ClassName + '|' + ACustomMessage, TLogLevel.Critical);
end;

procedure TLoggerHelper.LogInfo(const AMsg: string);
begin
  Log(AMsg, TLogLevel.Info);
end;

procedure TLoggerHelper.LogRawLine(const AMsg: string);
begin
  InternalRaw(AMsg);
end;

procedure TLoggerHelper.LogTrace(const AMsg: string);
begin
  Log(AMsg, TLogLevel.Trace);
end;

procedure TLoggerHelper.LogWarning(const AMsg: string);
begin
  Log(AMsg, TLogLevel.Warning);
end;

procedure TLoggerHelper.SetLevel(AValue: TLogLevel);
begin
  FLevel := AValue;
end;

initialization
  _Lock := TCriticalSection.Create;

finalization
  _Lock.Free;

end.
