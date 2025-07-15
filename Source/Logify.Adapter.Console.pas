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
unit Logify.Adapter.Console;

interface

uses
  {$IFDEF MSWindows}
  Winapi.Windows,
  {$ENDIF}
  System.SysUtils,
  Logify;

type
  /// <summary>
  ///   Adapter class for the Logify framework
  /// </summary>
  TLogifyAdapterConsole = class(TLoggerAdapterHelper, ILoggerAdapter)
  {$IFDEF MSWindows}
  strict private
    FAllocated: boolean;
  strict protected
    procedure AllocateConsole; inline;
  {$ENDIF}
  protected
    procedure InternalLog(const AMessage, AClassName: string; AException: Exception; ALevel: TLogLevel); override;
    procedure InternalRaw(const AMessage: string; ALevel: TLogLevel); override;
  end;

  /// <summary>
  ///   AdapterFactory class for the Logify framework
  /// </summary>
  TLogifyAdapterConsoleFactory = class(TLoggerAdapterFactory)
  private
    FLevel: TLogLevel;
  public
    class function CreateAdapterFactory(ALevel: TLogLevel): TLogifyAdapterConsoleFactory; overload;
    class function CreateAdapterFactory(const AName: string; ALevel: TLogLevel): TLogifyAdapterConsoleFactory; overload;
  public
    function CreateLoggerAdapter: ILoggerAdapter; override;

    property Level: TLogLevel read FLevel write FLevel;
  end;

implementation

{$IFDEF MSWindows}
procedure TLogifyAdapterConsole.AllocateConsole;
begin
  if FAllocated then
    Exit;

  AllocConsole;
  FAllocated := true;
end;
{$ENDIF}

procedure TLogifyAdapterConsole.InternalLog(const AMessage, AClassName: string;
    AException: Exception; ALevel: TLogLevel);
begin
  {$IFDEF MSWindows}
  AllocConsole;
  {$ENDIF}

  Writeln(FormatMsg(AMessage, AClassName, AException, ALevel));
end;

procedure TLogifyAdapterConsole.InternalRaw(const AMessage: string; ALevel: TLogLevel);
begin
  {$IFDEF MSWindows}
  AllocConsole;
  {$ENDIF}

  Writeln(AMessage);
end;

class function TLogifyAdapterConsoleFactory.CreateAdapterFactory(
  const AName: string; ALevel: TLogLevel): TLogifyAdapterConsoleFactory;
begin
  Result := TLogifyAdapterConsoleFactory.Create();
  Result.Name := AName;
  Result.Level := ALevel;
end;

class function TLogifyAdapterConsoleFactory.CreateAdapterFactory(
  ALevel: TLogLevel): TLogifyAdapterConsoleFactory;
begin
  Result := CreateAdapterFactory('', ALevel);
end;

function TLogifyAdapterConsoleFactory.CreateLoggerAdapter: ILoggerAdapter;
begin
  Result := TLogifyAdapterConsole.Create();
end;

end.
