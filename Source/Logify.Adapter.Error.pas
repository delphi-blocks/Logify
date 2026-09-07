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
unit Logify.Adapter.Error;

interface

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  System.SysUtils,
  Logify;

type
  /// <summary>
  ///   Adapter class for the Logify framework: writes every line to the
  ///   standard error stream.
  ///
  ///   stderr is the conventional out of band diagnostic channel: it stays
  ///   separate from whatever the program writes to stdout, so the log can be
  ///   redirected (<c>app 2&gt; app.log</c>) without touching the program
  ///   output, and it is what service supervisors (systemd, Docker) collect.
  ///
  ///   Every message is written with a single write call, so lines logged
  ///   from different threads do not interleave. When the process has no
  ///   standard error at all (a Windows GUI application started without a
  ///   console) the adapter silently does nothing: unlike
  ///   <see cref="TLogifyAdapterConsole" /> it never allocates a console.
  /// </summary>
  TLogifyAdapterError = class(TLoggerAdapterHelper, ILoggerAdapter)
  strict private
    {$IFDEF MSWINDOWS}
    FHandle: THandle;
    FIsConsole: Boolean;
    FResolved: Boolean;
    /// <summary>
    ///   Looks up the standard error handle and tells a console apart from a
    ///   redirection. Done once, on the first line written, because a console
    ///   can still be attached after the adapter has been created.
    /// </summary>
    procedure ResolveHandle;
    {$ENDIF}
    procedure WriteErrorLine(const AMessage: string);
  protected
    procedure InternalLog(const AMessage, AClassName: string; AException: Exception; ALevel: TLogLevel); override;
    procedure InternalRaw(const AMessage: string; ALevel: TLogLevel); override;
  end;

  /// <summary>
  ///   AdapterFactory class for the Logify framework
  /// </summary>
  TLogifyAdapterErrorFactory = class(TLoggerAdapterFactory)
  private
    FLevel: TLogLevel;
  public
    class function CreateAdapterFactory(ALevel: TLogLevel): TLogifyAdapterErrorFactory; overload;
    class function CreateAdapterFactory(const AName: string; ALevel: TLogLevel): TLogifyAdapterErrorFactory; overload;
  public
    function CreateLoggerAdapter: ILoggerAdapter; override;

    property Level: TLogLevel read FLevel write FLevel;
  end;

implementation

{$IFDEF POSIX}
uses
  Posix.Unistd;
{$ENDIF}

{ TLogifyAdapterError }

{$IFDEF MSWINDOWS}
procedure TLogifyAdapterError.ResolveHandle;
var
  LMode: DWORD;
begin
  FHandle := GetStdHandle(STD_ERROR_HANDLE);
  if FHandle = INVALID_HANDLE_VALUE then
    FHandle := 0;

  // A console handle takes characters, not bytes: WriteFile would hand the
  // UTF-8 bytes to the console code page and mangle everything outside it.
  // A redirected stderr (file, pipe) instead takes the UTF-8 bytes as they are
  FIsConsole := (FHandle <> 0) and GetConsoleMode(FHandle, LMode);

  FResolved := True;
end;
{$ENDIF}

procedure TLogifyAdapterError.WriteErrorLine(const AMessage: string);
var
  LLine: string;
  LBytes: TBytes;
  {$IFDEF MSWINDOWS}
  LWritten: DWORD;
  {$ENDIF}
begin
  LLine := AMessage + sLineBreak;

  {$IFDEF MSWINDOWS}
  if not FResolved then
    ResolveHandle;

  // No standard error at all (a GUI application without a console)
  if FHandle = 0 then
    Exit;

  if FIsConsole then
    WriteConsole(FHandle, PChar(LLine), Length(LLine), LWritten, nil)
  else
  begin
    LBytes := TEncoding.UTF8.GetBytes(LLine);
    WriteFile(FHandle, PByte(LBytes)^, Length(LBytes), LWritten, nil);
  end;
  {$ENDIF}

  {$IFDEF POSIX}
  LBytes := TEncoding.UTF8.GetBytes(LLine);
  __write(STDERR_FILENO, Pointer(LBytes), Length(LBytes));
  {$ENDIF}
end;

procedure TLogifyAdapterError.InternalLog(const AMessage, AClassName: string;
  AException: Exception; ALevel: TLogLevel);
begin
  WriteErrorLine(FormatMsg(AMessage, AClassName, AException, ALevel));
end;

procedure TLogifyAdapterError.InternalRaw(const AMessage: string; ALevel: TLogLevel);
begin
  WriteErrorLine(AMessage);
end;

{ TLogifyAdapterErrorFactory }

class function TLogifyAdapterErrorFactory.CreateAdapterFactory(
  const AName: string; ALevel: TLogLevel): TLogifyAdapterErrorFactory;
begin
  Result := TLogifyAdapterErrorFactory.Create();
  Result.Name := AName;
  Result.Level := ALevel;
end;

class function TLogifyAdapterErrorFactory.CreateAdapterFactory(
  ALevel: TLogLevel): TLogifyAdapterErrorFactory;
begin
  Result := CreateAdapterFactory('', ALevel);
end;

function TLogifyAdapterErrorFactory.CreateLoggerAdapter: ILoggerAdapter;
begin
  Result := TLogifyAdapterError.Create(FLevel);
end;

end.
