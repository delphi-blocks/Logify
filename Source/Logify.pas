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

    /// <summary>
    ///   Parses a level name (case insensitive), raising ELogifyException when
    ///   the value is not one of them. Use TryFromString to parse a value that
    ///   comes from a configuration file or from the command line.
    /// </summary>
    procedure FromString(const AValue: string);

    /// <summary>
    ///   Parses a level name (case insensitive). Leaves the level untouched
    ///   and returns False when the value is not a valid level name.
    /// </summary>
    function TryFromString(const AValue: string): Boolean;
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

    /// <summary>
    ///   One gate object per adapter name, used to serialize the creation of
    ///   that single adapter while FLock is *not* held. Gates outlive the
    ///   adapters they guard (a thread may still be waiting on one), so they
    ///   are only freed with the registry.
    /// </summary>
    FCreationGates: TObjectDictionary<string, TObject>;

    /// <summary>
    ///   Bumped by every change to the registry. An adapter list built outside
    ///   FLock is only worth caching if the registry did not move meanwhile.
    /// </summary>
    FVersion: Integer;
    class function GetInstance: TLoggerAdapterRegistry; static;

    // Must be called while holding FLock
    procedure InvalidateCache;
    procedure InternalUnregisterFactory(const AName: string);

    // Must be called *without* holding FLock: it takes it as needed and
    // leaves it while the adapter is being built
    function GetOrCreateLoggerAdapter(const AName: string): ILoggerAdapter;
    function AcquireCreationGate(const AName: string): TObject;
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
  SLoggerFactoryDuplicate = 'LoggerFactory [%s] is already registered (in category [%s]): ' +
    'every factory needs a unique name';
  SLogLevelNotValid = '[%s] is not a valid log level';
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
  FCreationGates := TObjectDictionary<string, TObject>.Create([doOwnsValues]);
end;

destructor TLoggerAdapterRegistry.Destroy;
begin
  FCreationGates.Free;
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
  LNames: TArray<string>;
  LAdapter: ILoggerAdapter;
  LVersion, LCount, LIndex: Integer;
begin
  FLock.Acquire;
  try
    if FCategoryCache.TryGetValue(ACategory, Result) then
      Exit;

    // Only the names are collected under the lock: building the adapters is what may take a while
    LVersion := FVersion;
    SetLength(LNames, FRegistry.Count);
    LCount := 0;
    for LReg in FRegistry do
      if LReg.Value.Category = ACategory then
      begin
        LNames[LCount] := LReg.Key;
        Inc(LCount);
      end;
    SetLength(LNames, LCount);
  finally
    FLock.Release;
  end;

  // Adapters are created outside FLock: some of them (files) start a thread
  // and wait for it, and a slow disk must not stall every logging thread in
  // the process. GetOrCreateLoggerAdapter still guarantees a single instance.
  SetLength(Result, Length(LNames));
  LCount := 0;
  for LIndex := 0 to High(LNames) do
  begin
    LAdapter := GetOrCreateLoggerAdapter(LNames[LIndex]);
    // nil when the factory was unregistered while we were building the list
    if Assigned(LAdapter) then
    begin
      Result[LCount] := LAdapter;
      Inc(LCount);
    end;
  end;
  SetLength(Result, LCount);

  FLock.Acquire;
  try
    // An empty category is cached too: "nothing registered" is the hot path.
    // A registry that changed while we were building leaves the list uncached
    // (it may already be stale): the next call rebuilds it.
    if LVersion = FVersion then
      FCategoryCache.AddOrSetValue(ACategory, Result);
  finally
    FLock.Release;
  end;
  // The array is refcounted, so the caller can iterate it outside the lock
  // even if another thread invalidates the cache in the meantime.
end;

function TLoggerAdapterRegistry.AcquireCreationGate(const AName: string): TObject;
begin
  FLock.Acquire;
  try
    if not FCreationGates.TryGetValue(AName, Result) then
    begin
      Result := TObject.Create;
      FCreationGates.Add(AName, Result);
    end;
  finally
    FLock.Release;
  end;
end;

function TLoggerAdapterRegistry.GetOrCreateLoggerAdapter(const AName: string): ILoggerAdapter;
var
  LLoggerAdapterInfo: LoggerAdapterInfo;
  LFactoryInfo, LCurrentInfo: FactoryInfo;
  LGate: TObject;
begin
  Result := nil;

  FLock.Acquire;
  try
    if FLoggerAdapters.TryGetValue(AName, LLoggerAdapterInfo) then
      Exit(LLoggerAdapterInfo.LoggerAdapter);
    if not FRegistry.ContainsKey(AName) then
      Exit(nil);
  finally
    FLock.Release;
  end;

  // Everything below runs without FLock, so only the threads racing for this
  // very adapter wait here: an adapter must never be created twice, and some
  // of them (files) own threads and handles.
  LGate := AcquireCreationGate(AName);
  TMonitor.Enter(LGate);
  try
    FLock.Acquire;
    try
      // The winner of the race got here first and already published it
      if FLoggerAdapters.TryGetValue(AName, LLoggerAdapterInfo) then
        Exit(LLoggerAdapterInfo.LoggerAdapter);
      // ...or the factory went away while we were waiting on the gate
      if not FRegistry.TryGetValue(AName, LFactoryInfo) then
        Exit(nil);
    finally
      FLock.Release;
    end;

    Result := LFactoryInfo.Factory.CreateLoggerAdapter;

    FLock.Acquire;
    try
      // Unregistered (or re-registered under another factory) while it was
      // being built: the adapter is handed back to this caller but never
      // cached under a name that no longer belongs to it
      if FRegistry.TryGetValue(AName, LCurrentInfo) and (LCurrentInfo.Factory = LFactoryInfo.Factory) then
        FLoggerAdapters.AddOrSetValue(AName, LoggerAdapterInfo.New(LCurrentInfo.Category, Result));
    finally
      FLock.Release;
    end;
  finally
    TMonitor.Exit(LGate);
  end;
end;

procedure TLoggerAdapterRegistry.InvalidateCache;
begin
  FCategoryCache.Clear;
  // Tells the adapter lists being built right now that they are stale
  Inc(FVersion);
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
var
  LName: string;
  LExisting: FactoryInfo;
begin
  LName := AFactory.GetUniqueName;
  FLock.Acquire;
  try
    // Two factories of the same class registered without distinct names is the
    // usual cause: say so, instead of letting TDictionary raise a bare
    // "Duplicates not allowed" EListError
    if FRegistry.TryGetValue(LName, LExisting) then
      raise ELogifyException.CreateFmt(SLoggerFactoryDuplicate, [LName, LExisting.Category]);

    FRegistry.Add(LName, FactoryInfo.New(ACategory, AFactory));
    InvalidateCache;
  finally
    FLock.Release;
  end;
end;

procedure TLoggerAdapterRegistry.UnregisterFactory(const AName: string);
begin
  FLock.Acquire;
  try
    InternalUnregisterFactory(AName);
    InvalidateCache;
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
  LCount: Integer;
begin
  FLock.Acquire;
  try
    // Collected first: the dictionary cannot be modified while enumerating it
    SetLength(LNames, FRegistry.Count);
    LCount := 0;
    for LReg in FRegistry do
      if LReg.Value.Category = ACategory then
      begin
        LNames[LCount] := LReg.Key;
        Inc(LCount);
      end;
    SetLength(LNames, LCount);

    for LName in LNames do
      InternalUnregisterFactory(LName);

    InvalidateCache;
  finally
    FLock.Release;
  end;
end;

procedure TLoggerAdapterRegistry.Clear;
begin
  FLock.Acquire;
  try
    InvalidateCache;
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

procedure TLogLevelHelper.FromString(const AValue: string);
begin
  if not TryFromString(AValue) then
    raise ELogifyException.CreateFmt(SLogLevelNotValid, [AValue]);
end;

function TLogLevelHelper.TryFromString(const AValue: string): Boolean;
var
  LValue: Integer;
begin
  // GetEnumValue answers -1 for anything it does not know: casting that to
  // TLogLevel would leave a level that later indexes LOG_LEVEL_STR out of
  // bounds, so an unknown string must never reach Self.
  LValue := GetEnumValue(TypeInfo(TLogLevel), AValue);
  Result := (LValue >= Ord(Low(TLogLevel))) and (LValue <= Ord(High(TLogLevel)));
  if Result then
    Self := TLogLevel(LValue);
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
