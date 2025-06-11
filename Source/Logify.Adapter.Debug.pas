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
    procedure InternalLog(const AClassName: string; const AException: Exception;
        const AMessage: string; const ALevel: TLogLevel); override;
    function InternalGetLogger(const AName: string = ''): TObject; override;
  end;

  /// <summary>
  ///   AdapterFactory class for the Logify framework
  /// </summary>
  TLogifyAdapterDebugFactory = class(TLoggerAdapterFactory)
  public
    class function CreateAdapterFactory(const AName: string = ''): TLogifyAdapterDebugFactory;
  public
    function CreateLoggerAdapter: ILoggerAdapter; override;
  end;

implementation

uses
  Winapi.Windows;

function TLogifyAdapterDebug.InternalGetLogger(const AName: string): TObject;
begin
  Result := Self;
end;

procedure TLogifyAdapterDebug.InternalLog(const AClassName: string; const AException: Exception; const AMessage: string; const ALevel: TLogLevel);
begin
  OutputDebugString(PChar(FormatMsg(AClassName, AException, AMessage, ALevel)));
end;

{ TLogifyAdapterDebugFactory }

class function TLogifyAdapterDebugFactory.CreateAdapterFactory(const AName: string): TLogifyAdapterDebugFactory;
begin
  Result := TLogifyAdapterDebugFactory.Create();
  Result.Name := AName;
end;

function TLogifyAdapterDebugFactory.CreateLoggerAdapter: ILoggerAdapter;
begin
  Result := TLogifyAdapterDebug.Create();
end;

end.
