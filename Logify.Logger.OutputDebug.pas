unit Logify.Logger.OutputDebug;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Winapi.Windows,
  Logify;

type
  TOutputDebugLogger = class(TLoggerHelper, ILogger)
  public
    procedure Log(const AMsg: string; ALevel: TLogLevel);
    procedure LogRawLine(const AMsg: string);
  end;

implementation

procedure TOutputDebugLogger.Log(const AMsg: string; ALevel: TLogLevel);
begin
  if ALevel < FLevel then
    Exit;

  OutputDebugString(PChar(FormatLog(AMsg, ALevel)));
end;

procedure TOutputDebugLogger.LogRawLine(const AMsg: string);
begin
  OutputDebugString(PChar(AMsg));
end;

end.
