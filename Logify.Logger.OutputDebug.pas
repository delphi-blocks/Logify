unit Logify.Logger.OutputDebug;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Winapi.Windows,
  Logify;

type
  TOutputDebugLogger = class(TLoggerHelper, ILogger)
  protected
    procedure InternalLog(const AMsg: string; ALevel: TLogLevel); override;
    procedure InternalRaw(const AMsg: string); override;
  end;

implementation

procedure TOutputDebugLogger.InternalLog(const AMsg: string; ALevel: TLogLevel);
begin
  OutputDebugString(PChar(FormatMsg(AMsg, ALevel)));
end;

procedure TOutputDebugLogger.InternalRaw(const AMsg: string);
begin
  OutputDebugString(PChar(AMsg));
end;

end.
