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
///   Syslog types, configuration and the syslog payload layout
///   (TSyslogFormatter).
///
///   Deliberately free of any POSIX dependency: the whole mapping between
///   Logify and the syslog protocol lives here, so it compiles and can be
///   tested on every platform, and a future network transport (RFC 3164 /
///   5424) can reuse it untouched.
/// </summary>
unit Logify.Syslog;

interface

{$SCOPEDENUMS ON}

uses
  System.SysUtils,
  Logify;

type
  /// <summary>
  ///   Syslog facilities. The ordinals ARE the protocol codes, reserved
  ///   entries included, so no separate lookup table is needed.
  /// </summary>
  TSyslogFacility = (
    Kernel, User, Mail, Daemon, Auth, Syslog, LPR, News,
    UUCP, Cron, AuthPriv, FTP, NTP, Audit, Alert, Clock,
    Local0, Local1, Local2, Local3, Local4, Local5, Local6, Local7
  );

  /// <summary>
  ///   Syslog severities, ordered as the protocol orders them: the ordinal
  ///   is the code.
  /// </summary>
  TSyslogSeverity = (
    Emergency, Alert, Critical, Error, Warning, Notice, Info, Debug
  );

  /// <summary>
  ///   openlog() options. The ordinal is the bit position of the flag.
  /// </summary>
  TSyslogOption = (PID, Console, Delay, NoDelay, NoWait, PrintError);
  TSyslogOptions = set of TSyslogOption;

  TSyslogFacilityHelper = record helper for TSyslogFacility
    /// <summary>Facility code, not yet shifted into a priority</summary>
    function ToCode: Integer;
  end;

  TSyslogSeverityHelper = record helper for TSyslogSeverity
    function ToCode: Integer;
    /// <summary>
    ///   Logify levels are fewer than syslog severities: Trace and Debug both
    ///   land on Debug, and Notice/Alert/Emergency are never produced.
    /// </summary>
    class function FromLevel(ALevel: TLogLevel): TSyslogSeverity; static;
  end;

  TSyslogOptionsHelper = record helper for TSyslogOptions
    function ToCode: Integer;
  end;

  /// <summary>
  ///   Configuration for the syslog adapter
  /// </summary>
  TSyslogConfig = record
  private const
    DEFAULT_MAX_LENGTH = 1024;
  private
    FAppName: string;
    FFacility: TSyslogFacility;
    FOptions: TSyslogOptions;
    FLevel: TLogLevel;
    FSplitLines: Boolean;
    FMaxLength: Integer;
    FUseLogMask: Boolean;
    procedure SetMaxLength(const Value: Integer);
  public
    class function Default: TSyslogConfig; static;

    /// <summary>Does this configuration let a message of that level through?</summary>
    function Accepts(ALevel: TLogLevel): Boolean;

    /// <summary>facility or severity, the single number syslog(3) expects</summary>
    function PriorityFor(ALevel: TLogLevel): Integer;

    /// <summary>
    ///   The facility as openlog(3) wants it: shifted into the priority's
    ///   upper bits, with the severity left at zero.
    /// </summary>
    function FacilityCode: Integer;

    /// <summary>The setlogmask() value matching Level, i.e. LOG_UPTO</summary>
    function LogMask: Integer;

    /// <summary>Is an openlog() call needed at all, or will the defaults do?</summary>
    function NeedsOpenLog: Boolean;

    /// <summary>Program name reported as the syslog tag. Empty: libc uses argv[0]</summary>
    property AppName: string read FAppName write FAppName;
    property Facility: TSyslogFacility read FFacility write FFacility;
    property Options: TSyslogOptions read FOptions write FOptions;
    /// <summary>Lowest level that reaches syslog at all</summary>
    property Level: TLogLevel read FLevel write FLevel;
    /// <summary>
    ///   Emit one syslog record per line. Off, a stack trace arrives as a
    ///   single record with the newlines escaped (#012 with rsyslog).
    /// </summary>
    property SplitLines: Boolean read FSplitLines write FSplitLines;
    /// <summary>Longest record emitted; 0 disables the limit</summary>
    property MaxLength: Integer read FMaxLength write SetMaxLength;
    /// <summary>
    ///   Also push Level down into libc via setlogmask(). Off by default: the
    ///   Logify level is meant to be the only place filtering happens.
    /// </summary>
    property UseLogMask: Boolean read FUseLogMask write FUseLogMask;
  end;

  TSyslogConfProc = reference to procedure (var AConfig: TSyslogConfig);

  /// <summary>
  ///   Syslog payload layout. The timestamp, host, tag and pid are added by
  ///   syslog itself, so only what it cannot know is carried here: the
  ///   originating class and the Logify level (which survives the collapse
  ///   of Trace and Debug onto a single severity). Exceptions render through
  ///   the inherited FormatMessage / FormatException, so the whole
  ///   InnerException chain is carried in the payload like everywhere else.
  ///
  ///   This is a TLoggerFormatter, so a subclass can change one piece of the
  ///   layout (FormatClassName, FormatLevel, ...) or the whole line.
  /// </summary>
  TSyslogFormatter = class(TLoggerFormatter)
  public const
    //[ClassName] LEVEL | Message
    SYSLOG_TEMPLATE = '[%s] %s | %s';
  public
    function FormatMsg(const AMessage, AClassName: string; AException: Exception; ALevel: TLogLevel): string; override;
  end;

/// <summary>
///   Cuts a payload into the records to emit, honouring SplitLines and
///   MaxLength. Blank lines are dropped rather than logged as empty records.
/// </summary>
function SplitMessage(const AMessage: string; AMaxLength: Integer;
  ASplitLines: Boolean): TArray<string>;

implementation

{ TSyslogFacilityHelper }

function TSyslogFacilityHelper.ToCode: Integer;
begin
  Result := Ord(Self);
end;

{ TSyslogSeverityHelper }

function TSyslogSeverityHelper.ToCode: Integer;
begin
  Result := Ord(Self);
end;

class function TSyslogSeverityHelper.FromLevel(ALevel: TLogLevel): TSyslogSeverity;
begin
  case ALevel of
    TLogLevel.Trace:    Result := TSyslogSeverity.Debug;
    TLogLevel.Debug:    Result := TSyslogSeverity.Debug;
    TLogLevel.Info:     Result := TSyslogSeverity.Info;
    TLogLevel.Warning:  Result := TSyslogSeverity.Warning;
    TLogLevel.Error:    Result := TSyslogSeverity.Error;
    TLogLevel.Critical: Result := TSyslogSeverity.Critical;
  else
    // Off is never emitted; Debug keeps the result a valid severity
    Result := TSyslogSeverity.Debug;
  end;
end;

{ TSyslogOptionsHelper }

function TSyslogOptionsHelper.ToCode: Integer;
var
  LOption: TSyslogOption;
begin
  Result := 0;
  for LOption in Self do
    Result := Result or (1 shl Ord(LOption));
end;

{ TSyslogConfig }

class function TSyslogConfig.Default: TSyslogConfig;
begin
  Result.FAppName := '';
  Result.FFacility := TSyslogFacility.User;
  Result.FOptions := [TSyslogOption.PID];
  Result.FLevel := TLogLevel.Info;
  Result.FSplitLines := True;
  Result.FMaxLength := DEFAULT_MAX_LENGTH;
  Result.FUseLogMask := False;
end;

procedure TSyslogConfig.SetMaxLength(const Value: Integer);
begin
  if Value < 0 then
    FMaxLength := 0
  else
    FMaxLength := Value;
end;

function TSyslogConfig.Accepts(ALevel: TLogLevel): Boolean;
begin
  Result := (ALevel <> TLogLevel.Off) and (ALevel >= FLevel);
end;

function TSyslogConfig.PriorityFor(ALevel: TLogLevel): Integer;
begin
  Result := (FFacility.ToCode shl 3) or TSyslogSeverity.FromLevel(ALevel).ToCode;
end;

function TSyslogConfig.FacilityCode: Integer;
begin
  Result := FFacility.ToCode shl 3;
end;

function TSyslogConfig.LogMask: Integer;
begin
  Result := (1 shl (TSyslogSeverity.FromLevel(FLevel).ToCode + 1)) - 1;
end;

function TSyslogConfig.NeedsOpenLog: Boolean;
begin
  Result := (not FAppName.IsEmpty) or (FOptions <> []);
end;

{ TSyslogFormatter }

function TSyslogFormatter.FormatMsg(const AMessage, AClassName: string;
    AException: Exception; ALevel: TLogLevel): string;
begin
  // No timestamp or thread id: syslog records those itself. The class and
  // level come from the inherited pieces, and FormatMessage appends the
  // exception block (whole InnerException chain) when one is present.
  Result := Format(SYSLOG_TEMPLATE, [
    FormatClassName(AClassName),
    FormatLevel(ALevel),
    FormatMessage(AMessage, AException)
  ]);
end;

function SplitMessage(const AMessage: string; AMaxLength: Integer;
  ASplitLines: Boolean): TArray<string>;
var
  LLines: TArray<string>;
  LLine: string;
  LRest: string;
begin
  Result := [];
  if AMessage.IsEmpty then
    Exit;

  if not ASplitLines then
  begin
    // One record per log call: truncate, never wrap
    if (AMaxLength > 0) and (AMessage.Length > AMaxLength) then
      Result := [AMessage.Substring(0, AMaxLength)]
    else
      Result := [AMessage];
    Exit;
  end;

  LLines := AMessage.Replace(#13#10, #10).Replace(#13, #10).Split([#10]);
  for LLine in LLines do
  begin
    if LLine.IsEmpty then
      Continue;

    if AMaxLength <= 0 then
    begin
      Result := Result + [LLine];
      Continue;
    end;

    LRest := LLine;
    while LRest.Length > AMaxLength do
    begin
      Result := Result + [LRest.Substring(0, AMaxLength)];
      LRest := LRest.Substring(AMaxLength);
    end;
    if not LRest.IsEmpty then
      Result := Result + [LRest];
  end;
end;

end.
