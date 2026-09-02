{******************************************************************************}
{                                                                              }
{  Logify: Metalogger for Delphi                                               }
{                                                                              }
{  Copyright (c) 2025 WiRL Team                                                }
{  https://github.com/delphi-blocks/Logify                                     }
{                                                                              }
{  Licensed under the MIT license                                              }
{                                                                              }
{******************************************************************************}

/// <summary>
///   DX.Logger adapter (https://github.com/omonien/DX.Logger, unit DX.Logger).
///
///   Implements ILoggerAdapter directly instead of deriving from
///   TLoggerAdapterHelper: DX.Logger stamps every entry with its own
///   timestamp, level and thread id and fans it out to its providers
///   (platform default, TextFile, Seq, UI, ...), so the helper layout would
///   only duplicate what each provider already writes. The payload is
///   rendered by a TDXLoggerFormatter, which drops the timestamp and the
///   thread id and keeps the originating class plus the Logify level (which
///   survives the collapse of Critical onto Error), while the exception
///   block (whole InnerException chain) travels in TLogEntry.Details, the
///   field the DX providers reserve for exactly this kind of extra detail.
///
///   Levels are filtered twice and that is intentional: this adapter applies
///   the Logify level (TDXLoggerConfig.Level) like every other adapter, and
///   DX.Logger applies its own global TDXLogger.SetMinLevel afterwards. Keep
///   the DX one at or below the Logify one or the entries never reach the
///   providers.
///
///   IMPORTANT - DX.Logger startup configuration window: from process start
///   DX.Logger buffers every entry and only its platform default provider
///   writes immediately; every other provider stays silent until
///   TDXLogger.CompleteConfiguration is called, StartupTimeoutMs (10 s by
///   default) elapses, or the process shuts down. Logify adapters are built
///   lazily, on the first log call, so nothing here can close that window at
///   a sensible time - the host application has to do it once registration
///   is over:
///
///   <code>
///   TLoggerAdapterRegistry.Instance.RegisterFactory(
///     TLogifyAdapterDXLoggerFactory.CreateAdapterFactory('DX log', TLogLevel.Debug));
///
///   TFileLogProvider.SetLogFileName('app.log');
///   TDXLogger.CompleteConfiguration;   // configuration done, providers start writing
///   </code>
///
///   DX.Logger declares its own TLogLevel, so every level in this unit is
///   qualified (Logify.TLogLevel / DX.Logger.TLogLevel).
/// </summary>
unit Logify.Adapter.DXLogger;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Logify,
  DX.Logger;

type
  /// <summary>
  ///   DX.Logger payload layout. The timestamp and thread id are recorded by
  ///   DX.Logger itself, so what is carried here is the originating class
  ///   and the Logify level - the latter because it survives the collapse of
  ///   Critical onto Error, and because it makes the payload the exact tail
  ///   of the line every other Logify adapter writes. Exceptions render
  ///   through the inherited FormatMessage / FormatException, but only when
  ///   the adapter passes one in, which it does not do while
  ///   ExceptionInDetails is on (the block goes to TLogEntry.Details
  ///   instead).
  ///
  ///   This is a TLoggerFormatter, so a subclass can change one piece of the
  ///   layout (FormatClassName, FormatLevel, ...) or the whole line.
  /// </summary>
  TDXLoggerFormatter = class(TLoggerFormatter)
  public const
    //[ClassName] Level | Message
    DXLOGGER_TEMPLATE = '[%s] %s | %s';
  public
    function FormatMsg(const AMessage, AClassName: string; AException: Exception;
      ALevel: Logify.TLogLevel): string; override;
  end;

  /// <summary>
  ///   Configuration of the DX.Logger adapter
  /// </summary>
  TDXLoggerConfig = record
  private const
    DEFAULT_SOURCE_PROPERTY = 'SourceContext';
    EXCEPTION_TYPE_PROPERTY = 'ExceptionType';
    EXCEPTION_MESSAGE_PROPERTY = 'ExceptionMessage';
  private
    FLevel: Logify.TLogLevel;
    FExceptionInDetails: Boolean;
    FSendProperties: Boolean;
    FSourceProperty: string;
  public
    class function Default: TDXLoggerConfig; static;

    /// <summary>Does this configuration let a message of that level through?</summary>
    function Accepts(ALevel: Logify.TLogLevel): Boolean;

    /// <summary>
    ///   The DX.Logger level matching a Logify one. Logify has one level
    ///   above Error (Critical) that DX.Logger does not distinguish, so
    ///   Critical collapses onto Error and stays readable only through the
    ///   level the formatter writes into the payload; Off maps to None for
    ///   completeness only, Accepts rejects it first.
    /// </summary>
    function LevelFor(ALevel: Logify.TLogLevel): DX.Logger.TLogLevel;

    /// <summary>Minimum level this adapter forwards to DX.Logger</summary>
    property Level: Logify.TLogLevel read FLevel write FLevel;

    /// <summary>
    ///   True (the default): the exception block travels in
    ///   TLogEntry.Details, which the DX providers render on their own (a
    ///   "Details:" line for the console/text providers, a Details field for
    ///   Seq). False: it is appended to the message instead, the way every
    ///   other Logify adapter renders it.
    /// </summary>
    property ExceptionInDetails: Boolean read FExceptionInDetails write FExceptionInDetails;

    /// <summary>
    ///   True (the default): the class name and, when present, the exception
    ///   class and message are attached to the entry as structured
    ///   properties. Providers that understand them (Seq) render them as
    ///   top-level fields; the plain providers ignore them.
    /// </summary>
    property SendProperties: Boolean read FSendProperties write FSendProperties;

    /// <summary>
    ///   Key of the structured property carrying the originating class,
    ///   'SourceContext' by default (the Seq/Serilog convention). Unlike the
    ///   message payload this keeps the fully qualified name, which is what
    ///   makes it worth filtering on. An empty key drops the property.
    ///   Keys must not start with '@', which is reserved by CLEF.
    /// </summary>
    property SourceProperty: string read FSourceProperty write FSourceProperty;
  end;

  /// <summary>
  ///   Procedure for anonymous method configuration
  /// </summary>
  TDXLoggerConfProc = reference to procedure (var AConfig: TDXLoggerConfig);

  /// <summary>
  ///   DX.Logger adapter for the Logify framework
  /// </summary>
  TLogifyAdapterDXLogger = class(TInterfacedObject, ILoggerAdapter)
  private
    FConfig: TDXLoggerConfig;
    FFormatter: TDXLoggerFormatter;
    function GetFormatter: TDXLoggerFormatter;
    procedure SetFormatter(const AFormatter: TDXLoggerFormatter);
    function BuildProperties(const AClassName: string; AException: Exception): TArray<TPair<string, string>>;
  public
    constructor Create(const AConfig: TDXLoggerConfig);
    destructor Destroy; override;

    { ILoggerAdapter }
    procedure WriteLog(const AClassName, AMsg: string; AException: Exception; ALevel: Logify.TLogLevel);
    procedure WriteRawLine(const AMsg: string; ALevel: Logify.TLogLevel);

    /// <summary>
    ///   Formatter used to render the DX.Logger payload. Defaults to a plain
    ///   TDXLoggerFormatter; assign a subclass instance to customize the
    ///   layout, or nil to go back to the default. The adapter owns the
    ///   formatter: it frees the previous one on assignment and on
    ///   destruction. Configure it at startup, not while other threads are
    ///   logging.
    /// </summary>
    property Formatter: TDXLoggerFormatter read GetFormatter write SetFormatter;
  end;

  /// <summary>
  ///   AdapterFactory class for the Logify framework
  /// </summary>
  TLogifyAdapterDXLoggerFactory = class(TLoggerAdapterFactory)
  private
    FConfig: TDXLoggerConfig;
  public
    /// <summary>
    ///   Creates a DX.Logger adapter factory with the default configuration.
    ///   The DX providers are configured through their own units, before or
    ///   right after the registration:
    ///
    ///   <code>
    ///   TLoggerAdapterRegistry.Instance.RegisterFactory(
    ///     TLogifyAdapterDXLoggerFactory.CreateAdapterFactory(TLogLevel.Debug));
    ///   </code>
    /// </summary>
    class function CreateAdapterFactory(ALevel: Logify.TLogLevel): TLogifyAdapterDXLoggerFactory; overload;

    /// <summary>
    ///   Creates a named DX.Logger adapter factory. The name is the registry
    ///   key: give a distinct one to every factory of the same class.
    /// </summary>
    class function CreateAdapterFactory(const AName: string; ALevel: Logify.TLogLevel): TLogifyAdapterDXLoggerFactory; overload;

    /// <summary>
    ///   Creates a DX.Logger adapter factory from a whole configuration.
    /// </summary>
    class function CreateAdapterFactory(const AName: string; const AConfig: TDXLoggerConfig): TLogifyAdapterDXLoggerFactory; overload;

    /// <summary>
    ///   Creates a DX.Logger adapter factory with the anonymous method
    ///   configuration:
    ///
    ///   <code>
    ///   TLogifyAdapterDXLoggerFactory.CreateAdapterFactory('DX log',
    ///     procedure (var AConfig: TDXLoggerConfig)
    ///     begin
    ///       AConfig.Level := TLogLevel.Trace;
    ///       AConfig.SourceProperty := 'Logger';
    ///     end);
    ///   </code>
    /// </summary>
    class function CreateAdapterFactory(const AName: string; AConfProc: TDXLoggerConfProc): TLogifyAdapterDXLoggerFactory; overload;
  public
    function CreateLoggerAdapter: ILoggerAdapter; override;

    property Config: TDXLoggerConfig read FConfig write FConfig;
  end;

implementation

const
  LogLevelMap: array [Logify.TLogLevel] of DX.Logger.TLogLevel = (
    DX.Logger.TLogLevel.Trace,
    DX.Logger.TLogLevel.Debug,
    DX.Logger.TLogLevel.Info,
    DX.Logger.TLogLevel.Warn,
    DX.Logger.TLogLevel.Error,
    // DX.Logger stops at Error: Critical shares the same level and stays
    // recognizable through the Logify level the formatter writes
    DX.Logger.TLogLevel.Error,
    DX.Logger.TLogLevel.None
  );

{ TDXLoggerFormatter }

function TDXLoggerFormatter.FormatMsg(const AMessage, AClassName: string;
  AException: Exception; ALevel: Logify.TLogLevel): string;
begin
  // No timestamp and no thread id: DX.Logger records both itself. The level
  // stays because DX.Logger has no Critical, and FormatMessage appends the
  // exception block when the adapter passes one in, i.e. only when it is not
  // routed to TLogEntry.Details.
  Result := Format(DXLOGGER_TEMPLATE, [
    FormatClassName(AClassName),
    FormatLevel(ALevel),
    FormatMessage(AMessage, AException)
  ]);
end;

{ TDXLoggerConfig }

class function TDXLoggerConfig.Default: TDXLoggerConfig;
begin
  Result.FLevel := Logify.TLogLevel.Info;
  Result.FExceptionInDetails := True;
  Result.FSendProperties := True;
  Result.FSourceProperty := DEFAULT_SOURCE_PROPERTY;
end;

function TDXLoggerConfig.Accepts(ALevel: Logify.TLogLevel): Boolean;
begin
  Result := (ALevel <> Logify.TLogLevel.Off) and (ALevel >= FLevel);
end;

function TDXLoggerConfig.LevelFor(ALevel: Logify.TLogLevel): DX.Logger.TLogLevel;
begin
  Result := LogLevelMap[ALevel];
end;

{ TLogifyAdapterDXLogger }

constructor TLogifyAdapterDXLogger.Create(const AConfig: TDXLoggerConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FFormatter := TDXLoggerFormatter.Create;
end;

destructor TLogifyAdapterDXLogger.Destroy;
begin
  FFormatter.Free;
  inherited;
end;

function TLogifyAdapterDXLogger.GetFormatter: TDXLoggerFormatter;
begin
  Result := FFormatter;
end;

procedure TLogifyAdapterDXLogger.SetFormatter(const AFormatter: TDXLoggerFormatter);
begin
  if AFormatter = FFormatter then
    Exit;
  FFormatter.Free;
  if Assigned(AFormatter) then
    FFormatter := AFormatter
  else
    // Assigning nil resets the adapter to the default layout
    FFormatter := TDXLoggerFormatter.Create;
end;

function TLogifyAdapterDXLogger.BuildProperties(const AClassName: string;
  AException: Exception): TArray<TPair<string, string>>;
begin
  Result := nil;
  if not FConfig.SendProperties then
    Exit;

  // The qualified name, not the short one the payload shows: this is what
  // makes the property worth filtering on
  if (FConfig.SourceProperty <> '') and (AClassName <> '') then
    Result := Result + [TPair<string, string>.Create(FConfig.SourceProperty, AClassName)];

  if AException <> nil then
    Result := Result + [
      TPair<string, string>.Create(TDXLoggerConfig.EXCEPTION_TYPE_PROPERTY, AException.ClassName),
      TPair<string, string>.Create(TDXLoggerConfig.EXCEPTION_MESSAGE_PROPERTY, AException.Message)
    ];
end;

procedure TLogifyAdapterDXLogger.WriteLog(const AClassName, AMsg: string;
  AException: Exception; ALevel: Logify.TLogLevel);
var
  LDetails: string;
  LPayloadException: Exception;
begin
  if not FConfig.Accepts(ALevel) then
    Exit;

  LDetails := '';
  LPayloadException := AException;
  if FConfig.ExceptionInDetails then
  begin
    // FormatException walks the whole InnerException chain (stack traces
    // included) and yields an empty string for a nil exception
    LDetails := FFormatter.FormatException(AException);
    // Already carried by Details: keep it out of the message as well
    LPayloadException := nil;
  end;

  // Note the argument order: FormatMsg takes (AMessage, AClassName)
  TDXLogger.Instance.Log(
    FFormatter.FormatMsg(AMsg, AClassName, LPayloadException, ALevel),
    FConfig.LevelFor(ALevel),
    LDetails,
    BuildProperties(AClassName, AException)
  );
end;

procedure TLogifyAdapterDXLogger.WriteRawLine(const AMsg: string; ALevel: Logify.TLogLevel);
begin
  if not FConfig.Accepts(ALevel) then
    Exit;

  // Raw means raw: no class, no exception block, just the line. DX.Logger
  // still prefixes its own timestamp, level and thread id, there is no way
  // around that from here.
  TDXLogger.Instance.Log(AMsg, FConfig.LevelFor(ALevel));
end;

{ TLogifyAdapterDXLoggerFactory }

class function TLogifyAdapterDXLoggerFactory.CreateAdapterFactory(
  ALevel: Logify.TLogLevel): TLogifyAdapterDXLoggerFactory;
begin
  Result := CreateAdapterFactory('', ALevel);
end;

class function TLogifyAdapterDXLoggerFactory.CreateAdapterFactory(const AName: string;
  ALevel: Logify.TLogLevel): TLogifyAdapterDXLoggerFactory;
var
  LConfig: TDXLoggerConfig;
begin
  LConfig := TDXLoggerConfig.Default;
  LConfig.Level := ALevel;
  Result := CreateAdapterFactory(AName, LConfig);
end;

class function TLogifyAdapterDXLoggerFactory.CreateAdapterFactory(const AName: string;
  const AConfig: TDXLoggerConfig): TLogifyAdapterDXLoggerFactory;
begin
  Result := TLogifyAdapterDXLoggerFactory.Create();
  Result.Name := AName;
  Result.Config := AConfig;
end;

class function TLogifyAdapterDXLoggerFactory.CreateAdapterFactory(const AName: string;
  AConfProc: TDXLoggerConfProc): TLogifyAdapterDXLoggerFactory;
var
  LConfig: TDXLoggerConfig;
begin
  LConfig := TDXLoggerConfig.Default;
  AConfProc(LConfig);
  Result := CreateAdapterFactory(AName, LConfig);
end;

function TLogifyAdapterDXLoggerFactory.CreateLoggerAdapter: ILoggerAdapter;
begin
  Result := TLogifyAdapterDXLogger.Create(FConfig);
end;

end.
