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
program DemoSyslog;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Logify,
  Logify.Syslog,
  Logify.Adapter.Syslog,
  Posix.Syslog;

const
  APP_NAME = 'logify-demo';

procedure Configure;
begin
  TLoggerAdapterRegistry.Instance.RegisterFactory(
    TLogifyAdapterSyslogFactory.CreateAdapterFactory('syslog',
      procedure (var AConfig: TSyslogConfig)
      begin
        // The tag the records are filed under; without it libc uses argv[0]
        AConfig.AppName := APP_NAME;

        // local0..local7 are the facilities left free for applications
        AConfig.Facility := TSyslogFacility.Local6;
        AConfig.Options := [TSyslogOption.PID];
        AConfig.Level := TLogLevel.Debug;

        // A stack trace arrives as one readable record per line
        AConfig.SplitLines := True;
      end
    ));
end;

procedure LogEveryLevel;
begin
  Logger.LogTrace('a trace line, mapped onto the debug severity');
  Logger.LogDebug('a debug line');
  Logger.LogInfo('an info line');
  Logger.LogWarning('a warning line');
  Logger.LogError('an error line');
  Logger.LogCritical('a critical line');
end;

procedure LogTextThatLooksLikeAFormatString;
begin
  // The message is passed to syslog(3) as an argument, never as the format
  // string, so these reach the log verbatim instead of sending libc looking
  // for arguments that were never pushed.
  Logger.LogInfo('100%s done, %d items, %n %p %x');
end;

procedure LogAnException;
begin
  try
    try
      raise Exception.Create('the root cause');
    except
      Exception.RaiseOuterException(Exception.Create('the outer failure'));
    end;
  except
    on E: Exception do
      Logger.LogError(E, 'the operation failed');
  end;
end;

procedure LogFromAClass;
var
  LLogger: ILogger;
begin
  LLogger := TLoggerManager.GetLogger(TObject);
  LLogger.LogInfo('a line stamped with the originating class');
  LLogger.LogRawLine('a raw line, no class and no level', TLogLevel.Info);
end;

begin
  try
    Configure;

    LogEveryLevel;
    LogTextThatLooksLikeAFormatString;
    LogAnException;
    LogFromAClass;

    Writeln('Sent to syslog under the tag "', APP_NAME, '" (facility local6).');
    Writeln('Read it back with:');
    Writeln('  journalctl -t ', APP_NAME, ' -n 50        # systemd');
    Writeln('  grep ', APP_NAME, ' /var/log/syslog       # rsyslog');

    // Releases the adapters, which closes the syslog session
    TLoggerAdapterRegistry.Instance.Clear;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
