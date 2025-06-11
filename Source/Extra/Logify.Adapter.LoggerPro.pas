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
  /// <summary>
  ///   LoggerPro adapter for the Logify framework
  /// </summary>
  TLogifyAdapterLoggerPro = class(TLoggerAdapterHelper, ILoggerAdapter)
  private
    FLogger: ILogWriter;
    FRawLogType: TLogType;
    FTag: string;
  protected
    procedure InternalLog(const AMessage, AClassName: string; AException: Exception; ALevel: TLogLevel); override;
    procedure InternalRaw(const AMessage: string); override;
    function InternalGetLogger(const AName: string = ''): TObject; override;
  public
    constructor Create(ALogType: TLogType; ALogger: ILogWriter; const ATag: string; ARawLogType: TLogType);
  end;

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
  public
    function CreateLoggerAdapter: ILoggerAdapter; override;
  end;

implementation

const
  LogTypeMap: array [TLogType] of TLogLevel = (
    TLogLevel.Debug,
    TLogLevel.Info,
    TLogLevel.Warning,
    TLogLevel.Error,
    TLogLevel.Critical
  );

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
  inherited Create(LogTypeMap[ALogType]);
  FLogger := ALogger;
  FTag := ATag;
  FRawLogType := ARawLogType;
end;

function TLogifyAdapterLoggerPro.InternalGetLogger(
  const AName: string): TObject;
begin
  Result := Self;
end;

procedure TLogifyAdapterLoggerPro.InternalLog(const AMessage,
  AClassName: string; AException: Exception; ALevel: TLogLevel);
begin
  inherited;
  if ALevel = TLogLevel.Off then
    Exit;

  FLogger.Log(LogLevelMap[ALevel], AMessage, FTag);
end;

procedure TLogifyAdapterLoggerPro.InternalRaw(const AMessage: string);
begin
  inherited;
  FLogger.Log(FRawLogType, AMessage, FTag);
end;

end.
