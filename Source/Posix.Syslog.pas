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
///   Binding for the syslog(3) family of libc. The RTL does not ship one.
///
///   Compiles to an empty unit outside POSIX.
/// </summary>
unit Posix.Syslog;

interface

{$IFDEF POSIX}

uses
  System.SysUtils,
  Posix.Base;

const
  // openlog() options
  LOG_PID    = $01;              // log the pid with each message
  LOG_CONS   = $02;              // log on the console if errors in sending
  LOG_ODELAY = $04;              // delay open until first syslog() (default)
  LOG_NDELAY = $08;              // don't delay open
  LOG_NOWAIT = $10;              // don't wait for console forks: DEPRECATED
  LOG_PERROR = $20;              // log to stderr as well

const
  // facility codes, already shifted into place
  LOG_KERN     =  0 shl 3;       // kernel messages
  LOG_USER     =  1 shl 3;       // random user-level messages
  LOG_MAIL     =  2 shl 3;       // mail system
  LOG_DAEMON   =  3 shl 3;       // system daemons
  LOG_AUTH     =  4 shl 3;       // security/authorization messages
  LOG_SYSLOG   =  5 shl 3;       // messages generated internally by syslogd
  LOG_LPR      =  6 shl 3;       // line printer subsystem
  LOG_NEWS     =  7 shl 3;       // network news subsystem
  LOG_UUCP     =  8 shl 3;       // UUCP subsystem
  LOG_CRON     =  9 shl 3;       // clock daemon
  LOG_AUTHPRIV = 10 shl 3;       // security/authorization messages (private)
  LOG_FTP      = 11 shl 3;       // ftp daemon

  // codes through 15 are reserved for system use
  LOG_LOCAL0   = 16 shl 3;       // reserved for local use
  LOG_LOCAL1   = 17 shl 3;
  LOG_LOCAL2   = 18 shl 3;
  LOG_LOCAL3   = 19 shl 3;
  LOG_LOCAL4   = 20 shl 3;
  LOG_LOCAL5   = 21 shl 3;
  LOG_LOCAL6   = 22 shl 3;
  LOG_LOCAL7   = 23 shl 3;

  LOG_NFACILITIES = 24;          // current number of facilities
  LOG_FACMASK     = $03F8;       // mask to extract the facility part

const
  // priorities, ordered
  LOG_EMERG   = 0;               // system is unusable
  LOG_ALERT   = 1;               // action must be taken immediately
  LOG_CRIT    = 2;               // critical conditions
  LOG_ERR     = 3;               // error conditions
  LOG_WARNING = 4;               // warning conditions
  LOG_NOTICE  = 5;               // normal but significant condition
  LOG_INFO    = 6;               // informational
  LOG_DEBUG   = 7;               // debug-level messages

  LOG_PRIMASK = $07;             // mask to extract the priority part

// syslog.h macros

function LOG_PRI(APriority: LongInt): LongInt; inline;
function LOG_MASK(APriority: LongInt): LongInt; inline;
function LOG_UPTO(APriority: LongInt): LongInt; inline;

// Pascal wrappers

/// <summary>
///   openlog(3). An empty ident lets libc fall back to the program name.
/// </summary>
procedure OpenLog(const AIdent: string; AOption, AFacility: LongInt);

/// <summary>
///   closelog(3)
/// </summary>
procedure CloseLog;

/// <summary>
///   setlogmask(3), returns the previous mask
/// </summary>
function SetLogMask(AMask: LongInt): LongInt;

/// <summary>
///   syslog(3). The message is passed as an argument and never as the format
///   string, so a '%' in a logged message cannot reach the libc formatter.
/// </summary>
procedure SysLog(APriority: LongInt; const AMessage: string);

{$ENDIF}

implementation

{$IFDEF POSIX}

procedure _openlog(ident: MarshaledAString; option: LongInt; facility: LongInt); cdecl;
  external libc name _PU + 'openlog';

procedure _closelog; cdecl;
  external libc name _PU + 'closelog';

function _setlogmask(mask: LongInt): LongInt; cdecl;
  external libc name _PU + 'setlogmask';

// Declared varargs: this is a C variadic function, and Delphi's "array of
// const" would pass a TVarRec array, which is a completely different ABI.
procedure _syslog(priority: LongInt; format: MarshaledAString); cdecl; varargs;
  external libc name _PU + 'syslog';

const
  // Kept as a byte array so its address is stable and needs no marshalling
  FORMAT_ARGUMENT: array[0..2] of AnsiChar = ('%', 's', #0);

var
  // openlog() stores the pointer it is handed, it does not copy the string:
  // the buffer has to outlive every later syslog() call, so it lives here
  // rather than in a local marshaller that dies on return.
  _Ident: TBytes;

function LOG_PRI(APriority: LongInt): LongInt;
begin
  Result := APriority and LOG_PRIMASK;
end;

function LOG_MASK(APriority: LongInt): LongInt;
begin
  Result := 1 shl APriority;
end;

function LOG_UPTO(APriority: LongInt): LongInt;
begin
  Result := (1 shl (APriority + 1)) - 1;
end;

procedure OpenLog(const AIdent: string; AOption, AFacility: LongInt);
begin
  if AIdent.IsEmpty then
    _Ident := nil
  else
    _Ident := TEncoding.UTF8.GetBytes(AIdent + #0);

  // A nil ident is legal and documented: libc uses the program name
  _openlog(MarshaledAString(Pointer(_Ident)), AOption, AFacility);
end;

procedure CloseLog;
begin
  _closelog;
  _Ident := nil;
end;

function SetLogMask(AMask: LongInt): LongInt;
begin
  Result := _setlogmask(AMask);
end;

procedure SysLog(APriority: LongInt; const AMessage: string);
var
  LBytes: TBytes;
begin
  LBytes := TEncoding.UTF8.GetBytes(AMessage + #0);
  _syslog(APriority, @FORMAT_ARGUMENT[0], MarshaledAString(Pointer(LBytes)));
end;

{$ENDIF}

end.
