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
    DEFAULT_BUFFERED = True;
    DEFAULT_ROTATE_ITEMS = 10;
    DEFAULT_ROTATE_SIZE = 10485760;
    DEFAULT_MAX_QUEUE_SIZE = 100000;
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
    FMaxQueueSize: Integer;
    procedure SetExt(const Value: string);
    procedure SetPath(const Value: string);
    procedure SetMaxQueueSize(const Value: Integer);
    procedure SetRotateSize(const Value: Integer);
    function BuildRotateName: string;
    function GetLogList: TArray<string>;
  public
    /// <summary>
    ///   Runs when any instance of the record comes into existence: a bare
    ///   "var LConfig: TFileLogConfig" used to carry whatever was on the
    ///   stack, which a caller that forgot NewSingle/NewRotate would feed to
    ///   the factory. Now every instance starts as a coherent default.
    /// </summary>
    class operator Initialize(out Dest: TFileLogConfig);

    class function NewSingle(ALevel: TLogLevel; AAppend: Boolean = True;
      const AName: string = ''; const APath: string = '.\logs';
      const AExt: string = '.log'): TFileLogConfig; static;

    class function NewRotate(ALevel: TLogLevel; AAppend: Boolean = True;
      const AName: string = ''; const APath: string = '.\logs';
      const AExt: string = '.log';
      ARotateItems: Integer = 10; ARotateSize: Integer = 10485760): TFileLogConfig; static;
  public
    procedure SetLogSingle(ALevel: TLogLevel; AAppend: Boolean = True;
      const AName: string = ''; const APath: string = '.\logs';
      const AExt: string = '.log');

    procedure SetLogRotate(ALevel: TLogLevel; AAppend: Boolean = True;
      const AName: string = ''; const APath: string = '.\logs';
      const AExt: string = '.log';
      ARotateItems: Integer = 10; ARotateSize: Integer = 10485760);

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
    property RotateSize: Integer read FRotateSize write SetRotateSize;
    property RotateItems: Integer read FRotateItems write FRotateItems;

    /// <summary>
    ///   Most messages allowed to wait for the writer thread. When the disk
    ///   stalls, or the application logs faster than the file can absorb, the
    ///   queue would otherwise grow until the process runs out of memory.
    ///
    ///   Once it is full the oldest waiting messages are dropped, and how
    ///   many were lost is written into the log as soon as it recovers, so
    ///   the gap is never silent.
    ///
    ///   0 removes the limit, and with it the guarantee.
    /// </summary>
    property MaxQueueSize: Integer read FMaxQueueSize write SetMaxQueueSize;
  end;
  TFileLogConfProc = reference to procedure (var AConfig: TFileLogConfig);

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
      FCapacity: Integer;
      FDropped: Integer;
      /// <summary>
      ///   Auto-reset event signalled by every Push: the writer thread sleeps
      ///   on it instead of polling, so an idle logger burns no CPU and a
      ///   single message reaches the file in microseconds, not 50 ms.
      /// </summary>
      FSignal: TEvent;
    public
      /// <summary>ACapacity 0 means no limit</summary>
      constructor Create(ACapacity: Integer);
      destructor Destroy; override;

      procedure Lock; inline;
      procedure UnLock;inline;

      procedure Push(const AItem: UTF8String);
      function Pop: UTF8String;
      function PopAll: TArray<UTF8String>;
      function Count: NativeInt;

      /// <summary>
      ///   How many messages have been dropped since the last call, and
      ///   resets the count. The writer reports them into the log.
      /// </summary>
      function TakeDropped: Integer;
    end;

    /// <summary>
    ///   Message Writer Thread
    /// </summary>
    TMessageWriter = class(TThread)
    private
      FConfig: TFileLogConfig;
      FWrittenBytes: Int64;
      FQueue: TMessageQueue;

      /// <summary>
      ///   Signalled once the thread knows whether it could open its file,
      ///   whichever way it went. StartLogging waits on this instead of
      ///   spinning on a flag that a failed thread would never set.
      /// </summary>
      FReady: TEvent;
      FFailed: Boolean;
      FLastError: string;
      /// <summary>Set by Stop: the buffered stream has to reach the file</summary>
      FFlushRequested: Boolean;

      procedure SetError(const AError: string);
      function GetLastError: string;

      function RecoverLastLog: TFileStream;
      function CreateLogFile: TFileStream;
      function CreateNextLog(AStream: TFileStream): TFileStream;
      function OpenStream(const AFileName: string; AMode: Word): TFileStream;
      procedure FlushStream(AStream: TFileStream);

      procedure WriteRecord(var AStream: TFileStream; const AMessage: UTF8String);
      procedure ConsumeAvailable(var AStream: TFileStream);
      procedure ConsumeQueue(var AStream: TFileStream);
      procedure ConsumeQueueBuffered(var AStream: TFileStream);
    protected
      procedure Execute; override;
      procedure TerminatedSet; override;
      procedure Stop;
    public
      constructor Create(const AConfig: TFileLogConfig; AQueue: TMessageQueue);
      destructor Destroy; override;

      /// <summary>
      ///   Waits for the thread to report the outcome of its startup.
      ///   False means it did not report in time.
      /// </summary>
      function WaitForStartup(ATimeout: Cardinal): Boolean;

      property Failed: Boolean read FFailed;
      property LastError: string read GetLastError;
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

  private const
    /// <summary>How long StartLogging waits for the writer to come up</summary>
    STARTUP_TIMEOUT = 5000;
    /// <summary>How long EndLogging waits for the queue to reach the file</summary>
    DRAIN_TIMEOUT = 5000;
  private
    FConfig: TFileLogConfig;
    FStarted: Boolean;
    FLastError: string;
    FQueue: TMessageQueue;
    FWriter: TMessageWriter;
    FRotateTimer: TRotateTimer;
    procedure SetLastError(const AError: string);
    function GetLastError: string;
    function GetStarted: Boolean;
    function GetMessagesToWrite: NativeInt;
  public
    constructor Create(const AConfig: TFileLogConfig);
    destructor Destroy; override;

    procedure StartLogging;
    procedure EndLogging;

    procedure AddStr(const AString: string);

    property MessagesToWrite: NativeInt read GetMessagesToWrite;

    /// <summary>
    ///   False when the writer thread could not open its file, or once
    ///   EndLogging has stopped the logger. The logger then drops messages
    ///   instead of queueing them.
    /// </summary>
    property Started: Boolean read GetStarted;
    property LastError: string read GetLastError;
  end;

  // ***********
  // Logify Adapter & Factory
  // ***********

  /// <summary>
  ///   Adapter for the Logify framework
  /// </summary>
  TLogifyAdapterFiles = class(TLoggerAdapterHelper, ILoggerAdapter)
  private
    FLogger: TLogFile;
  protected
    procedure InternalLog(const AMessage, AClassName: string; AException: Exception; ALevel: TLogLevel); override;
    procedure InternalRaw(const AMessage: string; ALevel: TLogLevel); override;
  public
    constructor Create(const AConfig: TFileLogConfig);
    destructor Destroy; override;

    procedure InitializeLogger; virtual;
    procedure FinalizeLogger; virtual;

    function GetMessagesToWrite: NativeInt;

    /// <summary>
    ///   False when the writer thread could not open its file. The adapter
    ///   then discards what it is given rather than failing the caller, so
    ///   this is the only way to find out.
    /// </summary>
    function IsStarted: Boolean;
    function LastError: string;
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

    class function CreateAdapterFactory(const AName: string; AConfProc: TFileLogConfProc): TLogifyAdapterFilesFactory; overload;
  public
    property Config: TFileLogConfig read FConfig write FConfig;
    function CreateLoggerAdapter: ILoggerAdapter; override;
  end;


implementation

uses
  System.IOUtils;

resourcestring
  /// <summary>
  ///   Written in place of the messages that did not fit. A gap in a log has
  ///   to be visible, otherwise the file quietly misleads whoever reads it.
  /// </summary>
  SMessagesDropped = '*** %d message(s) dropped: the log queue was full ***';
  SWriterDidNotStart = 'The log writer did not start within %d ms';

constructor TLogFile.Create(const AConfig: TFileLogConfig);
begin
  FConfig := AConfig;

  FQueue := TMessageQueue.Create(AConfig.MaxQueueSize);

  FWriter  := TMessageWriter.Create(AConfig, FQueue);
  FRotateTimer := TRotateTimer.Create(AConfig);
end;

destructor TLogFile.Destroy;
begin
  // Anything still queued belongs in the file, whether or not EndLogging was
  // called for us
  EndLogging;

  if Assigned(FRotateTimer) then
  begin
    // SignalTermination, not Terminate: the timer sleeps on its event, and a
    // bare Terminate would leave shutdown waiting out the whole interval.
    FRotateTimer.SignalTermination();
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

procedure TLogFile.SetLastError(const AError: string);
begin
  // LastError is polled from other threads (through the adapter) while a
  // retry may be writing it: a plain assignment would race on the string's
  // refcount.
  TMonitor.Enter(Self);
  try
    FLastError := AError;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TLogFile.GetLastError: string;
begin
  TMonitor.Enter(Self);
  try
    Result := FLastError;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TLogFile.GetStarted: Boolean;
begin
  // FStarted is written by StartLogging once the startup event has fired and
  // read on every log call from every thread; an Interlocked read keeps the
  // flag coherent without a lock on the hot path.
  Result := TInterlocked.CompareExchange(FStarted, False, False);
end;

procedure TLogFile.EndLogging;
var
  LWatch: TStopwatch;
begin
  // Stop accepting first: everything already queued is drained below, and no
  // producer can keep feeding the drain while it runs. A second call (or the
  // destructor) sees FStarted already cleared and returns immediately.
  if TInterlocked.Exchange(FStarted, False) = False then
    Exit;

  // Wake the writer and give it a bounded window to put the queue on disk.
  // Without this the messages logged just before shutdown, the interesting
  // ones, are the ones that never arrive.
  FWriter.Stop;

  LWatch := TStopwatch.StartNew;
  while (FQueue.Count > 0) and (LWatch.ElapsedMilliseconds < DRAIN_TIMEOUT) do
    Sleep(5);
end;

procedure TLogFile.StartLogging;
begin
  if GetStarted then
    Exit;

  // The writer thread can only be started once: TThread.Start raises on a
  // second call, so a retry after a failed or timed-out startup has to leave
  // the already-started thread alone and re-check its outcome instead.
  if not FWriter.Started then
    FWriter.Start;

  // Bounded, and driven by an event: a writer that cannot open its file used
  // to leave this spinning forever, which froze the first call to log.
  if not FWriter.WaitForStartup(STARTUP_TIMEOUT) then
  begin
    SetLastError(Format(SWriterDidNotStart, [STARTUP_TIMEOUT]));
    Exit;
  end;

  if FWriter.Failed then
  begin
    SetLastError(FWriter.LastError);
    Exit;
  end;

  // EndLogging may have stopped the logger; a restart has to leave the
  // already-started threads alone, exactly like the writer above.
  if (FConfig.LogType = TLogType.Rotate) and (not FRotateTimer.Started) then
    FRotateTimer.Start;

  TInterlocked.Exchange(FStarted, True);
end;

procedure TLogFile.AddStr(const AString: string);
var
  LLength: Integer;
begin
  // Nobody is consuming: queueing would only grow the queue for the lifetime
  // of the process
  if not GetStarted then
    Exit;

  // Normalize the line ending: a message already ending in #10/#13 (Unix
  // style, or a bare CR) is stripped and re-terminated with the platform's
  // break, so the file never mixes CRLF with other line endings.
  LLength := Length(AString);
  if (LLength > 0) and CharInSet(AString[LLength], [#10, #13]) then
  begin
    while (LLength > 0) and CharInSet(AString[LLength], [#10, #13]) do
      Dec(LLength);
    FQueue.Push(UTF8String(Copy(AString, 1, LLength) + sLineBreak));
    Exit;
  end;

  FQueue.Push(UTF8String(AString + sLineBreak));
end;

function TLogFile.GetMessagesToWrite: NativeInt;
begin
  Result := FQueue.Count;
end;

{ TMessageWriter }

procedure TLogFile.TMessageWriter.WriteRecord(var AStream: TFileStream; const AMessage: UTF8String);
var
  LLength: Integer;
begin
  LLength := Length(AMessage);
  if LLength = 0 then
    Exit;

  // Checked per record, not once per batch: a single buffered write can carry
  // far more than RotateSize, and the file would grow without any limit.
  if FConfig.NeedAnotherLog(FWrittenBytes) then
  begin
    AStream := CreateNextLog(AStream);
    FWrittenBytes := 0;
  end;

  AStream.WriteBuffer(PAnsiChar(AMessage)^, LLength);
  FWrittenBytes := FWrittenBytes + LLength;
end;

procedure TLogFile.TMessageWriter.ConsumeAvailable(var AStream: TFileStream);
var
  LDropped: Integer;
begin
  // Reported before the batch, which is where the gap actually is: the
  // messages that were dropped are older than everything still queued.
  LDropped := FQueue.TakeDropped;
  if LDropped > 0 then
    WriteRecord(AStream, UTF8String(Format(SMessagesDropped, [LDropped]) + sLineBreak));

  if FQueue.Count = 0 then
    Exit;

  if FConfig.Buffered then
    ConsumeQueueBuffered(AStream)
  else
    ConsumeQueue(AStream);
end;

procedure TLogFile.TMessageWriter.ConsumeQueue(var AStream: TFileStream);
var
  LPending: NativeInt;
begin
  // Bounded by the count observed on entry, so a fast producer cannot keep
  // this loop running forever, but everything already queued is written now
  // instead of one record per sleep interval.
  LPending := FQueue.Count;
  while (LPending > 0) and (FQueue.Count > 0) do
  begin
    WriteRecord(AStream, FQueue.Pop);
    Dec(LPending);
  end;
end;

procedure TLogFile.TMessageWriter.ConsumeQueueBuffered(var AStream: TFileStream);
var
  LStr: UTF8String;
begin
  // One trip through the lock for the whole batch, then the records are
  // written outside it
  for LStr in FQueue.PopAll do
    WriteRecord(AStream, LStr);
end;

constructor TLogFile.TMessageWriter.Create(const AConfig: TFileLogConfig; AQueue: TMessageQueue);
begin
  inherited Create(True);

  FConfig := AConfig;
  FQueue := AQueue;
  FReady := TEvent.Create(nil, True, False, '');
end;

destructor TLogFile.TMessageWriter.Destroy;
begin
  // inherited first: it terminates and waits for the thread, which is still
  // allowed to touch FReady until then
  inherited;
  FReady.Free;
end;

function TLogFile.TMessageWriter.WaitForStartup(ATimeout: Cardinal): Boolean;
begin
  Result := FReady.WaitFor(ATimeout) = wrSignaled;
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
  except
    on E: Exception do
    begin
      // The caller is waiting: it has to be told that the file never opened,
      // otherwise it waits for a thread that is about to disappear.
      SetError(E.ClassName + ': ' + E.Message);
      FFailed := True;
      FReady.SetEvent;
      Exit;
    end;
  end;

  try
    // Initialize FWrittenBytes to the file size
    FWrittenBytes := LStream.Seek(0, soEnd);
    FReady.SetEvent;

    while not Terminated do
    begin
      try
        ConsumeAvailable(LStream);
        // EndLogging asked for the queue to reach the file: push whatever is
        // still sitting in the stream buffer.
        if TInterlocked.Exchange(FFlushRequested, False) then
          FlushStream(LStream);
      except
        on E: Exception do
          // A failing write (disk full, file removed underneath us) must not
          // kill the thread: the next pass tries again.
          SetError(E.ClassName + ': ' + E.Message);
      end;

      // Sleep until a push, a Stop or a Terminate wakes us: no polling, no
      // idle CPU, and no latency from a fixed sleep interval.
      FQueue.FSignal.WaitFor;
    end;

    // Terminated. Whatever is still queued was accepted from the caller and
    // has to reach the file before the stream goes away.
    try
      ConsumeAvailable(LStream);
    except
      on E: Exception do
        SetError(E.ClassName + ': ' + E.Message);
    end;
  finally
    LStream.Free;
  end;
end;

procedure TLogFile.TMessageWriter.TerminatedSet;
begin
  inherited;
  // The loop sleeps on the queue's event: without this it would never notice
  // the termination request and WaitFor would hang.
  FQueue.FSignal.SetEvent;
end;

procedure TLogFile.TMessageWriter.SetError(const AError: string);
begin
  // LastError is polled from other threads while the writer thread keeps
  // failing: a plain assignment would race on the string's refcount.
  TMonitor.Enter(Self);
  try
    FLastError := AError;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TLogFile.TMessageWriter.GetLastError: string;
begin
  TMonitor.Enter(Self);
  try
    Result := FLastError;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TLogFile.TMessageWriter.RecoverLastLog: TFileStream;
var
  LLastLog: string;
  LList: TArray<string>;
begin
  // A FullName points at one specific file, possibly outside FPath, so the
  // GetLogList pattern can never match it. Append to it directly, falling
  // back to creating it when it does not exist yet: without this, append mode
  // truncated the FullName file on every restart (or wrote to a stray
  // FName+FExt file instead).
  if (FConfig.LogType = TLogType.Single) and (not FConfig.FullName.IsEmpty) then
  begin
    try
      Result := OpenStream(FConfig.FullName, fmOpenReadWrite or fmShareDenyWrite);
    except
      Result := CreateLogFile;
    end;
    Exit;
  end;

  LList := FConfig.GetLogList;

  if Length(LList) = 0 then
    Exit(CreateLogFile);

  LLastLog := LList[Length(LList) - 1];
  try
    Result := OpenStream(LLastLog, fmOpenReadWrite or fmShareDenyWrite);
  except
    Result := CreateLogFile;
  end;
end;

procedure TLogFile.TMessageWriter.Stop;
begin
  // EndLogging: wake the writer and ask it to push whatever is still sitting
  // in the stream buffer to the file.
  TInterlocked.Exchange(FFlushRequested, True);
  FQueue.FSignal.SetEvent;
end;

function TLogFile.TMessageWriter.CreateLogFile: TFileStream;
var
  LFileName: string;
begin
  LFileName := FConfig.GetFileName;
  Result := OpenStream(LFileName, fmCreate or fmShareDenyWrite);
end;

function TLogFile.TMessageWriter.OpenStream(const AFileName: string; AMode: Word): TFileStream;
begin
  // Buffered mode batches the file I/O too: records accumulate in the
  // stream's buffer and reach the disk in chunks instead of one WriteFile
  // syscall per record. The buffer is flushed when it fills, when the file
  // rotates, when Stop asks for it, and when the stream closes.
  if FConfig.Buffered then
    Result := TBufferedFileStream.Create(AFileName, AMode)
  else
    Result := TFileStream.Create(AFileName, AMode);
end;

procedure TLogFile.TMessageWriter.FlushStream(AStream: TFileStream);
begin
  if AStream is TBufferedFileStream then
    TBufferedFileStream(AStream).FlushBuffer;
end;

function TLogFile.TMessageWriter.CreateNextLog(AStream: TFileStream): TFileStream;
begin
  // The new stream first: if creating it fails, the caller keeps writing to
  // the old one instead of holding a pointer that has already been freed.
  Result := CreateLogFile();
  AStream.Free;
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
  LKeep: Integer;
  LList: TArray<string>;
begin
  LList := FConfig.GetLogList;

  if Length(LList) = 0 then
    Exit;

  // At least one has to survive: the newest is the file the writer thread
  // currently holds open, and RotateItems <= 0 would put it in range.
  LKeep := FConfig.RotateItems;
  if LKeep < 1 then
    LKeep := 1;

  for LIndex := 0 to (Length(LList) - LKeep - 1) do
  try
    TFile.Delete(LList[LIndex]);
  except
    // Still open, or not ours to delete. Leaving it for the next pass beats
    // letting the exception escape Execute and kill the thread, which would
    // silently stop all cleanup for the rest of the process.
  end;
end;

{ TLogFile.TMessageQueue }

function TLogFile.TMessageQueue.Count: NativeInt;
begin
  Lock;
  try
    Result := FMessages.Count;
  finally
    UnLock;
  end;
end;

constructor TLogFile.TMessageQueue.Create(ACapacity: Integer);
begin
  FMessages := TQueue<UTF8String>.Create;
  FSignal := TEvent.Create(nil, False, False, '');
  FCapacity := ACapacity;
end;

destructor TLogFile.TMessageQueue.Destroy;
begin
  FMessages.Free;
  FSignal.Free;
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
begin
  Lock;
  try
    // One allocation for the whole batch: appending one element at a time
    // ("Result := Result + [...]") copies the whole array on every iteration,
    // O(n^2) total, which stalled the writer thread for seconds when a full
    // queue drained.
    Result := FMessages.ToArray;
    FMessages.Clear;
  finally
    UnLock;
  end;
end;

procedure TLogFile.TMessageQueue.Push(const AItem: UTF8String);
begin
  Lock;
  try
    // Full: make room by dropping the oldest waiting messages. When a log is
    // overflowing it is the newest records that explain what is going on, and
    // blocking the caller would make the logger a liability to the program
    // it is supposed to be observing.
    if FCapacity > 0 then
      while FMessages.Count >= FCapacity do
      begin
        FMessages.Dequeue;
        TInterlocked.Increment(FDropped);
      end;

    FMessages.Enqueue(AItem);
  finally
    UnLock;
  end;

  // Wake the writer: signalling outside the lock keeps the producers from
  // contending with the consumer for it, and an auto-reset event means one
  // signal covers any number of messages that arrived since the last drain.
  FSignal.SetEvent;
end;

function TLogFile.TMessageQueue.TakeDropped: Integer;
begin
  // Interlocked rather than the queue lock: the writer asks on every pass,
  // and there is no reason to contend with the producers for that.
  Result := TInterlocked.Exchange(FDropped, 0);
end;

procedure TLogFile.TMessageQueue.UnLock;
begin
  TMonitor.Exit(FMessages);
end;

{ TFileLogConfig }

function TFileLogConfig.BuildRotateName: string;
var
  LBase: string;
  LIndex: Integer;
begin
  LBase := TPath.Combine(FPath, FName) + '_' + FormatDateTime(DATETIME_FILENAME, Now);

  // The stamp only resolves to the second, and the file is opened with
  // fmCreate: rotating twice inside one second would truncate the file just
  // rotated out. A suffix keeps every generation.
  //
  // Zero padded, because GetLogList sorts the names as text and the retention
  // pass deletes from the front: unpadded, _10 would sort before _2 and the
  // file currently being written could end up inside the delete range.
  Result := LBase + FExt;
  LIndex := 1;
  while TFile.Exists(Result) do
  begin
    Result := LBase + Format('_%.3d', [LIndex]) + FExt;
    Inc(LIndex);
  end;
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
  Result.SetLogRotate(ALevel, AAppend, AName, APath, AExt, ARotateItems, ARotateSize);
end;

class function TFileLogConfig.NewSingle(ALevel: TLogLevel; AAppend: Boolean;
  const AName, APath, AExt: string): TFileLogConfig;
begin
  Result.SetLogSingle(ALevel, AAppend, AName, APath, AExt);
end;

class operator TFileLogConfig.Initialize(out Dest: TFileLogConfig);
begin
  // Same defaults as SetLogSingle: a record created by hand (without
  // NewSingle/NewRotate) used to carry whatever was on the stack in its
  // non-managed fields, silently misconfiguring the adapter.
  Dest.FLogType := TLogType.Single;
  Dest.FAppend := True;
  Dest.FBuffered := DEFAULT_BUFFERED;
  Dest.FExt := '';
  Dest.FFullName := '';
  Dest.FName := '';
  Dest.FPath := '';
  Dest.FLevel := TLogLevel.Info;
  Dest.FRotateSize := DEFAULT_ROTATE_SIZE;
  Dest.FRotateItems := DEFAULT_ROTATE_ITEMS;
  Dest.FMaxQueueSize := DEFAULT_MAX_QUEUE_SIZE;
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

procedure TFileLogConfig.SetMaxQueueSize(const Value: Integer);
begin
  if Value < 0 then
    FMaxQueueSize := 0
  else
    FMaxQueueSize := Value;
end;

procedure TFileLogConfig.SetRotateSize(const Value: Integer);
begin
  // A size of 0 or less would rotate on every single record, one file per
  // message and endless retention churn: fall back to the default instead.
  if Value < 1 then
    FRotateSize := DEFAULT_ROTATE_SIZE
  else
    FRotateSize := Value;
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

procedure TFileLogConfig.SetLogRotate(ALevel: TLogLevel; AAppend: Boolean =
    True; const AName: string = ''; const APath: string = '.\logs'; const AExt:
    string = '.log'; ARotateItems: Integer = 10; ARotateSize: Integer =
    10485760);
begin
  Self.LogType := TLogType.Rotate;
  Self.Level := ALevel;
  Self.Append := AAppend;
  Self.Buffered := DEFAULT_BUFFERED;
  Self.MaxQueueSize := DEFAULT_MAX_QUEUE_SIZE;
  Self.SetLogName(AName);
  Self.Path := APath;
  Self.Ext := AExt;

  Self.RotateItems := ARotateItems;
  Self.RotateSize := ARotateSize;
end;

procedure TFileLogConfig.SetLogSingle(ALevel: TLogLevel; AAppend: Boolean =
    True; const AName: string = ''; const APath: string = '.\logs'; const AExt:
    string = '.log');
begin
  Self.LogType := TLogType.Single;
  Self.Level := ALevel;
  Self.Append := AAppend;
  Self.Buffered := DEFAULT_BUFFERED;
  Self.MaxQueueSize := DEFAULT_MAX_QUEUE_SIZE;
  Self.SetLogName(AName);
  Self.Path := APath;
  Self.Ext := AExt;

  // Unused while the type is Single, but a record result only has its managed
  // fields initialized: leaving these two holding stack garbage means a later
  // switch to Rotate rotates on a nonsense size.
  Self.RotateItems := DEFAULT_ROTATE_ITEMS;
  Self.RotateSize := DEFAULT_ROTATE_SIZE;
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

function TLogifyAdapterFiles.GetMessagesToWrite: NativeInt;
begin
  Result := 0;
  if Assigned(FLogger) then
    Result := FLogger.MessagesToWrite;
end;

function TLogifyAdapterFiles.IsStarted: Boolean;
begin
  Result := Assigned(FLogger) and FLogger.Started;
end;

function TLogifyAdapterFiles.LastError: string;
begin
  Result := '';
  if Assigned(FLogger) then
    Result := FLogger.LastError;
end;

procedure TLogifyAdapterFiles.InitializeLogger;
begin
  FLogger.StartLogging;
end;

procedure TLogifyAdapterFiles.InternalLog(const AMessage, AClassName: string;
    AException: Exception; ALevel: TLogLevel);
begin
  FLogger.AddStr(FormatMsg(AMessage, AClassName, AException, ALevel));
end;

procedure TLogifyAdapterFiles.InternalRaw(const AMessage: string; ALevel: TLogLevel);
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

class function TLogifyAdapterFilesFactory.CreateAdapterFactory(const AName:
    string; AConfProc: TFileLogConfProc): TLogifyAdapterFilesFactory;
var
  LConfig: TFileLogConfig;
begin
  LConfig := TFileLogConfig.NewSingle(TLogLevel.Info);
  AConfProc(LConfig);
  Result := CreateAdapterFactory(AName, LConfig);
end;

function TLogifyAdapterFilesFactory.CreateLoggerAdapter: ILoggerAdapter;
begin
  Result := TLogifyAdapterFiles.Create(FConfig);
end;

end.
