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
unit Logify.Adapter.Buffer;

interface

uses
  System.Classes,
  System.SysUtils,
  Logify;

type
  /// <summary>
  ///   Adapter class for the Buffer Logger
  /// </summary>
  TLogifyAdapterBuffer = class(TLoggerAdapterHelper, ILoggerAdapter)
  private
    FTarget: TStrings;
    FBuffer: TStringList;
  protected
    procedure InternalLog(const AMessage, AClassName: string; AException: Exception; ALevel: TLogLevel); override;
    procedure InternalRaw(const AMessage: string); override;
  public
    constructor Create;
    destructor Destroy; override;

    // Non-interface methods
    procedure Flush(ATarget: ILogger); overload;
    procedure Flush(ATarget: TStrings); overload;
    procedure SetTarget(ATarget: TStrings);
  end;

  /// <summary>
  ///   AdapterFactory class for the Logify framework
  /// </summary>
  TLogifyAdapterBufferFactory = class(TLoggerAdapterFactory)
  private
    FLevel: TLogLevel;
    FTarget: TStrings;
  public
    class function CreateAdapterFactory(ALevel: TLogLevel; ATarget: TStrings): TLogifyAdapterBufferFactory; overload;
    class function CreateAdapterFactory(const AName: string; ALevel: TLogLevel; ATarget: TStrings): TLogifyAdapterBufferFactory; overload;
  public
    function CreateLoggerAdapter: ILoggerAdapter; override;

    property Level: TLogLevel read FLevel write FLevel;
    property Target: TStrings read FTarget write FTarget;
  end;

implementation

{ TBufferLogger }

constructor TLogifyAdapterBuffer.Create;
begin
  inherited Create;
  FBuffer := TStringList.Create;
end;

destructor TLogifyAdapterBuffer.Destroy;
begin
  FBuffer.Free;
  inherited;
end;

procedure TLogifyAdapterBuffer.Flush(ATarget: ILogger);
begin
  for var Msg in FBuffer do
    ATarget.LogRawLine(Msg);
end;

procedure TLogifyAdapterBuffer.Flush(ATarget: TStrings);
begin
  ATarget.AddStrings(FBuffer);
end;

procedure TLogifyAdapterBuffer.InternalLog(const AMessage, AClassName: string;
    AException: Exception; ALevel: TLogLevel);
begin
  if Assigned(FTarget) then
    FTarget.Add(FormatMsg(AMessage, AClassName, AException, ALevel))
  else
    FBuffer.Add(FormatMsg(AMessage, AClassName, AException, ALevel));
end;

procedure TLogifyAdapterBuffer.InternalRaw(const AMessage: string);
begin
  if Assigned(FTarget) then
    FTarget.Add(AMessage)
  else
    FBuffer.Add(AMessage);
end;

procedure TLogifyAdapterBuffer.SetTarget(ATarget: TStrings);
begin
  FTarget := ATarget;
end;

class function TLogifyAdapterBufferFactory.CreateAdapterFactory(const AName: string;
  ALevel: TLogLevel; ATarget: TStrings): TLogifyAdapterBufferFactory;
begin
  Result := TLogifyAdapterBufferFactory.Create();
  Result.Name := AName;
  Result.Level := ALevel;
  Result.Target := ATarget;
end;

class function TLogifyAdapterBufferFactory.CreateAdapterFactory(ALevel: TLogLevel;
  ATarget: TStrings): TLogifyAdapterBufferFactory;
begin
  Result := CreateAdapterFactory('', ALevel, ATarget);
end;

function TLogifyAdapterBufferFactory.CreateLoggerAdapter: ILoggerAdapter;
var
  LLogger: TLogifyAdapterBuffer;
begin
  LLogger := TLogifyAdapterBuffer.Create();
  LLogger.Level := FLevel;
  LLogger.SetTarget(FTarget);

  Result := LLogger;
end;

end.
