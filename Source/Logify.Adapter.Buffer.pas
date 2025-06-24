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
  ///   Adapter class for the Logify framework
  /// </summary>
  TLogifyAdapterBuffer = class(TLoggerAdapterHelper, ILoggerAdapter)
  private
    FBuffer: TStringList;
    FDestination: TStrings;
  protected
    procedure InternalLog(const AMessage, AClassName: string; AException: Exception; ALevel: TLogLevel); override;
    procedure InternalRaw(const AMessage: string); override;

    function InternalGetLogger(const AName: string = ''): TObject; override;
  public
    constructor Create;
    destructor Destroy; override;

    // Non-interface methods
    procedure Flush(ADestination: ILogger); overload;
    procedure Flush(ADestination: TStrings); overload;
    procedure SetDestination(ADestination: TStrings);
  end;

  /// <summary>
  ///   AdapterFactory class for the Logify framework
  /// </summary>
  TLogifyAdapterBufferFactory = class(TLoggerAdapterFactory)
  private
    FDest: TStrings;
  public
    class function CreateAdapterFactory(ADest: TStrings): TLogifyAdapterBufferFactory; overload;
    class function CreateAdapterFactory(const AName: string; ADest: TStrings): TLogifyAdapterBufferFactory; overload;
  public
    function CreateLoggerAdapter: ILoggerAdapter; override;
    property Dest: TStrings read FDest write FDest;
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

procedure TLogifyAdapterBuffer.Flush(ADestination: ILogger);
begin
  for var Msg in FBuffer do
    ADestination.LogRawLine(Msg);
end;

procedure TLogifyAdapterBuffer.Flush(ADestination: TStrings);
begin
  ADestination.AddStrings(FBuffer);
end;

function TLogifyAdapterBuffer.InternalGetLogger(const AName: string): TObject;
begin
  Result := Self;
end;

procedure TLogifyAdapterBuffer.InternalLog(const AMessage, AClassName: string;
    AException: Exception; ALevel: TLogLevel);
begin
  if Assigned(FDestination) then
    FDestination.Add(FormatMsg(AMessage, AClassName, AException, ALevel))
  else
    FBuffer.Add(FormatMsg(AMessage, AClassName, AException, ALevel));
end;

procedure TLogifyAdapterBuffer.InternalRaw(const AMessage: string);
begin
  if Assigned(FDestination) then
    FDestination.Add(AMessage)
  else
    FBuffer.Add(AMessage);
end;

procedure TLogifyAdapterBuffer.SetDestination(ADestination: TStrings);
begin
  FDestination := ADestination;
end;

{ TLogifyAdapterBufferFactory }

class function TLogifyAdapterBufferFactory.CreateAdapterFactory(ADest: TStrings): TLogifyAdapterBufferFactory;
begin
  Result := CreateAdapterFactory('', ADest);
end;

class function TLogifyAdapterBufferFactory.CreateAdapterFactory(const AName: string; ADest: TStrings): TLogifyAdapterBufferFactory;
begin
  Result := TLogifyAdapterBufferFactory.Create();
  Result.Name := AName;
  Result.Dest := ADest;
end;

function TLogifyAdapterBufferFactory.CreateLoggerAdapter: ILoggerAdapter;
var
  LLogger: TLogifyAdapterBuffer;
begin
  LLogger := TLogifyAdapterBuffer.Create();
  LLogger.SetDestination(FDest);

  Result := LLogger;
end;

end.
