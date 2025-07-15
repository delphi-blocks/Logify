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
  System.Generics.Collections,
  Logify;

type
  /// <summary>
  ///   Adapter class for the Buffer Logger
  /// </summary>
  TLogifyAdapterBuffer = class(TLoggerAdapterHelper, ILoggerAdapter)
  private type
    TMsgBuffer = record
      Msg: string;
      Level: TLogLevel;
      class function New(const AMsg: string; ALevel: TLogLevel): TMsgBuffer; static;
    end;
  private
    FTarget: TStrings;
    FBuffer: TList<TMsgBuffer>;
  protected
    procedure InternalLog(const AMessage, AClassName: string; AException: Exception; ALevel: TLogLevel); override;
    procedure InternalRaw(const AMessage: string; ALevel: TLogLevel); override;
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
  FBuffer := TList<TMsgBuffer>.Create;
end;

destructor TLogifyAdapterBuffer.Destroy;
begin
  FBuffer.Free;
  inherited;
end;

procedure TLogifyAdapterBuffer.Flush(ATarget: ILogger);
var
  LItem: TMsgBuffer;
begin
  for LItem in FBuffer do
    ATarget.LogRawLine(LItem.Msg, LItem.Level);
end;

procedure TLogifyAdapterBuffer.Flush(ATarget: TStrings);
var
  LItem: TMsgBuffer;
begin
  for LItem in FBuffer do
    ATarget.Add(LItem.Msg);
end;

procedure TLogifyAdapterBuffer.InternalLog(const AMessage, AClassName: string;
    AException: Exception; ALevel: TLogLevel);
begin
  if Assigned(FTarget) then
    FTarget.Add(FormatMsg(AMessage, AClassName, AException, ALevel))
  else
    FBuffer.Add(TMsgBuffer.New(FormatMsg(AMessage, AClassName, AException, ALevel), ALevel));
end;

procedure TLogifyAdapterBuffer.InternalRaw(const AMessage: string; ALevel: TLogLevel);
begin
  if Assigned(FTarget) then
    FTarget.Add(AMessage)
  else
    FBuffer.Add(TMsgBuffer.New(AMessage, ALevel));
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

{ TLogifyAdapterBuffer.TMsgBuffer }

class function TLogifyAdapterBuffer.TMsgBuffer.New(const AMsg: string;
  ALevel: TLogLevel): TMsgBuffer;
begin
  Result.Msg := AMsg;
  Result.Level := ALevel;
end;

end.
