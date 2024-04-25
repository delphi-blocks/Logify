unit Logify.Logger.Buffer;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  Logify;

type
  TBufferLogger = class(TLoggerHelper, ILogger)
  private
    FBuffer: TStringList;
    FDestination: TStrings;
  protected
    procedure InternalLog(const AMsg: string; ALevel: TLogLevel); override;
    procedure InternalRaw(const AMsg: string); override;
  public
    constructor Create;
    destructor Destroy; override;

    // Non-interface methods
    procedure Flush(ADestination: ILogger); overload;
    procedure Flush(ADestination: TStrings); overload;
    procedure SetDestination(ADestination: TStrings);
  end;

implementation

{ TBufferLogger }

constructor TBufferLogger.Create;
begin
  FBuffer := TStringList.Create;
end;

destructor TBufferLogger.Destroy;
begin
  FBuffer.Free;
  inherited;
end;

procedure TBufferLogger.Flush(ADestination: ILogger);
begin
  for var Msg in FBuffer do
    ADestination.LogRawLine(Msg);
end;

procedure TBufferLogger.Flush(ADestination: TStrings);
begin
  ADestination.AddStrings(FBuffer);
end;

procedure TBufferLogger.InternalLog(const AMsg: string; ALevel: TLogLevel);
begin
  if Assigned(FDestination) then
    FDestination.Add(FormatLog(AMsg, ALevel))
  else
    FBuffer.Add(FormatLog(AMsg, ALevel));
end;

procedure TBufferLogger.InternalRaw(const AMsg: string);
begin
  if Assigned(FDestination) then
    FDestination.Add(AMsg)
  else
    FBuffer.Add(AMsg);
end;

procedure TBufferLogger.SetDestination(ADestination: TStrings);
begin
  FDestination := ADestination;
end;

end.
