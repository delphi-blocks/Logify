unit Logify.Logger.Console;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Logify;

type
  TConsoleLogger = class(TLoggerHelper, ILogger)
  protected
    procedure InternalLog(const AMsg: string; ALevel: TLogLevel); override;
    procedure InternalRaw(const AMsg: string); override;
  end;

implementation

procedure TConsoleLogger.InternalLog(const AMsg: string; ALevel: TLogLevel);
begin
  Writeln(FormatMsg(AMsg, ALevel));
end;

procedure TConsoleLogger.InternalRaw(const AMsg: string);
begin
  Writeln(AMsg);
end;

end.
