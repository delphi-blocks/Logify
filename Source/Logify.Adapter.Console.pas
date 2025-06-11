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
  Logify, System.SysUtils;

type
  /// <summary>
  ///   Adapter class for the Logify framework
  /// </summary>
  TLogifyAdapterConsole = class(TLoggerAdapterHelper, ILoggerAdapter)
  protected
    procedure InternalLog(const AClassName: string; const AException: Exception; const AMessage: string; const ALevel: TLogLevel); override;
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

function TLogifyAdapterConsole.InternalGetLogger(const AName: string): TObject;
begin
  Result := Self;
end;

procedure TLogifyAdapterConsole.InternalLog(const AClassName: string; const AException: Exception; const AMessage: string; const ALevel: TLogLevel);
begin
  Writeln(FormatMsg(AClassName, AException, AMessage, ALevel));
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
