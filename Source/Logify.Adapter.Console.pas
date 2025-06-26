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
    procedure InternalRaw(const AMessage: string); override;
    function InternalGetLogger(const AName: string = ''): TObject; override;
  end;

  /// <summary>
  ///   AdapterFactory class for the Logify framework
  /// </summary>
  TLogifyAdapterConsoleFactory = class(TLoggerAdapterFactory)
  public
    class function CreateAdapterFactory(const AName: string): TLogifyAdapterConsoleFactory;
  public
    function CreateLoggerAdapter: ILoggerAdapter; override;
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

function TLogifyAdapterConsole.InternalGetLogger(const AName: string): TObject;
begin
  Result := Self;
end;

procedure TLogifyAdapterConsole.InternalLog(const AMessage, AClassName: string;
    AException: Exception; ALevel: TLogLevel);
begin
  {$IFDEF MSWindows}
  AllocConsole;
  {$ENDIF}

  Writeln(FormatMsg(AMessage, AClassName, AException, ALevel));
end;

procedure TLogifyAdapterConsole.InternalRaw(const AMessage: string);
begin
  {$IFDEF MSWindows}
  AllocConsole;
  {$ENDIF}

  Writeln(AMessage);
end;

{ TLogifyAdapterConsoleFactory }

class function TLogifyAdapterConsoleFactory.CreateAdapterFactory(const AName: string): TLogifyAdapterConsoleFactory;
begin
  Result := TLogifyAdapterConsoleFactory.Create();
  Result.Name := AName;
end;

function TLogifyAdapterConsoleFactory.CreateLoggerAdapter: ILoggerAdapter;
begin
  Result := TLogifyAdapterConsole.Create();
end;

end.
