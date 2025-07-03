program LogifyConsole;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils, System.Classes,
  Logify,
  Logify.Adapter.Console;

procedure Thread1Proc;
begin
  for var i := 1 to 1000 do
    Logger.LogInfo('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
end;

procedure Thread2Proc;
begin
  for var i := 1 to 1000 do
    Logger.LogInfo('bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb');
end;

begin
  TLoggerAdapterRegistry.Instance.RegisterFactory(
    TLogifyAdapterConsoleFactory.CreateAdapterFactory('Console log', TLogLevel.Info));
  try
    Logger.LogInfo('Hello, console!');
    var th1 := TThread.CreateAnonymousThread(Thread1Proc);
    var th2 := TThread.CreateAnonymousThread(Thread2Proc);
    th1.Start;
    th2.Start;
    Sleep(1000);
    Write('> '); Readln;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
