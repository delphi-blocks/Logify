unit Logify.Logger.Console;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Logify;

type
  TConsoleLogger = class(TLoggerHelper, ILogger)
  public
    procedure Log(const AMsg: string; ALevel: TLogLevel); override;
    procedure LogRawLine(const AMsg: string);
  end;

implementation

procedure TConsoleLogger.Log(const AMsg: string; ALevel: TLogLevel);
begin
  if ALevel < FLevel then
    Exit;

  Writeln(FormatLog(AMsg, ALevel));
end;

procedure TConsoleLogger.LogRawLine(const AMsg: string);
begin
  Writeln(AMsg);
end;

end.
