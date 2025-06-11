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
unit Logify.Adapter.Files;

interface

uses
  System.Classes,
  System.SysUtils,
  System.SyncObjs,
  System.Diagnostics,
  System.Generics.Defaults,
  System.Generics.Collections,

  Logify;

{$SCOPEDENUMS ON}

type
  /// <summary>
  ///   Configuration for the TLogFile logger
  /// </summary>
  TLogType = (Single, Rotate);
  TFileLogConfig = record
  private const
    DATETIME_FILENAME = 'yyyymmdd_hhmmss';
  public type
  private
    FLogType: TLogType;
    FAppend: Boolean;
    FBuffered: Boolean;
    FExt: string;
    FFullName: string;
    FName: string;
    FPath: string;
    FLevel: TLogLevel;
    FRotateSize: Integer;
    FRotateItems: Integer;
    procedure SetExt(const Value: string);
    procedure SetPath(const Value: string);
    function BuildRotateName: string;
    function GetLogList: TArray<string>;
  public
    class function NewSingle(ALevel: TLogLevel; AAppend: Boolean = True;
      const AName: string = ''; const APath: string = '.\logs';
      const AExt: string = '.log'): TFileLogConfig; static;

    class function NewRotate(ALevel: TLogLevel; AAppend: Boolean = True;
      const AName: string = ''; const APath: string = '.\logs';
      const AExt: string = '.log';
      ARotateItems: Integer = 10; ARotateSize: Integer = 10485760): TFileLogConfig; static;
  public
    procedure SetLogName(const ALogName: string);
    function IsRotate: Boolean;
    function GetFileName: string;
    function NeedAnotherLog(ASize: UInt64): Boolean;
  public
    property LogType: TLogType read FLogType write FLogType;
    property Level: TLogLevel read FLevel write FLevel;
    property Path: string read FPath write SetPath;
    property Name: string read FName write FName;
    property Ext: string read FExt write SetExt;
    property FullName: string read FFullName write FFullName;
    property Append: Boolean read FAppend write FAppend;
    property Buffered: Boolean read FBuffered write FBuffered;
    property RotateSize: Integer read FRotateSize write FRotateSize;
    property RotateItems: Integer read FRotateItems write FRotateItems;
  end;

  /// <summary>
  ///   Simple Log to file class for the Logify framework
  /// </summary>
  TLogFile = class
  private type

    /// <summary>
    ///   Thread-safe queue (FIFO) for UTF8String
    /// </summary>
    TMessageQueue = class
    private
      FMessages: TQueue<UTF8String>;
    public
      constructor Create;
      destructor Destroy; override;

      procedure Lock; inline;
      procedure UnLock;inline;

      procedure Clear;
      procedure Push(const AItem: UTF8String);
      function Pop: UTF8String;
      function PopAll: TArray<UTF8String>;
      function Count: NativeInt;
    end;

    /// <summary>
    ///   Message Writer Thread
    /// </summary>
    TMessageWriter = class(TThread)
    private
      //FWatch: TStopWatch;
      FConfig: TFileLogConfig;
      FSleepInterval: Integer;
      FWrittenBytes: Int64;
      FQueue: TMessageQueue;
      FExecuting: Boolean;
      function RecoverLastLog: TFileStream;
      function CreateLogFile: TFileStream;
      function CreateNextLog(AStream: TFileStream): TFileStream;

      procedure ConsumeQueue(AStream: TStream);
      procedure ConsumeQueueBuffered(AStream: TStream);
    protected
      procedure Execute; override;
      procedure Stop;
    public
      constructor Create(const AConfig: TFileLogConfig; AQueue: TMessageQueue);
    end;

    /// <summary>
    ///   File Rotation Thread
    /// </summary>
    TRotateTimer = class(TThread)
    private
      FSignal: TEvent;
      FConfig: TFileLogConfig;
      FInterval: Cardinal;
      procedure DeleteOldFiles;
    protected
      procedure Execute; override;
    public
      constructor Create(const AConfig: TFileLogConfig); overload;
      destructor Destroy; override;

      procedure SignalTermination();
    end;

  private
    FConfig: TFileLogConfig;
    FStarted: Boolean;
    FQueue: TMessageQueue;
    FWriter: TMessageWriter;
    FRotateTimer: TRotateTimer;
    function GetMessagesToWrite: Integer;
  public
    constructor Create(const AConfig: TFileLogConfig);
    destructor Destroy; override;

    procedure StartLogging;
    procedure EndLogging;

    procedure AddStr(const AString: string);

    property MessagesToWrite: Integer read GetMessagesToWrite;
  end;

  /// <summary>
  ///   Adapter for the Logify framework
  /// </summary>
  TLogifyAdapterFiles = class(TLoggerAdapterHelper, ILoggerAdapter)
  private
    FLogger: TLogFile;
  protected
    procedure InternalLog(const AMessage, AClassName: string; AException: Exception; ALevel: TLogLevel); override;
    procedure InternalRaw(const AMessage: string); override;

    function InternalGetLogger(const AName: string = ''): TObject; override;
  public
    constructor Create(const AConfig: TFileLogConfig);
    destructor Destroy; override;

    procedure InitializeLogger; virtual;
    procedure FinalizeLogger; virtual;

    function GetMessagesToWrite: Integer;
  end;

  /// <summary>
  ///   AdapterFactory class for the Logify framework
  /// </summary>
  TLogifyAdapterFilesFactory = class(TLoggerAdapterFactory)
  private
    FConfig: TFileLogConfig;
  public
    class function CreateAdapterFactory(const AConfig: TFileLogConfig): TLogifyAdapterFilesFactory; overload;
    class function CreateAdapterFactory(const AName: string; const AConfig: TFileLogConfig): TLogifyAdapterFilesFactory; overload;
  public
    property Config: TFileLogConfig read FConfig write FConfig;
    function CreateLoggerAdapter: ILoggerAdapter; override;
  end;


implementation

uses
  System.IOUtils;

constructor TLogFile.Create(const AConfig: TFileLogConfig);
begin
  FConfig := AConfig;

  FQueue := TMessageQueue.Create;

  FWriter  := TMessageWriter.Create(AConfig, FQueue);
  FRotateTimer := TRotateTimer.Create(AConfig);
end;

destructor TLogFile.Destroy;
begin
  if Assigned(FRotateTimer) then
  begin
    FRotateTimer.Terminate();
    if not FRotateTimer.Suspended then
      FRotateTimer.WaitFor;

    FreeAndNil(FRotateTimer);
  end;

  if Assigned(FWriter) then
  begin
    FWriter.Terminate();
    if not FWriter.Suspended then
      FWriter.WaitFor;

    FreeAndNil(FWriter);
  end;

  FQueue.Free;
  inherited;
end;

procedure TLogFile.EndLogging;
begin
  FWriter.Stop;
end;

procedure TLogFile.StartLogging;
begin
  if FStarted then
    Exit;

  FWriter.Start;
  while not FWriter.FExecuting do
    Sleep(5);

  if FConfig.LogType = TLogType.Rotate then
    FRotateTimer.Start;

  FStarted := True;
end;

procedure TLogFile.AddStr(const AString: string);
begin
  if AString.EndsWith(sLineBreak) then
    FQueue.Push(UTF8String(AString))
  else
    FQueue.Push(UTF8String(AString + sLineBreak));
end;

function TLogFile.GetMessagesToWrite: Integer;
begin
  Result := FQueue.Count;
end;

{ TMessageWriter }

procedure TLogFile.TMessageWriter.ConsumeQueue(AStream: TStream);
var
  LStr: UTF8String;
  LStrLen: UInt32;
begin
  LStr := FQueue.Pop();
  LStrLen := Length(LStr);
  AStream.WriteBuffer(PAnsiChar(LStr)^, LStrLen);
  FWrittenBytes := FWrittenBytes + LStrLen;

  {
  if ContainsStr(LStr, 'Line 0') then
    FWatch.Start;

  if ContainsStr(LStr, 'Line 9999') then
  begin
    FWatch.Stop;
    var tm: UTF8String := Format('Total time for (%d) bytes: %d' + sLineBreak, [Length(LStr), FWatch.ElapsedMilliseconds]);
    AStream.WriteBuffer(PAnsiChar(tm)^, Length(tm));
    FWatch.Reset;
  end;
  }
end;

procedure TLogFile.TMessageWriter.ConsumeQueueBuffered(AStream: TStream);
var
  LArray: TArray<UTF8String>;
  LStr: UTF8String;
  LStrLen: Integer;
  //LChunkLen: Integer;
begin

  //FWatch.Start;
  //LChunkLen := 0;
  LArray := FQueue.PopAll;
  for LStr in LArray do
  begin
    LStrLen := Length(LStr);
    AStream.WriteBuffer(PAnsiChar(LStr)^, LStrLen);
    FWrittenBytes := FWrittenBytes + LStrLen;
    //LChunkLen := LChunkLen + LStrLen;
  end;

  {
  FWatch.Stop;
  var tm: UTF8String := Format('Total time for %d bytes: %dms' + sLineBreak, [LChunkLen, FWatch.ElapsedMilliseconds]);
  AStream.WriteBuffer(PAnsiChar(tm)^, Length(tm));
  FWatch.Reset;
  FQueue.Lock;
  try
    for LStr in FQueue.FMessages do
    begin
      LStrLen := Length(LStr);
      AStream.WriteBuffer(PAnsiChar(LStr)^, LStrLen);
      FWrittenBytes := FWrittenBytes + LStrLen;
    end;
    FQueue.FMessages.Clear;
  finally
    FQueue.UnLock;
  end;
  }
end;

constructor TLogFile.TMessageWriter.Create(const AConfig: TFileLogConfig; AQueue: TMessageQueue);
begin
  inherited Create(True);

  FConfig := AConfig;
  FQueue := AQueue;

  FSleepInterval := 50;
end;

procedure TLogFile.TMessageWriter.Execute;
var
  LStream: TFileStream;
begin
  try
    if FConfig.Append then
      LStream := RecoverLastLog
    else
      LStream := CreateLogFile;

    try
      // Initialize FWrittenBytes to the file size
      FWrittenBytes := LStream.Seek(0, soEnd);
      FExecuting := True;

      while not Terminated do
      begin
        if FQueue.Count > 0 then
        begin
          if FConfig.NeedAnotherLog(FWrittenBytes) then
          begin
            LStream := CreateNextLog(LStream);
            FWrittenBytes := 0;
          end;

          if FConfig.Buffered then
            ConsumeQueueBuffered(LStream)
          else
            ConsumeQueue(LStream);
        end;

        Sleep(FSleepInterval);
      end;
    finally
      LStream.Free;
    end;
  except
    FExecuting := False;
  end;
end;

function TLogFile.TMessageWriter.RecoverLastLog: TFileStream;
var
  LLastLog: string;
  LList: TArray<string>;
begin
  LList := FConfig.GetLogList;

  if Length(LList) = 0 then
    Exit(CreateLogFile);

  LLastLog := LList[Length(LList) - 1];
  try
    Result := TFileStream.Create(LLastLog, fmOpenReadWrite or fmShareDenyWrite);
  except
    Result := CreateLogFile;
  end;
end;

procedure TLogFile.TMessageWriter.Stop;
begin
  FSleepInterval := 2;
end;

function TLogFile.TMessageWriter.CreateLogFile: TFileStream;
var
  LFileName: string;
begin
  LFileName := FConfig.GetFileName;
  Result := TFileStream.Create(LFileName, fmCreate or fmShareDenyWrite);
end;

function TLogFile.TMessageWriter.CreateNextLog(AStream: TFileStream): TFileStream;
begin
  FreeAndNil(AStream);
  Result := CreateLogFile();
end;

{ TLogFile.TRotateTimer }

constructor TLogFile.TRotateTimer.Create(const AConfig: TFileLogConfig);
begin
  inherited Create(True);
  FSignal := TEvent.Create();
  FConfig := AConfig;
  FInterval := 2000;
end;

destructor TLogFile.TRotateTimer.Destroy;
begin
  FSignal.Free;
  inherited;
end;

procedure TLogFile.TRotateTimer.Execute;
begin
  while not Terminated do
    if FSignal.WaitFor(FInterval) = wrTimeout then
      DeleteOldFiles;
end;

procedure TLogFile.TRotateTimer.SignalTermination;
begin
  Terminate;
  FSignal.SetEvent;
end;

procedure TLogFile.TRotateTimer.DeleteOldFiles;
var
  LIndex: Integer;
  LList: TArray<string>;
begin
  LList := FConfig.GetLogList;

  if Length(LList) = 0 then
    Exit;

  for LIndex := 0 to (Length(LList) - FConfig.RotateItems - 1) do
    TFile.Delete(LList[LIndex]);
end;

{ TLogFile.TMessageQueue }

procedure TLogFile.TMessageQueue.Clear;
begin
  Lock;
  try
    FMessages.Clear;
  finally
    UnLock;
  end;
end;

function TLogFile.TMessageQueue.Count: NativeInt;
begin
  Lock;
  try
    Result := FMessages.Count;
  finally
    UnLock;
  end;
end;

constructor TLogFile.TMessageQueue.Create;
begin
  FMessages := TQueue<UTF8String>.Create;
end;

destructor TLogFile.TMessageQueue.Destroy;
begin
  FMessages.Free;
  inherited;
end;

procedure TLogFile.TMessageQueue.Lock;
begin
  TMonitor.Enter(FMessages);
end;

function TLogFile.TMessageQueue.Pop: UTF8String;
begin
  Lock;
  try
    Result := FMessages.Dequeue;
  finally
    UnLock;
  end;
end;

function TLogFile.TMessageQueue.PopAll: TArray<UTF8String>;
//var
//  LStr: string;
begin
  Lock;
  try
    //Result := FMessages.ToArray;

    Result := [];
    while FMessages.Count > 0 do
      Result := Result + [FMessages.Dequeue];

    {
    Result := '';
    for LStr in FMessages do
      Result := Result + LStr;
    FMessages.Clear;
    }
  finally
    UnLock;
  end;
end;

procedure TLogFile.TMessageQueue.Push(const AItem: UTF8String);
begin
  Lock;
  try
    FMessages.Enqueue(AItem);
  finally
    UnLock;
  end;
end;

procedure TLogFile.TMessageQueue.UnLock;
begin
  TMonitor.Exit(FMessages);
end;

{ TFileLogConfig }

function TFileLogConfig.BuildRotateName: string;
begin
  Result := TPath.Combine(FPath, FName) + '_' +
    FormatDateTime(DATETIME_FILENAME, Now) + FExt;
end;

function TFileLogConfig.GetFileName: string;
begin
  case FLogType of
    TLogType.Single:
    begin
      if FFullName.IsEmpty then
        Result := TPath.Combine(FPath, FName) + FExt
      else
        Result := FFullName;
    end;
    TLogType.Rotate: Result := BuildRotateName;
  end;
end;

function TFileLogConfig.GetLogList: TArray<string>;
begin
  if IsRotate then
    Result := TDirectory.GetFiles(FPath, FName + '_*' + FExt)
  else
    Result := TDirectory.GetFiles(FPath, FName + FExt);

  if Length(Result) = 0 then
    Exit;

  TArray.Sort<string>(Result, TComparer<string>.Construct(
    function(const Left, Right: string): Integer
    begin
      Result := TComparer<string>.Default.Compare(Left, Right);
    end)
  );
end;

function TFileLogConfig.IsRotate: Boolean;
begin
  Result := FLogType = TLogType.Rotate;
end;

function TFileLogConfig.NeedAnotherLog(ASize: UInt64): Boolean;
begin
  if (FLogType = TLogType.Rotate) and (ASize > FRotateSize) then
    Result := True
  else
    Result := False;
end;

class function TFileLogConfig.NewRotate(ALevel: TLogLevel; AAppend: Boolean;
  const AName: string; const APath: string; const AExt: string;
  ARotateItems: Integer; ARotateSize: Integer): TFileLogConfig;
begin
  Result.LogType := TLogType.Rotate;
  Result.Level := ALevel;
  Result.Append := AAppend;
  Result.SetLogName(AName);
  Result.Path := APath;
  Result.Ext := AExt;

  Result.RotateItems := ARotateItems;
  Result.RotateSize := ARotateSize;
end;

class function TFileLogConfig.NewSingle(ALevel: TLogLevel; AAppend: Boolean;
  const AName, APath, AExt: string): TFileLogConfig;
begin
  Result.LogType := TLogType.Single;
  Result.Level := ALevel;
  Result.Append := AAppend;
  Result.SetLogName(AName);
  Result.Path := APath;
  Result.Ext := AExt;
end;

procedure TFileLogConfig.SetExt(const Value: string);
begin
  if Value.IsEmpty then
    Exit;

  if Value.StartsWith('.') then
    FExt := Value
  else
    FExt := '.' + Value;
end;

procedure TFileLogConfig.SetPath(const Value: string);
begin
  if Value.IsEmpty then
    Exit;

  FPath := IncludeTrailingPathDelimiter(Value);
  { TODO -opaolo -c : Move to log start 05/03/2025 13:03:46 }
  TDirectory.CreateDirectory(FPath);
end;


procedure TFileLogConfig.SetLogName(const ALogName: string);
begin
  if ALogName.IsEmpty then
  begin
    FName := ExtractFileName(ParamStr(0));
    if FName.Contains('.') then
      FName := FName.Substring(0, FName.LastIndexOf('.'));
  end
  else
    FName := ALogName;
end;

{ TLogifyAdapterFiles }

constructor TLogifyAdapterFiles.Create(const AConfig: TFileLogConfig);
begin
  inherited Create(AConfig.Level);

  FLogger := TLogFile.Create(AConfig);
  InitializeLogger();
end;

destructor TLogifyAdapterFiles.Destroy;
begin
  FinalizeLogger();

  FLogger.Free;
  inherited;
end;

procedure TLogifyAdapterFiles.FinalizeLogger;
begin
  if Assigned(FLogger) then
    FLogger.EndLogging;
end;

function TLogifyAdapterFiles.GetMessagesToWrite: Integer;
begin
  Result := 0;
  if Assigned(FLogger) then
    Result := FLogger.MessagesToWrite;
end;

procedure TLogifyAdapterFiles.InitializeLogger;
begin
  FLogger.StartLogging;
end;

function TLogifyAdapterFiles.InternalGetLogger(const AName: string): TObject;
begin
  Result := FLogger;
end;

procedure TLogifyAdapterFiles.InternalLog(const AMessage, AClassName: string;
    AException: Exception; ALevel: TLogLevel);
begin
  FLogger.AddStr(FormatMsg(AMessage, AClassName, AException, ALevel));
end;

procedure TLogifyAdapterFiles.InternalRaw(const AMessage: string);
begin
  FLogger.AddStr(AMessage);
end;

{ TLogifyAdapterFilesFactory }

class function TLogifyAdapterFilesFactory.CreateAdapterFactory(const AConfig: TFileLogConfig): TLogifyAdapterFilesFactory;
begin
  Result := CreateAdapterFactory('', AConfig);
end;

class function TLogifyAdapterFilesFactory.CreateAdapterFactory(const AName: string;
  const AConfig: TFileLogConfig): TLogifyAdapterFilesFactory;
begin
  Result := TLogifyAdapterFilesFactory.Create();
  Result.Name := AName;
  Result.Config := AConfig;
end;

function TLogifyAdapterFilesFactory.CreateLoggerAdapter: ILoggerAdapter;
begin
  Result := TLogifyAdapterFiles.Create(FConfig);
end;

end.
