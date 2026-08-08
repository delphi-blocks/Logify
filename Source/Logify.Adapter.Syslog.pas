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

/// <summary>
///   Syslog adapter, on top of libc syslog(3).
///
///   Implements ILoggerAdapter directly instead of deriving from
///   TLoggerAdapterHelper: syslog does its own timestamping, tagging and
///   severity handling, so the helper's formatting would only duplicate what
///   the daemon already records.
///
///   Compiles to an empty unit outside POSIX.
/// </summary>
unit Logify.Adapter.Syslog;

interface

{$IFDEF POSIX}

uses
  System.SysUtils,
  Logify,
  Logify.Syslog;

type
  /// <summary>
  ///   Adapter for the Logify framework
  /// </summary>
  TLogifyAdapterSyslog = class(TInterfacedObject, ILoggerAdapter)
  private
    FConfig: TSyslogConfig;
    FOpened: Boolean;
    procedure OpenSession;
    procedure CloseSession;
    procedure Emit(const APayload: string; ALevel: TLogLevel);
  public
    constructor Create(const AConfig: TSyslogConfig);
    destructor Destroy; override;

    { ILoggerAdapter }
    procedure WriteLog(const AClassName, AMessage: string; AException: Exception; ALevel: TLogLevel);
    procedure WriteRawLine(const AMessage: string; ALevel: TLogLevel);
  end;

  /// <summary>
  ///   AdapterFactory class for the Logify framework
  /// </summary>
  TLogifyAdapterSyslogFactory = class(TLoggerAdapterFactory)
  private
    FConfig: TSyslogConfig;
  public
    class function CreateAdapterFactory(const AConfig: TSyslogConfig): TLogifyAdapterSyslogFactory; overload;
    class function CreateAdapterFactory(const AName: string; const AConfig: TSyslogConfig): TLogifyAdapterSyslogFactory; overload;
    class function CreateAdapterFactory(const AName: string; AConfProc: TSyslogConfProc): TLogifyAdapterSyslogFactory; overload;
  public
    function CreateLoggerAdapter: ILoggerAdapter; override;

    property Config: TSyslogConfig read FConfig write FConfig;
  end;

{$ENDIF}

implementation

{$IFDEF POSIX}

uses
  System.SyncObjs,
  Posix.Syslog;

var
  /// <summary>
  ///   openlog() and closelog() act on the process, not on a handle: several
  ///   adapters would otherwise overwrite each other's tag and the first one
  ///   destroyed would close the session for all of them. Only the first
  ///   opens, only the last closes.
  /// </summary>
  _OpenSessions: Integer;

{ TLogifyAdapterSyslog }

constructor TLogifyAdapterSyslog.Create(const AConfig: TSyslogConfig);
begin
  inherited Create;
  FConfig := AConfig;
  OpenSession;
end;

destructor TLogifyAdapterSyslog.Destroy;
begin
  CloseSession;
  inherited;
end;

procedure TLogifyAdapterSyslog.OpenSession;
begin
  // Without a tag or options there is nothing to configure: syslog() opens the
  // session by itself and libc tags the records with the program name.
  if not FConfig.NeedsOpenLog then
    Exit;

  FOpened := True;
  if TInterlocked.Increment(_OpenSessions) = 1 then
  begin
    OpenLog(FConfig.AppName, FConfig.Options.ToCode, FConfig.FacilityCode);

    // Off by default: the Logify level is meant to be the only filter, having
    // libc drop messages as well just gives two places to look.
    if FConfig.UseLogMask then
      SetLogMask(FConfig.LogMask);
  end;
end;

procedure TLogifyAdapterSyslog.CloseSession;
begin
  if not FOpened then
    Exit;

  FOpened := False;
  if TInterlocked.Decrement(_OpenSessions) = 0 then
    CloseLog;
end;

procedure TLogifyAdapterSyslog.Emit(const APayload: string; ALevel: TLogLevel);
var
  LPriority: Integer;
  LRecord: string;
begin
  LPriority := FConfig.PriorityFor(ALevel);
  for LRecord in SplitMessage(APayload, FConfig.MaxLength, FConfig.SplitLines) do
    Posix.Syslog.SysLog(LPriority, LRecord);
end;

procedure TLogifyAdapterSyslog.WriteLog(const AClassName, AMessage: string;
  AException: Exception; ALevel: TLogLevel);
var
  LPayload: string;
begin
  if not FConfig.Accepts(ALevel) then
    Exit;

  LPayload := ShapeMessage(AClassName, AMessage, ALevel);
  if Assigned(AException) then
    LPayload := LPayload + sLineBreak + GetFullExceptionInfo(AException);

  Emit(LPayload, ALevel);
end;

procedure TLogifyAdapterSyslog.WriteRawLine(const AMessage: string; ALevel: TLogLevel);
begin
  if not FConfig.Accepts(ALevel) then
    Exit;

  // Raw means raw: no class, no level, just the line
  Emit(AMessage, ALevel);
end;

{ TLogifyAdapterSyslogFactory }

class function TLogifyAdapterSyslogFactory.CreateAdapterFactory(
  const AConfig: TSyslogConfig): TLogifyAdapterSyslogFactory;
begin
  Result := CreateAdapterFactory('', AConfig);
end;

class function TLogifyAdapterSyslogFactory.CreateAdapterFactory(const AName: string;
  const AConfig: TSyslogConfig): TLogifyAdapterSyslogFactory;
begin
  Result := TLogifyAdapterSyslogFactory.Create();
  Result.Name := AName;
  Result.Config := AConfig;
end;

class function TLogifyAdapterSyslogFactory.CreateAdapterFactory(const AName: string;
  AConfProc: TSyslogConfProc): TLogifyAdapterSyslogFactory;
var
  LConfig: TSyslogConfig;
begin
  LConfig := TSyslogConfig.Default;
  AConfProc(LConfig);
  Result := CreateAdapterFactory(AName, LConfig);
end;

function TLogifyAdapterSyslogFactory.CreateLoggerAdapter: ILoggerAdapter;
begin
  Result := TLogifyAdapterSyslog.Create(FConfig);
end;

{$ENDIF}

end.
