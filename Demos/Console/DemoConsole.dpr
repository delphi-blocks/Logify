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
program DemoConsole;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils, System.Classes,
  Logify,
  Logify.Adapter.Console,
  Logify.Adapter.Error;

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
  // Everything from Info up goes to stdout...
  TLoggerAdapterRegistry.Instance.RegisterFactory(
    TLogifyAdapterConsoleFactory.CreateAdapterFactory('Console log', TLogLevel.Info));

  // ...while warnings and above are duplicated on stderr, so they can be
  // separated from the program output: DemoConsole.exe 2> errors.log
  TLoggerAdapterRegistry.Instance.RegisterFactory(
    TLogifyAdapterErrorFactory.CreateAdapterFactory('Error log', TLogLevel.Warning));
  try
    Logger.LogInfo('Hello, console!');

    // Below the stderr adapter level: this line only shows up on stdout
    Logger.LogInfo('Starting the worker threads');
    // At or above it: shown twice, once per stream
    Logger.LogWarning('This one goes to stdout *and* to stderr');
    try
      raise Exception.Create('Something went wrong');
    except
      on E: Exception do
        Logger.LogError(E, 'And so does the exception below');
    end;

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
