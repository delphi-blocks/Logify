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
    /// <summary>
    ///   Guards every dictionary below. Recursive (a Windows critical
    ///   section), so the internal helpers may be reached from an already
    ///   locked public method on the same thread.
    /// </summary>
    FLock: TCriticalSection;
    FLoggerAdapters: TDictionary<string, LoggerAdapterInfo>;
    FRegistry: TDictionary<string, FactoryInfo>;

    /// <summary>
    ///   Adapters of a category, resolved once. Logging hits this on every
    ///   single call, so it must not rescan the whole factory dictionary.
    ///   Dropped whenever the registry changes.
    /// </summary>
    FCategoryCache: TDictionary<string, TArray<ILoggerAdapter>>;
    class function GetInstance: TLoggerAdapterRegistry; static;

    // The callers of these two must already hold FLock
    function GetOrCreateLoggerAdapter(const AName: string): ILoggerAdapter;
    procedure InternalUnregisterFactory(const AName: string);
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

    /// <summary>
    ///   Removes a factory, together with the adapter cached for it, so the
    ///   same unique name can be registered again. Unknown names are ignored,
    ///   which makes it safe to call from cleanup code.
    /// </summary>
    procedure UnregisterFactory(const AName: string); overload;
    procedure UnregisterFactory(AFactory: ILoggerAdapterFactory); overload;

    /// <summary>
    ///   Removes every factory (and cached adapter) of a category, leaving the
    ///   other categories untouched.
    /// </summary>
    procedure UnregisterCategory(const ACategory: string);

    /// <summary>
    ///   Empties the registry: no factory, no cached adapter. Logging goes
    ///   back to doing nothing at all.
    /// </summary>
    procedure Clear;

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
    /// <summary>
    ///   Loggers for the "default" category
    /// </summary>
    class function GetLogger<T:class>(): ILogger; overload; static;
    class function GetLogger(AClass: TClass): ILogger; overload; static;
    class function GetLogger(const AClassName: string): ILogger; overload; static;

    /// <summary>
    ///   Loggers for any other category: they reach only the adapters whose
    ///   factory was registered under the same category name.
    ///
    ///   The category comes first so it cannot be confused with the class
    ///   name in the two-string overload.
    /// </summary>
    class function GetCategoryLogger(const ACategory: string): ILogger; overload; static;
    class function GetCategoryLogger(const ACategory: string; AClass: TClass): ILogger; overload; static;
    class function GetCategoryLogger(const ACategory, AClassName: string): ILogger; overload; static;
    class function GetCategoryLogger<T:class>(const ACategory: string): ILogger; overload; static;
  end;

const
  DEFAULT_CATEGORY = 'default';

  /// <summary>
  ///   Ready to use Logger for the "default" category
  /// </summary>
  function Logger: ILogger;

  /// <summary>
  ///   Full text of an exception: class, message, stack trace and the whole
  ///   InnerException chain.
  ///
  ///   Exposed for the adapters that implement ILoggerAdapter directly and so
  ///   do not inherit TLoggerAdapterHelper.FormatMsg. A nil exception yields
  ///   an empty string.
  /// </summary>
  function GetFullExceptionInfo(E: Exception): string;

implementation

uses
  System.TypInfo, System.Classes, System.DateUtils, System.Rtti;

resourcestring
  SLoggerFactoryNotFound = 'LoggerFactory [%s] not found';
  SCausedBy = '--- Caused by %s: %s';

function GetFullExceptionInfo(E: Exception): string;
const
  // Guards against a self-referential or circular InnerException chain
  MAX_INNER_DEPTH = 16;
begin
  var LSB := TStringBuilder.Create;
  try
    var LCurrent := E;
    var LFirst := True;
    var LDepth := 0;
    while (LCurrent <> nil) and (LDepth < MAX_INNER_DEPTH) do
    begin
      if LFirst then
      begin
        LSB.AppendLine(LCurrent.ClassName + ': ' + LCurrent.ToString());
        LFirst := False;
      end
      else
        LSB.AppendLine(Format(SCausedBy, [LCurrent.ClassName, LCurrent.ToString()]));

      // .StackTrace requires a provider (JCL, MadExcept, etc.)
      // If no provider is installed, this remains empty.
      if LCurrent.StackTrace <> '' then
        LSB.AppendLine(LCurrent.StackTrace);

      if LCurrent.InnerException = LCurrent then
        Break;

      LCurrent := LCurrent.InnerException;
      Inc(LDepth);
    end;
    Result := LSB.ToString.TrimRight;
  finally
    LSB.Free;
  end;
end;

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

  /// <summary>
  ///   Set at the beginning of the unit finalization. Once the library is
  ///   shutting down, logging becomes a no-op: the registry is never
  ///   resurrected and no adapter is touched.
  /// </summary>
  _Shutdown: Boolean;

function Logger: ILogger;
var
  LNew: ILogger;
begin
  // Built on first use, never in the initialization section: inside a DLL, an
  // OCX or a runtime package the creation order of the units is not ours to
  // control, so the logger has to be able to appear at any moment.

  if _Shutdown then
    // Past finalization: hand out an inert logger owned by the caller, rather
    // than publishing a new global one that nothing would ever release.
    Exit(TMultiLogger.Create('', DEFAULT_CATEGORY));

  Result := _Logger;
  if Assigned(Result) then
    Exit;

  LNew := TMultiLogger.Create('', DEFAULT_CATEGORY);
  if TInterlocked.CompareExchange(Pointer(_Logger), Pointer(LNew), nil) = nil then
    // We won the race: the reference counted by LNew now belongs to _Logger,
    // so let the local one go without releasing it. Whoever loses simply lets
    // LNew fall out of scope, which frees the loser's instance.
    Pointer(LNew) := nil;

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
  FLock := TCriticalSection.Create;
  FRegistry := TDictionary<string, FactoryInfo>.Create;
  FLoggerAdapters := TDictionary<string, LoggerAdapterInfo>.Create;
  FCategoryCache := TDictionary<string, TArray<ILoggerAdapter>>.Create;
end;

destructor TLoggerAdapterRegistry.Destroy;
begin
  FCategoryCache.Free;
  FLoggerAdapters.Free;
  FRegistry.Free;
  FLock.Free;
  inherited;
end;

class function TLoggerAdapterRegistry.GetInstance: TLoggerAdapterRegistry;
var
  LNew: TLoggerAdapterRegistry;
begin
  // Once finalization has started the registry is gone for good: resurrecting
  // it would only leak an empty one and silently swallow the log line.
  if _Shutdown then
    Exit(nil);

  Result := FInstance;
  if Assigned(Result) then
    Exit;

  // Lock-free lazy creation: whoever loses the race discards its own instance.
  LNew := TLoggerAdapterRegistry.Create;
  Result := TInterlocked.CompareExchange<TLoggerAdapterRegistry>(FInstance, LNew, nil);
  if Result = nil then
    Result := LNew
  else
    LNew.Free;
end;

function TLoggerAdapterRegistry.GetFactory(const AName: string): ILoggerAdapterFactory;
begin
  Result := FindFactory(AName);
  if not Assigned(Result) then
    raise ELogifyException.CreateFmt(SLoggerFactoryNotFound, [AName]);
end;

function TLoggerAdapterRegistry.FindFactory(const AName: string): ILoggerAdapterFactory;
var
  LInfo: FactoryInfo;
begin
  Result := nil;
  FLock.Acquire;
  try
    if FRegistry.TryGetValue(AName, LInfo) then
      Result := LInfo.Factory;
  finally
    FLock.Release;
  end;
end;

function TLoggerAdapterRegistry.FindLoggerAdapter(const AName: string): ILoggerAdapter;
var
  LInfo: LoggerAdapterInfo;
begin
  Result := nil;
  FLock.Acquire;
  try
    if FLoggerAdapters.TryGetValue(AName, LInfo) then
      Result := LInfo.LoggerAdapter;
  finally
    FLock.Release;
  end;
end;

function TLoggerAdapterRegistry.GetLoggerAdapters(const ACategory: string): TArray<ILoggerAdapter>;
var
  LReg: TPair<string, FactoryInfo>;
begin
  FLock.Acquire;
  try
    if FCategoryCache.TryGetValue(ACategory, Result) then
      Exit;

    Result := [];
    for LReg in FRegistry do
      if LReg.Value.Category = ACategory then
        Result := Result + [GetOrCreateLoggerAdapter(LReg.Key)];

    // An empty category is cached too: "nothing registered" is the hot path
    FCategoryCache.Add(ACategory, Result);
  finally
    FLock.Release;
  end;
  // The array is refcounted, so the caller can iterate it outside the lock
  // even if another thread invalidates the cache in the meantime.
end;

function TLoggerAdapterRegistry.GetOrCreateLoggerAdapter(const AName: string): ILoggerAdapter;
var
  LLoggerAdapterInfo: LoggerAdapterInfo;
  LFactoryInfo: FactoryInfo;
begin
  Result := nil;
  if FLoggerAdapters.TryGetValue(AName, LLoggerAdapterInfo) then
    Exit(LLoggerAdapterInfo.LoggerAdapter);

  if FRegistry.TryGetValue(AName, LFactoryInfo) then
  begin
    // Built while holding the lock: an adapter must never be created twice,
    // and some of them (files) own threads and handles.
    Result := LFactoryInfo.Factory.CreateLoggerAdapter;
    FLoggerAdapters.Add(AName, LoggerAdapterInfo.New(LFactoryInfo.Category, Result));
  end;
end;

procedure TLoggerAdapterRegistry.InternalUnregisterFactory(const AName: string);
begin
  // The cached adapter has to go as well: re-registering the same name must
  // not resurrect the adapter built by the previous factory.
  FLoggerAdapters.Remove(AName);
  FRegistry.Remove(AName);
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
  FLock.Acquire;
  try
    FRegistry.Add(AFactory.GetUniqueName, FactoryInfo.New(ACategory, AFactory));
    FCategoryCache.Clear;
  finally
    FLock.Release;
  end;
end;

procedure TLoggerAdapterRegistry.UnregisterFactory(const AName: string);
begin
  FLock.Acquire;
  try
    InternalUnregisterFactory(AName);
    FCategoryCache.Clear;
  finally
    FLock.Release;
  end;
end;

procedure TLoggerAdapterRegistry.UnregisterFactory(AFactory: ILoggerAdapterFactory);
begin
  if Assigned(AFactory) then
    UnregisterFactory(AFactory.GetUniqueName);
end;

procedure TLoggerAdapterRegistry.UnregisterCategory(const ACategory: string);
var
  LReg: TPair<string, FactoryInfo>;
  LNames: TArray<string>;
  LName: string;
begin
  FLock.Acquire;
  try
    // Collected first: the dictionary cannot be modified while enumerating it
    LNames := [];
    for LReg in FRegistry do
      if LReg.Value.Category = ACategory then
        LNames := LNames + [LReg.Key];

    for LName in LNames do
      InternalUnregisterFactory(LName);

    FCategoryCache.Clear;
  finally
    FLock.Release;
  end;
end;

procedure TLoggerAdapterRegistry.Clear;
begin
  FLock.Acquire;
  try
    FCategoryCache.Clear;
    FLoggerAdapters.Clear;
    FRegistry.Clear;
  finally
    FLock.Release;
  end;
end;

function TLoggerAdapterRegistry.CreateLoggerAdapter(AName: string): ILoggerAdapter;
var
  LInfo: FactoryInfo;
begin
  Result := nil;
  FLock.Acquire;
  try
    if FRegistry.TryGetValue(AName, LInfo) then
      Result := LInfo.Factory.CreateLoggerAdapter;
  finally
    FLock.Release;
  end;
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
  if _Shutdown or not Assigned(FRegistry) then
    Exit;

  for LLoggerAdapter in FRegistry.GetLoggerAdapters(FCategory) do
    LLoggerAdapter.WriteRawLine(AMsg, ALevel);
end;

procedure TMultiLogger.Log(AException: Exception; const AMsg: string; ALevel: TLogLevel);
var
  LLoggerAdapter: ILoggerAdapter;
begin
  if _Shutdown or not Assigned(FRegistry) then
    Exit;

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
var
  LMsg: string;
  LClassName: string;
  LIndex: Integer;
begin
  if AException <> nil then
    // Walks the whole InnerException chain, stack traces included
    LMsg := AMessage + sLineBreak + GetFullExceptionInfo(AException)
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

class function TLoggerManager.GetCategoryLogger(const ACategory: string): ILogger;
begin
  Result := TMultiLogger.Create('', ACategory);
end;

class function TLoggerManager.GetCategoryLogger(const ACategory: string; AClass: TClass): ILogger;
begin
  Result := TMultiLogger.Create(AClass.QualifiedClassName(), ACategory);
end;

class function TLoggerManager.GetCategoryLogger(const ACategory, AClassName: string): ILogger;
begin
  Result := TMultiLogger.Create(AClassName, ACategory);
end;

class function TLoggerManager.GetCategoryLogger<T>(const ACategory: string): ILogger;
begin
  Result := GetCategoryLogger(ACategory, PTypeInfo(TypeInfo(T)).TypeData.ClassType.QualifiedClassName());
end;

initialization
  // Deliberately empty: everything here is created on first use, so the unit
  // imposes no initialization order on its host (DLL, OCX, runtime package).

finalization
  // Must come first: background threads still calling Logger while the process
  // shuts down have to find the library already disarmed.
  _Shutdown := True;

end.
