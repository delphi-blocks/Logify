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
unit Logify.Adapter.Debug;

interface

uses
  System.SysUtils, Logify;

type
  /// <summary>
  ///   Adapter for the Logify framework
  /// </summary>
  TLogifyAdapterDebug = class(TLoggerAdapterHelper, ILoggerAdapter)
  protected
    procedure InternalLog(const AMessage, AClassName: string; AException: Exception; ALevel: TLogLevel); override;
    procedure InternalRaw(const AMessage: string; ALevel: TLogLevel); override;
  end;

  /// <summary>
  ///   AdapterFactory class for the Logify framework
  /// </summary>
  TLogifyAdapterDebugFactory = class(TLoggerAdapterFactory)
  private
    FLevel: TLogLevel;
  public
    class function CreateAdapterFactory(ALevel: TLogLevel): TLogifyAdapterDebugFactory; overload;
    class function CreateAdapterFactory(const AName: string; ALevel: TLogLevel): TLogifyAdapterDebugFactory; overload;
  public
    function CreateLoggerAdapter: ILoggerAdapter; override;

    property Level: TLogLevel read FLevel write FLevel;
  end;

implementation

uses
  {$IFDEF MSWINDOWS}Winapi.Windows{$ENDIF}
  {$IFDEF POSIX}Posix.Unistd{$ENDIF};

/// <summary>
///   Writes one line to the platform debug channel.
/// </summary>
procedure WriteDebugLine(const AMessage: string);
{$IFDEF POSIX}
var
  LBytes: TBytes;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  // The Windows debug channel is line oriented: one call is one line
  OutputDebugString(PChar(AMessage));
  {$ENDIF}

  {$IFDEF POSIX}
  // There is no OutputDebugString here. stderr is the conventional out of
  // band diagnostic channel: unbuffered, separate from whatever the program
  // writes to stdout, and captured by the IDE when debugging a Linux target.
  // A single write() call per message keeps concurrent lines from interleaving.
  LBytes := TEncoding.UTF8.GetBytes(AMessage + sLineBreak);
  __write(STDERR_FILENO, Pointer(LBytes), Length(LBytes));
  {$ENDIF}
end;

procedure TLogifyAdapterDebug.InternalLog(const AMessage, AClassName: string; AException: Exception; ALevel: TLogLevel);
begin
  WriteDebugLine(FormatMsg(AMessage, AClassName, AException, ALevel));
end;

procedure TLogifyAdapterDebug.InternalRaw(const AMessage: string; ALevel: TLogLevel);
begin
  WriteDebugLine(AMessage);
end;

{ TLogifyAdapterDebugFactory }

class function TLogifyAdapterDebugFactory.CreateAdapterFactory(const AName: string; ALevel: TLogLevel): TLogifyAdapterDebugFactory;
begin
  Result := TLogifyAdapterDebugFactory.Create();
  Result.Name := AName;
  Result.Level := ALevel;
end;

class function TLogifyAdapterDebugFactory.CreateAdapterFactory(ALevel: TLogLevel): TLogifyAdapterDebugFactory;
begin
  Result := CreateAdapterFactory('', ALevel);
end;

function TLogifyAdapterDebugFactory.CreateLoggerAdapter: ILoggerAdapter;
begin
  Result := TLogifyAdapterDebug.Create(FLevel);
end;

end.
