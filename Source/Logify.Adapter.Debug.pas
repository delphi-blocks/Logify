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
  Winapi.Windows;

procedure TLogifyAdapterDebug.InternalLog(const AMessage, AClassName: string; AException: Exception; ALevel: TLogLevel);
begin
  OutputDebugString(PChar(FormatMsg(AMessage, AClassName, AException, ALevel)));
end;

procedure TLogifyAdapterDebug.InternalRaw(const AMessage: string; ALevel: TLogLevel);
begin
  OutputDebugString(PChar(AMessage));
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
