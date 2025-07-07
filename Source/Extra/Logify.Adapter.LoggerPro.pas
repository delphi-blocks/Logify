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
unit Logify.Adapter.LoggerPro;

interface

uses
  System.SysUtils,
  Logify,
  LoggerPro;

type
  /// <summary>                            +
  ///   LoggerPro adapter for the Logify framework
  /// </summary>
  TLogifyAdapterLoggerPro = class(TInterfacedObject, ILoggerAdapter)
  private
    FLogger: ILogWriter;
    FRawLogType: TLogType;
    FTag: string;
  protected
    { ILoggerAdapter }
    procedure WriteLog(const AClassName: string; const AMsg: string; AException: Exception; ALevel: Logify.TLogLevel);
    procedure WriteRawLine(const AMessage: string);
  public
    constructor Create(ALogType: TLogType; ALogger: ILogWriter; const ATag: string; ARawLogType: TLogType);
  end;

  /// <summary>
  ///   Configuration for loggerpro
  /// </summary>
  TLoggerProConfig = record
  private
    FAppenders: TArray<ILogAppender>;
    FEventsHandlers: TLoggerProEventsHandler;
    FLogType: TLogType;
    FTag: string;
    FRawLogLevel: TLogType;
  public
    property Appenders: TArray<ILogAppender> read FAppenders write FAppenders;
    property EventsHandlers: TLoggerProEventsHandler read FEventsHandlers write FEventsHandlers;
    property LogType: TLogType read FLogType write FLogType;
    property Tag: string read FTag write FTag;
    property RawLogLevel: TLogType read FRawLogLevel write FRawLogLevel;

    constructor Create(ALogType: TLogType);
  end;

  /// <summary>
  ///   Procedure for anonymous method configuration
  /// </summary>
  TFileLogConfProc = reference to procedure (var AConfig: TLoggerProConfig);

  /// <summary>
  ///   LoggerPro adapter factory class for the Logify framework.
  ///   Create an instance of this class using one of the CreateAdapterFactory methods.
  /// </summary>
  TLogifyAdapterLoggerProFactory = class(TLoggerAdapterFactory)
  private
    FTag: string;
    FAppenders: TArray<ILogAppender>;
    FEventsHandlers: TLoggerProEventsHandler;
    FLogType: TLogType;
    FRawLogType: TLogType;
    FLogger: ILogWriter;
  public
    /// <summary>
    ///   Creates a new instance of the LoggerPro adapter factory.
    ///   This factory creates the LoggerPro logger with the specified appenders, events handlers, log level, tag and raw log level.
    /// </summary>
    /// <param name="aAppenders">The appenders to use for the logger.</param>
    /// <param name="aEventsHandlers">The events handlers.</param>
    /// <param name="aType">The minimum log type to log.</param>
    /// <param name="aTag">The tag to display in the log entries (typically the class name or identifier).</param>
    /// <param name="aRawLogLevel">The log level to be used with raw logging.</param>
    /// <returns>A new instance of the LoggerPro adapter factory.</returns>
    class function CreateAdapterFactory(aAppenders: TArray<ILogAppender>; aEventsHandlers: TLoggerProEventsHandler = nil;
      aType: TLogType = TLogType.Debug; const aTag: string = ''; aRawLogLevel: TLogType = TLogType.Info): TLogifyAdapterLoggerProFactory; overload;

    /// <summary>
    ///   Creates a LoggerPro adapter factory using an existing logger.
    /// </summary>
    /// <param name="aLogger">The existing logger to use.</param>
    /// <param name="aTag">The tag to display in the log entries (typically the class name or identifier).</param>
    /// <param name="aRawLogType">The log level to be used with raw logging.</param>
    /// <returns>A new instance of the LoggerPro adapter factory.</returns>
    class function CreateAdapterFactory(aLogger: ILogWriter; const aTag: string = ''; aRawLogType: TLogType = TLogType.Info): TLogifyAdapterLoggerProFactory; overload;

    /// <summary>
    ///   Creates a LoggerPro adapter factory with the anonymous method configuration
    /// </summary>
    class function CreateAdapterFactory(AConfProc: TFileLogConfProc): TLogifyAdapterLoggerProFactory; overload;
  public
    function CreateLoggerAdapter: ILoggerAdapter; override;
  end;

implementation

const
  LogLevelMap: array [TLogLevel] of TLogType = (
    TLogType.Debug,
    TLogType.Debug,
    TLogType.Info,
    TLogType.Warning,
    TLogType.Error,
    TLogType.Fatal,
    TLogType.Fatal
  );

{ TLogifyAdapterLoggerProFactory }

class function TLogifyAdapterLoggerProFactory.CreateAdapterFactory(aAppenders: TArray<ILogAppender>; aEventsHandlers: TLoggerProEventsHandler = nil;
  aType: TLogType = TLogType.Debug; const aTag: string = '';
  aRawLogLevel: TLogType = TLogType.Info): TLogifyAdapterLoggerProFactory;
begin
  Result := TLogifyAdapterLoggerProFactory.Create();
  Result.FAppenders := aAppenders;
  Result.FEventsHandlers := aEventsHandlers;
  Result.FLogType := aType;
  Result.FTag := aTag;
  Result.FRawLogType := aRawLogLevel;
end;

class function TLogifyAdapterLoggerProFactory.CreateAdapterFactory(
  aLogger: ILogWriter; const aTag: string = '';
  aRawLogType: TLogType = TLogType.Info): TLogifyAdapterLoggerProFactory;
begin
  Result := TLogifyAdapterLoggerProFactory.Create();
  Result.FLogger := aLogger;
  Result.FTag := aTag;
  Result.FRawLogType := aRawLogType;
end;

class function TLogifyAdapterLoggerProFactory.CreateAdapterFactory(
  AConfProc: TFileLogConfProc): TLogifyAdapterLoggerProFactory;
var
  LConfig: TLoggerProConfig;
begin
  LConfig := TLoggerProConfig.Create(TLogType.Info);
  AConfProc(LConfig);
  Result := CreateAdapterFactory(
    LConfig.Appenders,
    LConfig.EventsHandlers,
    LConfig.LogType,
    LConfig.Tag,
    LConfig.RawLogLevel
  );
end;

function TLogifyAdapterLoggerProFactory.CreateLoggerAdapter: ILoggerAdapter;
var
  LLogger: ILogWriter;
begin
  if Assigned(FLogger) then
  begin
    Result := TLogifyAdapterLoggerPro.Create(TLogType.Debug, FLogger, FTag, FRawLogType);
  end
  else
  begin
    LLogger := BuildLogWriter(FAppenders, FEventsHandlers, FLogType);
    Result := TLogifyAdapterLoggerPro.Create(FLogType, LLogger, FTag, FRawLogType);
  end;
end;

{ TLogifyAdapterLoggerPro }

constructor TLogifyAdapterLoggerPro.Create(ALogType: TLogType; ALogger: ILogWriter; const ATag: string; ARawLogType: TLogType);
begin
  inherited Create();
  FLogger := ALogger;
  FTag := ATag;
  FRawLogType := ARawLogType;
end;

procedure TLogifyAdapterLoggerPro.WriteLog(const AClassName: string; const AMsg: string; AException: Exception; ALevel: Logify.TLogLevel);
begin
  inherited;
  if ALevel = TLogLevel.Off then
    Exit;

  FLogger.Log(LogLevelMap[ALevel], AMsg, FTag);
end;

procedure TLogifyAdapterLoggerPro.WriteRawLine(const AMessage: string);
begin
  inherited;
  FLogger.Log(FRawLogType, AMessage, FTag);
end;

{ TLoggerProConfig }

constructor TLoggerProConfig.Create(ALogType: TLogType);
begin
  FAppenders := nil;
  FEventsHandlers := nil;
  FLogType := ALogType;
  FTag := '';
  FRawLogLevel := ALogType;
end;

end.
