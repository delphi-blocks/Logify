{******************************************************************************}
{                                                                              }
{  Logify: Metalogger for Delphi                                               }
{                                                                              }
{  Copyright (c) 2024 WiRL Team                                                }
{  https://github.com/delphi-blocks/Logify                                     }
{                                                                              }
{  Licensed under the MIT license                                              }
{                                                                              }
{******************************************************************************}
unit Logify;

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils, System.Generics.Collections, System.SyncObjs;

type
  ELogifyException = class(Exception);

  /// <summary>
  ///   Logify Logging levels
  /// </summary>
  TLogLevel = (Trace, Debug, Info, Warning, Error, Critical, Off);
  TLogLevelHelper = record helper for TLogLevel
  private const
    LOG_LEVEL_STR: array[TLogLevel] of string =
      ('TRACE', 'DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL', 'OFF');
  public
    function ToString: string;
    procedure FromString(AValue: string);
  end;

  /// <summary>
  ///   Logify Generic Logger Interface
  /// </summary>
  ILogger = interface(IInterface)
  ['{FEC81C15-3142-4ECF-AED5-4E05FB1FB882}']
    // Standard Logging Methods
    procedure Log(const AMsg: string; ALevel: TLogLevel); overload;
    procedure Log(const AMsg: string; const AArgs: array of const; ALevel: TLogLevel); overload;
    procedure Log(AException: Exception; const AMsg: string; ALevel: TLogLevel); overload;

    procedure LogRawLine(const AMsg: string; ALevel: TLogLevel);

    procedure LogTrace(const AMsg: string); overload;
    procedure LogDebug(const AMsg: string); overload;
    procedure LogInfo(const AMsg: string); overload;
    procedure LogWarning(const AMsg: string); overload;
    procedure LogError(const AMsg: string); overload;
    procedure LogCritical(const AMsg: string); overload;

    procedure LogTrace(const AMsg: string; const AArgs: array of const); overload;
    procedure LogDebug(const AMsg: string; const AArgs: array of const); overload;
    procedure LogInfo(const AMsg: string; const AArgs: array of const); overload;
    procedure LogWarning(const AMsg: string; const AArgs: array of const); overload;
    procedure LogError(const AMsg: string; const AArgs: array of const); overload;
    procedure LogCritical(const AMsg: string; const AArgs: array of const); overload;

    procedure LogTrace(AException: Exception; const AMsg: string); overload;
    procedure LogDebug(AException: Exception; const AMsg: string); overload;
    procedure LogInfo(AException: Exception; const AMsg: string); overload;
    procedure LogWarning(AException: Exception; const AMsg: string); overload;
    procedure LogError(AException: Exception; const AMsg: string); overload;
    procedure LogCritical(AException: Exception; const AMsg: string); overload;
  end;

  /// <summary>
  ///   Logger Adapter Interface
  /// </summary>
  ILoggerAdapter = interface(IInterface)
  ['{3593B5F9-EACB-403F-90DA-A63C32AD4E33}']

    /// <summary>
    ///   Main logger function to be implemented.
    /// </summary>
    procedure WriteLog(const AClassName, AMsg: string; AException: Exception; ALevel: TLogLevel);

    /// <summary>
    ///   Alternative logger function intended to write a message without
    ///   formatting (timestamp, level info, thread id, etc...).
    ///
    ///   If your logger doesn't have this feature, implement this function
    ///   as a normal log call.
    /// </summary>
    procedure WriteRawLine(const AMsg: string; ALevel: TLogLevel);
  end;

  /// <summary>
  ///   Adapter Factory Interface
  /// </summary>
  ILoggerAdapterFactory = interface(IInterface)
  ['{2D5EE776-AB98-4A1C-88AB-C76339C05D72}']
    function GetUniqueName: string;
    function CreateLoggerAdapter: ILoggerAdapter;
  end;

  /// <summary>
  ///   Logger Adapter Factory Base (utility) class
  /// </summary>
  TLoggerAdapterFactory = class (TInterfacedObject, ILoggerAdapterFactory)
  protected
    FName: string;
  public
    function GetUniqueName: string; virtual;
    function CreateLoggerAdapter: ILoggerAdapter; virtual; abstract;

    property Name: string read FName write FName;
  end;
  TLoggerAdapterFactoryClass = class of TLoggerAdapterFactory;

  /// <summary>
  ///   Utility class for a logger implementing the ILogger interface.
  ///
  ///   This class is useful only il the final logger lacks formatting
  ///   and LogLevel management.
  ///
  ///   If you are using a full featured Logger it's probably better
  ///   to implement the ILoggerAdapter directly.
  /// </summary>
  TLoggerAdapterHelper = class(TInterfacedObject, ILoggerAdapter)
  public const
    //Date ThreadID [ClassName] Level | Message
    LOG_TEMPLATE = '%s %s [%s] %s | %s';
    LOG_LINE_SEP = '=';
  protected
    FLevel: TLogLevel;
    function FormatMsg(const AMessage, AClassName: string; AException: Exception; ALevel: TLogLevel): string; virtual;
    function FormatHeader(): string; virtual;
    function FormatSeparator(): string; virtual;

    procedure InternalLog(const AMessage, AClassName: string; AException: Exception; ALevel: TLogLevel); virtual; abstract;
    procedure InternalRaw(const AMessage: string; ALevel: TLogLevel); virtual; abstract;
  public
    constructor Create; overload;
    constructor Create(ALevel: TLogLevel); overload;

    // ILoggerAdapter functions
    procedure WriteLog(const AClassName, AMessage: string; AException: Exception; ALevel: TLogLevel);
    procedure WriteRawLine(const AMessage: string; ALevel: TLogLevel);

    property Level: TLogLevel read FLevel write FLevel;
  end;

  /// <summary>
  ///   Main registry for the Factory classes and created Logger Adapters (cache)
  /// </summary>
  TLoggerAdapterRegistry = class
  private type
    FactoryInfo = record
      Category: string;
      Factory: ILoggerAdapterFactory;
      class function New(const ACategory: string; AFactory: ILoggerAdapterFactory): FactoryInfo; static;
    end;
    LoggerAdapterInfo = record
      Category: string;
      LoggerAdapter: ILoggerAdapter;
      class function New(const ACategory: string; ALoggerAdapter: ILoggerAdapter): LoggerAdapterInfo; static;
    end;
  private class var
    FInstance: TLoggerAdapterRegistry;
  private
    FLoggerAdapters: TDictionary<string, LoggerAdapterInfo>;
    FRegistry: TDictionary<string, FactoryInfo>;
    class function GetInstance: TLoggerAdapterRegistry; static;
    function GetOrCreateLoggerAdapter(const AName: string): ILoggerAdapter;
  public
    class constructor Create;
    class destructor Destroy;
  public
    constructor Create;
    destructor Destroy; override;

    procedure RegisterFactoryClass(AFactoryClass: TLoggerAdapterFactoryClass); overload;
    procedure RegisterFactoryClass(const ACategory: string; AFactoryClass: TLoggerAdapterFactoryClass); overload;

    procedure RegisterFactory(AFactory: ILoggerAdapterFactory); overload;
    procedure RegisterFactory(const ACategory: string; AFactory: ILoggerAdapterFactory); overload;

    function FindFactory(const AName: string): ILoggerAdapterFactory;
    function GetFactory(const AName: string): ILoggerAdapterFactory;

    function CreateLoggerAdapter(AName: string): ILoggerAdapter;
    function FindLoggerAdapter(const AName: string): ILoggerAdapter;
    function GetLoggerAdapters(const ACategory: string): TArray<ILoggerAdapter>;

    class property Instance: TLoggerAdapterRegistry read GetInstance;
  end;

  /// <summary>
  ///   Manager static class to get ILogger and ILogger<T> ready to use
  /// </summary>
  TLoggerManager = class
  public
    class function GetLogger<T:class>(): ILogger; overload; static;
    class function GetLogger(AClass: TClass): ILogger; overload; static;
    class function GetLogger(const AClassName: string): ILogger; overload; static;
  end;

const
  DEFAULT_CATEGORY = 'default';

  /// <summary>
  ///   Ready to use Logger for the "default" category
  /// </summary>
  function Logger: ILogger;

implementation

uses
  System.TypInfo, System.Classes, System.DateUtils, System.Rtti;

type
  /// <summary>
  ///   Default implementation for the ILogger interface.
  ///   TMultiLogger allows you to log on different loggers
  ///   depending on the registered adapter factories.
  /// </summary>
  TMultiLogger = class(TInterfacedObject, ILogger)
  private
    FClassName: string;
    FCategory: string;
    FRegistry: TLoggerAdapterRegistry;
  public
    constructor Create(const AClassName, ACategory: string; ARegistry: TLoggerAdapterRegistry = nil);

    procedure Log(const AMsg: string; ALevel: TLogLevel); overload;
    procedure Log(const AMsg: string; const AArgs: array of const; ALevel: TLogLevel); overload;
    procedure Log(AException: Exception; const AMsg: string; ALevel: TLogLevel); overload;

    procedure LogRawLine(const AMsg: string; ALevel: TLogLevel);

    procedure LogTrace(const AMsg: string); overload;
    procedure LogDebug(const AMsg: string); overload;
    procedure LogInfo(const AMsg: string); overload;
    procedure LogWarning(const AMsg: string); overload;
    procedure LogError(const AMsg: string); overload;
    procedure LogCritical(const AMsg: string); overload;

    procedure LogTrace(const AMsg: string; const AArgs: array of const); overload;
    procedure LogDebug(const AMsg: string; const AArgs: array of const); overload;
    procedure LogInfo(const AMsg: string; const AArgs: array of const); overload;
    procedure LogWarning(const AMsg: string; const AArgs: array of const); overload;
    procedure LogError(const AMsg: string; const AArgs: array of const); overload;
    procedure LogCritical(const AMsg: string; const AArgs: array of const); overload;

    procedure LogTrace(AException: Exception; const AMsg: string); overload;
    procedure LogDebug(AException: Exception; const AMsg: string); overload;
    procedure LogInfo(AException: Exception; const AMsg: string); overload;
    procedure LogWarning(AException: Exception; const AMsg: string); overload;
    procedure LogError(AException: Exception; const AMsg: string); overload;
    procedure LogCritical(AException: Exception; const AMsg: string); overload;
  end;

var
  _Logger: ILogger;
  _Lock: TCriticalSection;
  _RegistryLock: TCriticalSection;

function Logger: ILogger;
begin
  if not Assigned(_Logger) then
  begin
    _Lock.Acquire;
    try
      if not Assigned(_Logger) then
        _Logger := TMultiLogger.Create('', DEFAULT_CATEGORY);
    finally
      _Lock.Release;
    end;
  end;
  Result := _Logger;
end;

{ TLoggerAdapterRegistry }

class constructor TLoggerAdapterRegistry.Create;
begin

end;

class destructor TLoggerAdapterRegistry.Destroy;
begin
  FreeAndNil(FInstance);
end;

constructor TLoggerAdapterRegistry.Create;
begin
  FRegistry := TDictionary<string, FactoryInfo>.Create;
  FLoggerAdapters := TDictionary<string, LoggerAdapterInfo>.Create;
end;

destructor TLoggerAdapterRegistry.Destroy;
begin
  FLoggerAdapters.Free;
  FRegistry.Free;
  inherited;
end;

class function TLoggerAdapterRegistry.GetInstance: TLoggerAdapterRegistry;
begin
  if not Assigned(FInstance) then
  begin
    _RegistryLock.Acquire;
    try
      if not Assigned(FInstance) then
        FInstance := TLoggerAdapterRegistry.Create;
    finally
      _RegistryLock.Release;
    end;
  end;
  Result := FInstance;
end;

function TLoggerAdapterRegistry.GetFactory(const AName: string): ILoggerAdapterFactory;
begin
  Result := FindFactory(AName);
  if not Assigned(Result) then
    raise ELogifyException.CreateFmt('LoggerFactory [%s] not found', [AName]);
end;

function TLoggerAdapterRegistry.FindFactory(const AName: string): ILoggerAdapterFactory;
var
  LInfo: FactoryInfo;
begin
  Result := nil;
  if FRegistry.TryGetValue(AName, LInfo) then
    Result := LInfo.Factory;
end;

function TLoggerAdapterRegistry.FindLoggerAdapter(const AName: string): ILoggerAdapter;
var
  LReg: TPair<string, LoggerAdapterInfo>;
begin
  Result := nil;
  for LReg in FLoggerAdapters do
   if LReg.Key = AName then
     Result := LReg.Value.LoggerAdapter;
end;

function TLoggerAdapterRegistry.GetLoggerAdapters(const ACategory: string): TArray<ILoggerAdapter>;
var
  LReg: TPair<string, FactoryInfo>;
  LLogger: ILoggerAdapter;
begin
  Result := [];

  for LReg in FRegistry do
    if LReg.Value.Category = ACategory then
    begin
      LLogger := GetOrCreateLoggerAdapter(LReg.Key);
      Result := Result + [LLogger];
    end;
end;

function TLoggerAdapterRegistry.GetOrCreateLoggerAdapter(const AName: string): ILoggerAdapter;
var
  LLoggerAdapterInfo: LoggerAdapterInfo;
  LFactoryInfo: FactoryInfo;
begin
  if FLoggerAdapters.TryGetValue(AName, LLoggerAdapterInfo) then
    Exit(LLoggerAdapterInfo.LoggerAdapter);

  if FRegistry.TryGetValue(AName, LFactoryInfo) then
  begin
    Result := LFactoryInfo.Factory.CreateLoggerAdapter;
    FLoggerAdapters.Add(AName, LoggerAdapterInfo.New(LFactoryInfo.Category, Result));
  end;
end;

procedure TLoggerAdapterRegistry.RegisterFactoryClass(const ACategory: string; AFactoryClass: TLoggerAdapterFactoryClass);
begin
  RegisterFactory(ACategory, AFactoryClass.Create);
end;

procedure TLoggerAdapterRegistry.RegisterFactoryClass(AFactoryClass: TLoggerAdapterFactoryClass);
begin
  RegisterFactory(DEFAULT_CATEGORY, AFactoryClass.Create);
end;

procedure TLoggerAdapterRegistry.RegisterFactory(AFactory: ILoggerAdapterFactory);
begin
  RegisterFactory(DEFAULT_CATEGORY, AFactory);
end;

procedure TLoggerAdapterRegistry.RegisterFactory(const ACategory: string; AFactory: ILoggerAdapterFactory);
begin
  FRegistry.Add(AFactory.GetUniqueName, FactoryInfo.New(ACategory, AFactory));
end;

function TLoggerAdapterRegistry.CreateLoggerAdapter(AName: string): ILoggerAdapter;
var
  LInfo: FactoryInfo;
begin
  Result := nil;
  if FRegistry.TryGetValue(AName, LInfo) then
    Result := LInfo.Factory.CreateLoggerAdapter;
end;

{ TLoggerAdapterRegistry.LoggerAdapterInfo }

class function TLoggerAdapterRegistry.LoggerAdapterInfo.New(const ACategory: string; ALoggerAdapter: ILoggerAdapter): LoggerAdapterInfo;
begin
  Result.Category := ACategory;
  Result.LoggerAdapter := ALoggerAdapter;
end;

{ TLoggerAdapterRegistry.FactoryInfo }

class function TLoggerAdapterRegistry.FactoryInfo.New(const ACategory: string; AFactory: ILoggerAdapterFactory): FactoryInfo;
begin
  Result.Category := ACategory;
  Result.Factory := AFactory;
end;

{ TMultiLogger }

constructor TMultiLogger.Create(const AClassName, ACategory: string; ARegistry: TLoggerAdapterRegistry);
begin
  FClassName := AClassName;
  FCategory := ACategory;
  if Assigned(ARegistry) then
    FRegistry := ARegistry
  else
    FRegistry := TLoggerAdapterRegistry.Instance;
end;

procedure TMultiLogger.LogCritical(const AMsg: string);
begin
  Log(nil, AMsg, TLogLevel.Critical);
end;

procedure TMultiLogger.LogDebug(const AMsg: string);
begin
  Log(nil, AMsg, TLogLevel.Debug);
end;

procedure TMultiLogger.LogError(const AMsg: string);
begin
  Log(nil, AMsg, TLogLevel.Error);
end;

procedure TMultiLogger.LogInfo(AException: Exception; const AMsg: string);
begin
  Log(AException, AMsg, TLogLevel.Info);
end;

procedure TMultiLogger.LogInfo(const AMsg: string);
begin
  Log(nil, AMsg, TLogLevel.Info);
end;

procedure TMultiLogger.LogTrace(AException: Exception; const AMsg: string);
begin
  Log(AException, AMsg, TLogLevel.Trace);
end;

procedure TMultiLogger.LogTrace(const AMsg: string; const AArgs: array of const);
begin
  Log(nil, Format(AMsg, AArgs), TLogLevel.Trace);
end;

procedure TMultiLogger.LogWarning(const AMsg: string; const AArgs: array of const);
begin
  Log(nil, Format(AMsg, AArgs), TLogLevel.Warning);
end;

procedure TMultiLogger.LogTrace(const AMsg: string);
begin
  Log(nil, AMsg, TLogLevel.Trace);
end;

procedure TMultiLogger.LogWarning(const AMsg: string);
begin
  Log(nil, AMsg, TLogLevel.Warning);
end;

procedure TMultiLogger.LogRawLine(const AMsg: string; ALevel: TLogLevel);
var
  LLoggerAdapter: ILoggerAdapter;
begin
  for LLoggerAdapter in FRegistry.GetLoggerAdapters(FCategory) do
    LLoggerAdapter.WriteRawLine(AMsg, ALevel);
end;

procedure TMultiLogger.Log(AException: Exception; const AMsg: string; ALevel: TLogLevel);
var
  LLoggerAdapter: ILoggerAdapter;
begin
  for LLoggerAdapter in FRegistry.GetLoggerAdapters(FCategory) do
    LLoggerAdapter.WriteLog(FClassName, AMsg, AException, ALevel);
end;

procedure TMultiLogger.Log(const AMsg: string; ALevel: TLogLevel);
begin
  Log(nil, AMsg, ALevel);
end;

procedure TMultiLogger.Log(const AMsg: string; const AArgs: array of const; ALevel: TLogLevel);
begin
  Log(nil, Format(AMsg, AArgs), ALevel);
end;

procedure TMultiLogger.LogCritical(AException: Exception; const AMsg: string);
begin
  Log(AException, AMsg, TLogLevel.Critical);
end;

procedure TMultiLogger.LogCritical(const AMsg: string; const AArgs: array of const);
begin
  Log(nil, Format(AMsg, AArgs), TLogLevel.Critical);
end;

procedure TMultiLogger.LogDebug(const AMsg: string; const AArgs: array of const);
begin
  Log(nil, Format(AMsg, AArgs), TLogLevel.Debug);
end;

procedure TMultiLogger.LogDebug(AException: Exception; const AMsg: string);
begin
  Log(AException, AMsg, TLogLevel.Debug);
end;

procedure TMultiLogger.LogError(const AMsg: string; const AArgs: array of const);
begin
  Log(nil, Format(AMsg, AArgs), TLogLevel.Error);
end;

procedure TMultiLogger.LogError(AException: Exception; const AMsg: string);
begin
  Log(AException, AMsg, TLogLevel.Error);
end;

procedure TMultiLogger.LogInfo(const AMsg: string; const AArgs: array of const);
begin
  Log(nil, Format(AMsg, AArgs), TLogLevel.Info);
end;

procedure TMultiLogger.LogWarning(AException: Exception; const AMsg: string);
begin
  Log(AException, AMsg, TLogLevel.Warning);
end;

{ TLoggerAdapterHelper }

constructor TLoggerAdapterHelper.Create;
begin
  FLevel := TLogLevel.Info;
end;

constructor TLoggerAdapterHelper.Create(ALevel: TLogLevel);
begin
  FLevel := ALevel;
end;

function TLoggerAdapterHelper.FormatHeader: string;
begin
  Result := Format(LOG_TEMPLATE, [
      'DATE',
      'THREAD',
      'LEVEL',
      'CLASS',
      'MESSAGE'
    ]);
end;

function TLoggerAdapterHelper.FormatMsg(const AMessage, AClassName: string; AException: Exception; ALevel: TLogLevel): string;
const
  LOG_STD = '%s' + sLineBreak + '%s : %s';
  LOG_STACK = LOG_STD + sLineBreak + '%s';
var
  LStackTrace: string;
  LMsg: string;
  LClassName: string;
  LIndex: Integer;
begin
  if AException <> nil then
  begin
    LStackTrace := AException.StackTrace;
    if LStackTrace <> '' then
      LMsg := Format(LOG_STACK, [
        AMessage,
        AException.ClassName(),
        AException.ToString(),
        LStackTrace
      ])
    else
      LMsg := Format(LOG_STD, [
        AMessage,
        AException.ClassName,
        AException.ToString
      ]);
  end
  else
    LMsg := AMessage;

  if AClassName = '' then
    Result := Format(LOG_TEMPLATE, [
      DateToISO8601(Now, False),
      TThread.CurrentThread.ThreadID.ToString,
      'default',
      ALevel.ToString,
      LMsg
    ])
  else
  begin
    LIndex := AClassName.LastIndexOf('.');
    if LIndex >= 0 then
      LClassName := AClassName.Substring(LIndex + 1)
    else
      LClassName := AClassName;

    Result := Format(LOG_TEMPLATE, [
      DateToISO8601(Now, False),
      TThread.CurrentThread.ThreadID.ToString,
      LClassName,
      ALevel.ToString,
      LMsg
    ]);
  end;
end;

function TLoggerAdapterHelper.FormatSeparator: string;
begin
  Result := StringOfChar(LOG_LINE_SEP, 60);
end;

procedure TLoggerAdapterHelper.WriteLog(const AClassName, AMessage: string; AException: Exception; ALevel: TLogLevel);
begin
  if ALevel = TLogLevel.Off then
    Exit;
  if ALevel < FLevel then
    Exit;
  InternalLog(AMessage, AClassName, AException, ALevel);
end;

procedure TLoggerAdapterHelper.WriteRawLine(const AMessage: string; ALevel: TLogLevel);
begin
  if ALevel = TLogLevel.Off then
    Exit;
  if ALevel < FLevel then
    Exit;
  InternalRaw(AMessage, ALevel);
end;

{ TLoggerAdapterFactory }

function TLoggerAdapterFactory.GetUniqueName: string;
begin
  if FName.IsEmpty then
    Result := Self.ClassName
  else
    Result := FName;
end;

{ TLogLevelHelper }

procedure TLogLevelHelper.FromString(AValue: string);
begin
  Self := TLogLevel(GetEnumValue(TypeInfo(TLogLevel), AValue));
end;

function TLogLevelHelper.ToString: string;
begin
  Result := LOG_LEVEL_STR[Self];
end;

{ TLoggerManager }

class function TLoggerManager.GetLogger(const AClassName: string): ILogger;
begin
  Result := TMultiLogger.Create(AClassName, DEFAULT_CATEGORY);
end;

class function TLoggerManager.GetLogger(AClass: TClass): ILogger;
begin
  Result := TMultiLogger.Create(AClass.QualifiedClassName(), DEFAULT_CATEGORY);
end;

class function TLoggerManager.GetLogger<T>: ILogger;
begin
  Result := GetLogger(PTypeInfo(TypeInfo(T)).TypeData.ClassType.QualifiedClassName());
end;

initialization
  _Lock := TCriticalSection.Create;
  _RegistryLock := TCriticalSection.Create;

finalization
  FreeAndNil(_Lock);
  FreeAndNil(_RegistryLock);

end.
