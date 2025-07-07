unit Logify.Adapter.QuickLogger;

interface

uses
  System.Classes, System.SysUtils,
  Logify,
  Quick.Logger;

type
  /// <summary>                            +
  ///   QuickLogger adapter for the Logify framework
  /// </summary>
  TLogifyAdapterQuickLog = class(TInterfacedObject, ILoggerAdapter)
  private
    FLogger: TLogger;
    FRawLogType: TEventType;
  public
    { ILoggerAdapter }
    procedure WriteRawLine(const AMsg: string);
    procedure WriteLog(const AClassName: string; const AMsg: string; AException: Exception; ALevel: Logify.TLogLevel);

    constructor Create(ALogger: TLogger; ALogLevel: Logify.TLogLevel);
  end;

  TLogifyAdapterQuickLoggerFactory = class(TLoggerAdapterFactory)
  private
    FLogger: TLogger;
    FLogLevel: Logify.TLogLevel;
  public
    /// <summary>
    ///   Creates a QuickLogger adapter factory using the default logger.
    ///   You can configure quick logger as in the following example:
    ///
    ///  TLoggerAdapterRegistry.Instance.RegisterFactory(
    ///    TLogifyAdapterQuickLoggerFactory.CreateAdapterFactory()
    ///  );
    ///  Quick.Logger.Logger.Providers.Add(GlobalLogStringListProvider);
    ///
    ///  GlobalLogStringListProvider.LogList := memoLog.Lines;
    ///  GlobalLogStringListProvider.Enabled := True;
    ///  GlobalLogStringListProvider.ShowTimeStamp := True;
    ///  GlobalLogStringListProvider.ShowEventTypes := True;
    /// </summary>
    class function CreateAdapterFactory(ALogLevel: Logify.TLogLevel = Logify.TLogLevel.Info): TLogifyAdapterQuickLoggerFactory; overload;

    /// <summary>
    ///   Creates a QuickLogger adapter factory using provided logger.
    ///   You need to configure the logger before run the following method.
    /// </summary>
    class function CreateAdapterFactory(ALogger: TLogger; ALogLevel: Logify.TLogLevel = Logify.TLogLevel.Info): TLogifyAdapterQuickLoggerFactory; overload;
  public
    function CreateLoggerAdapter: ILoggerAdapter; override;
  end;

implementation

const
  LogLevelMap: array [Logify.TLogLevel] of TEventType = (
    etTrace,
    etDebug,
    etInfo,
    etWarning,
    etError,
    etCritical,
    etCritical
  );

{ TLogifyAdapterQuickLoggerFactory }

class function TLogifyAdapterQuickLoggerFactory.CreateAdapterFactory(ALogLevel: Logify.TLogLevel): TLogifyAdapterQuickLoggerFactory;
begin
  Result := TLogifyAdapterQuickLoggerFactory.Create();
  Result.FLogger := Logger;
  Result.FLogLevel := ALogLevel;
end;

class function TLogifyAdapterQuickLoggerFactory.CreateAdapterFactory(
  ALogger: TLogger; ALogLevel: Logify.TLogLevel): TLogifyAdapterQuickLoggerFactory;
begin
  Result := TLogifyAdapterQuickLoggerFactory.Create();
  Result.FLogger := ALogger;
  Result.FLogLevel := ALogLevel;
end;

function TLogifyAdapterQuickLoggerFactory.CreateLoggerAdapter: ILoggerAdapter;
begin
  if Assigned(FLogger) then
    Result := TLogifyAdapterQuickLog.Create(FLogger, FLogLevel)
  else
    Result := TLogifyAdapterQuickLog.Create(Quick.Logger.Logger, FLogLevel);
end;

{ TLogifyAdapterQuickLog }

constructor TLogifyAdapterQuickLog.Create(ALogger: TLogger; ALogLevel: Logify.TLogLevel);
begin
  inherited Create;
  FLogger := ALogger;
  FRawLogType := etCustom1;
end;

procedure TLogifyAdapterQuickLog.WriteLog(const AClassName, AMsg: string;
  AException: Exception; ALevel: Logify.TLogLevel);
begin
  FLogger.Add(AMsg, [AClassName], LogLevelMap[ALevel]);
end;

procedure TLogifyAdapterQuickLog.WriteRawLine(const AMsg: string);
begin
  FLogger.Add(AMsg, FRawLogType);
end;

end.
