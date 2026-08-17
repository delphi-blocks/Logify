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

/// <summary>
///   The file adapter writes from a background thread, so what matters is not
///   only that a message is formatted correctly but that it survives the trip:
///   these tests read the files back.
/// </summary>
unit Logify.Tests.Files;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Diagnostics,
  DUnitX.TestFramework,
  Logify,
  Logify.Adapter.Files;

type
  [TestFixture]
  TFileAdapterTests = class
  private const
    MESSAGES = 2000;
    // The default TFileLogConfig.MaxQueueSize, and the scale at which the
    // queue drain has to stay fast: a full queue is drained in one pass.
    FULL_QUEUE = 100000;
    LOG_NAME = 'test';
  private
    FDir: string;
    FAdapter: ILoggerAdapter;
    // Procedures, not functions: a discarded interface result stays alive in a
    // hidden temporary until the calling method returns, which would keep the
    // adapter, and its file, open for the whole test.
    procedure NewAdapter(ABuffered: Boolean); overload;
    procedure NewAdapter(ABuffered: Boolean; AMaxQueueSize: Integer); overload;
    procedure NewRotatingAdapter(ARotateSize, ARotateItems: Integer);
    procedure NewAppendAdapter(const AFullName: string);
    procedure Release;
    function LogFiles: TArray<string>;
    function TotalLines: Integer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // Nothing may be lost between the caller and the file
    [Test]
    procedure EveryMessageSurvivesAnImmediateShutdown;
    [Test]
    procedure EveryMessageSurvivesUnbuffered;
    [Test]
    procedure TheQueueIsEmptyOnceTheAdapterIsGone;

    // Rotation
    [Test]
    procedure NoFileGrowsFarBeyondTheRotateSize;
    [Test]
    procedure RotationsInsideTheSameSecondDoNotOverwriteEachOther;
    [Test]
    procedure NothingIsLostAcrossRotations;
    [Test]
    procedure RetentionKeepsTheFileBeingWritten;

    // Failure
    [Test]
    procedure AWriterThatCannotOpenItsFileDoesNotBlockTheCaller;
    [Test]
    procedure AFailedWriterReportsWhyAndDropsMessages;

    // Append + FullName: the file to continue is the one the config names,
    // not whatever the pattern happens to find
    [Test]
    procedure AppendContinuesTheFullNameFileAcrossRestarts;
    [Test]
    procedure AppendWithFullNamePrefersItOverPatternFiles;

    // A queue that cannot grow without limit
    [Test]
    procedure AFullQueueDropsInsteadOfGrowing;
    [Test]
    procedure DroppedMessagesAreReportedInTheLog;
    [Test]
    procedure AZeroLimitKeepsEverything;
    [Test]
    procedure EveryMessageSurvivesAtTheDefaultQueueLimit;

    // Configuration
    [Test]
    procedure ASingleConfigurationIsFullyInitialized;
    [Test]
    procedure ARotateConfigurationIsFullyInitialized;
  end;

implementation

uses
  Logify.Tests.Core;

{ TFileAdapterTests }

procedure TFileAdapterTests.Setup;
begin
  FDir := TPath.Combine(TPath.GetTempPath, 'logify-tests-' + UniqueName);
  if TDirectory.Exists(FDir) then
    TDirectory.Delete(FDir, True);
end;

procedure TFileAdapterTests.TearDown;
begin
  Release;
  if TDirectory.Exists(FDir) then
    try
      TDirectory.Delete(FDir, True);
    except
      // a stray temp directory is not worth failing a test over
    end;
end;

procedure TFileAdapterTests.NewAdapter(ABuffered: Boolean);
begin
  NewAdapter(ABuffered, 0);
end;

procedure TFileAdapterTests.NewAdapter(ABuffered: Boolean; AMaxQueueSize: Integer);
var
  LFactory: ILoggerAdapterFactory;
  LDir: string;
  LLimit: Integer;
begin
  LDir := FDir;
  LLimit := AMaxQueueSize;
  LFactory := TLogifyAdapterFilesFactory.CreateAdapterFactory(UniqueName,
    procedure(var AConfig: TFileLogConfig)
    begin
      AConfig.Level := TLogLevel.Trace;
      AConfig.Append := False;
      AConfig.Buffered := ABuffered;
      AConfig.MaxQueueSize := LLimit;
      AConfig.SetLogName(LOG_NAME);
      AConfig.Path := LDir;
      AConfig.Ext := 'log';
    end);

  FAdapter := LFactory.CreateLoggerAdapter;
end;

procedure TFileAdapterTests.NewRotatingAdapter(ARotateSize, ARotateItems: Integer);
var
  LFactory: ILoggerAdapterFactory;
  LDir: string;
begin
  LDir := FDir;
  LFactory := TLogifyAdapterFilesFactory.CreateAdapterFactory(UniqueName,
    procedure(var AConfig: TFileLogConfig)
    begin
      AConfig.SetLogRotate(TLogLevel.Trace, False, LOG_NAME, LDir, 'log',
        ARotateItems, ARotateSize);
    end);

  FAdapter := LFactory.CreateLoggerAdapter;
end;

procedure TFileAdapterTests.NewAppendAdapter(const AFullName: string);
var
  LFactory: ILoggerAdapterFactory;
  LDir: string;
begin
  LDir := FDir;
  LFactory := TLogifyAdapterFilesFactory.CreateAdapterFactory(UniqueName,
    procedure(var AConfig: TFileLogConfig)
    begin
      AConfig.SetLogSingle(TLogLevel.Trace, True, LOG_NAME, LDir, 'log');
      AConfig.FullName := AFullName;
    end);

  FAdapter := LFactory.CreateLoggerAdapter;
end;

procedure TFileAdapterTests.Release;
begin
  // Releasing the last reference destroys the adapter, which has to flush
  FAdapter := nil;
end;

function TFileAdapterTests.LogFiles: TArray<string>;
begin
  if not TDirectory.Exists(FDir) then
    Exit(nil);

  Result := TDirectory.GetFiles(FDir, LOG_NAME + '*.log');
end;

function TFileAdapterTests.TotalLines: Integer;
var
  LFile: string;
begin
  Result := 0;
  for LFile in LogFiles do
    Inc(Result, Length(TFile.ReadAllLines(LFile)));
end;

procedure TFileAdapterTests.EveryMessageSurvivesAnImmediateShutdown;
var
  LIndex: Integer;
begin
  NewAdapter(True);
  for LIndex := 1 to MESSAGES do
    FAdapter.WriteLog('', 'line ' + LIndex.ToString, nil, TLogLevel.Info);

  // No grace period on purpose: the messages logged just before shutdown are
  // the ones that used to be thrown away wholesale
  Release;

  Assert.AreEqual(MESSAGES, TotalLines);
end;

procedure TFileAdapterTests.EveryMessageSurvivesUnbuffered;
var
  LIndex: Integer;
begin
  NewAdapter(False);
  for LIndex := 1 to MESSAGES do
    FAdapter.WriteLog('', 'line ' + LIndex.ToString, nil, TLogLevel.Info);
  Release;

  // Unbuffered used to write one record per sleep interval, so this many
  // messages would have needed a minute and a half
  Assert.AreEqual(MESSAGES, TotalLines);
end;

procedure TFileAdapterTests.TheQueueIsEmptyOnceTheAdapterIsGone;
var
  LFiles: TLogifyAdapterFiles;
  LIndex: Integer;
begin
  NewAdapter(True);
  LFiles := FAdapter as TObject as TLogifyAdapterFiles;

  for LIndex := 1 to MESSAGES do
    FAdapter.WriteLog('', 'line ' + LIndex.ToString, nil, TLogLevel.Info);

  LFiles.FinalizeLogger;

  Assert.AreEqual(0, LFiles.GetMessagesToWrite,
    'FinalizeLogger has to leave the queue on disk, not in memory');
end;

procedure TFileAdapterTests.NoFileGrowsFarBeyondTheRotateSize;
var
  LIndex: Integer;
  LFile: string;
  LSize: Int64;
begin
  NewRotatingAdapter(2000, 500);
  for LIndex := 1 to MESSAGES do
    FAdapter.WriteLog('', 'a line of a reasonable length, number ' + LIndex.ToString, nil, TLogLevel.Info);
  Release;

  for LFile in LogFiles do
  begin
    LSize := TFile.GetSize(LFile);
    // One record of overshoot is expected: the size is checked before writing
    Assert.IsTrue(LSize <= 2000 + 500,
      Format('%s is %d bytes, the limit is 2000', [TPath.GetFileName(LFile), LSize]));
  end;
end;

procedure TFileAdapterTests.RotationsInsideTheSameSecondDoNotOverwriteEachOther;
var
  LIndex: Integer;
begin
  // Small files and a fast feed: many rotations land inside the same second,
  // and the name only resolves to the second
  NewRotatingAdapter(1000, 500);
  for LIndex := 1 to MESSAGES do
    FAdapter.WriteLog('', 'a line of a reasonable length, number ' + LIndex.ToString, nil, TLogLevel.Info);
  Release;

  Assert.IsTrue(Length(LogFiles) > 5,
    Format('only %d files: generations are overwriting each other', [Length(LogFiles)]));
end;

procedure TFileAdapterTests.NothingIsLostAcrossRotations;
var
  LIndex: Integer;
begin
  // Retention high enough that nothing is deleted, so every line must be found
  NewRotatingAdapter(1000, 1000);
  for LIndex := 1 to MESSAGES do
    FAdapter.WriteLog('', 'a line of a reasonable length, number ' + LIndex.ToString, nil, TLogLevel.Info);
  Release;

  Assert.AreEqual(MESSAGES, TotalLines);
end;

procedure TFileAdapterTests.RetentionKeepsTheFileBeingWritten;
var
  LIndex: Integer;
  LFiles: TArray<string>;
begin
  NewRotatingAdapter(1000, 5);
  for LIndex := 1 to MESSAGES do
    FAdapter.WriteLog('', 'a line of a reasonable length, number ' + LIndex.ToString, nil, TLogLevel.Info);

  // The retention pass runs on its own thread every couple of seconds
  Sleep(2500);
  LFiles := LogFiles;
  Release;

  Assert.IsTrue(Length(LFiles) > 0, 'retention deleted every file, including the live one');
end;

procedure TFileAdapterTests.AWriterThatCannotOpenItsFileDoesNotBlockTheCaller;
var
  LWatch: TStopwatch;
begin
  // A directory sitting exactly where the log file wants to be
  TDirectory.CreateDirectory(FDir);
  TDirectory.CreateDirectory(TPath.Combine(FDir, LOG_NAME + '.log'));

  LWatch := TStopwatch.StartNew;
  NewAdapter(True);
  FAdapter.WriteLog('', 'into the void', nil, TLogLevel.Info);
  Release;
  LWatch.Stop;

  Assert.IsTrue(LWatch.ElapsedMilliseconds < 10000,
    Format('took %d ms: a writer that cannot open its file used to spin forever',
      [LWatch.ElapsedMilliseconds]));
end;

procedure TFileAdapterTests.AFailedWriterReportsWhyAndDropsMessages;
var
  LFiles: TLogifyAdapterFiles;
begin
  TDirectory.CreateDirectory(FDir);
  TDirectory.CreateDirectory(TPath.Combine(FDir, LOG_NAME + '.log'));

  NewAdapter(True);
  LFiles := FAdapter as TObject as TLogifyAdapterFiles;
  FAdapter.WriteLog('', 'into the void', nil, TLogLevel.Info);

  Assert.IsFalse(LFiles.IsStarted, 'the writer cannot have started');
  Assert.IsNotEmpty(LFiles.LastError, 'the reason has to be reachable');
  Assert.AreEqual(0, LFiles.GetMessagesToWrite,
    'messages must be dropped, not queued for a thread that will never run');
end;

procedure TFileAdapterTests.AppendContinuesTheFullNameFileAcrossRestarts;
var
  LFullName: string;
begin
  // FullName lives outside the pattern directory, so GetLogList can never see
  // it: the second adapter has to continue the same file, not recreate it
  LFullName := TPath.Combine(TPath.Combine(FDir, 'elsewhere'), 'custom.log');
  TDirectory.CreateDirectory(TPath.GetDirectoryName(LFullName));

  NewAppendAdapter(LFullName);
  FAdapter.WriteLog('', 'first life', nil, TLogLevel.Info);
  Release;

  // Same configuration, new "process"
  NewAppendAdapter(LFullName);
  FAdapter.WriteLog('', 'second life', nil, TLogLevel.Info);
  Release;

  Assert.Contains(TFile.ReadAllText(LFullName), 'first life');
  Assert.Contains(TFile.ReadAllText(LFullName), 'second life');
  Assert.AreEqual(2, Length(TFile.ReadAllLines(LFullName)));
end;

procedure TFileAdapterTests.AppendWithFullNamePrefersItOverPatternFiles;
var
  LFullName: string;
  LPatternFile: string;
begin
  // A file matching the pattern exists in the configured path: append mode has
  // to follow FullName, not grab the first pattern match
  LFullName := TPath.Combine(TPath.Combine(FDir, 'elsewhere'), 'custom.log');
  TDirectory.CreateDirectory(TPath.GetDirectoryName(LFullName));

  NewAppendAdapter(LFullName);
  FAdapter.WriteLog('', 'first life', nil, TLogLevel.Info);
  Release;

  // A decoy the pattern would match
  LPatternFile := TPath.Combine(FDir, LOG_NAME + '.log');
  TFile.WriteAllText(LPatternFile, 'decoy' + sLineBreak);

  NewAppendAdapter(LFullName);
  FAdapter.WriteLog('', 'second life', nil, TLogLevel.Info);
  Release;

  Assert.Contains(TFile.ReadAllText(LFullName), 'second life',
    'the second session has to keep using the FullName file');
  Assert.IsFalse(TFile.ReadAllText(LPatternFile).Contains('second life'),
    'the pattern file must not steal the log');
end;

procedure TFileAdapterTests.AFullQueueDropsInsteadOfGrowing;
var
  LFiles: TLogifyAdapterFiles;
  LIndex: Integer;
begin
  // A queue of one, filled far faster than the writer's poll interval: almost
  // every message has to be dropped rather than queued
  NewAdapter(True, 1);
  LFiles := FAdapter as TObject as TLogifyAdapterFiles;

  for LIndex := 1 to MESSAGES do
    FAdapter.WriteLog('', 'line ' + LIndex.ToString, nil, TLogLevel.Info);

  Assert.IsTrue(LFiles.GetMessagesToWrite <= 1,
    Format('%d messages are waiting, the limit was 1', [LFiles.GetMessagesToWrite]));

  Release;
  Assert.IsTrue(TotalLines < MESSAGES, 'nothing was dropped, so nothing was bounded');
end;

procedure TFileAdapterTests.DroppedMessagesAreReportedInTheLog;
var
  LIndex: Integer;
  LFile: string;
  LText: string;
begin
  NewAdapter(True, 1);
  for LIndex := 1 to MESSAGES do
    FAdapter.WriteLog('', 'line ' + LIndex.ToString, nil, TLogLevel.Info);
  Release;

  LText := '';
  for LFile in LogFiles do
    LText := LText + TFile.ReadAllText(LFile);

  // A gap that says nothing turns the log into a quiet lie
  Assert.Contains(LText, 'dropped',
    'the log has to say that messages were lost, and how many');
end;

procedure TFileAdapterTests.AZeroLimitKeepsEverything;
var
  LIndex: Integer;
begin
  NewAdapter(True, 0);
  for LIndex := 1 to MESSAGES do
    FAdapter.WriteLog('', 'line ' + LIndex.ToString, nil, TLogLevel.Info);
  Release;

  Assert.AreEqual(MESSAGES, TotalLines);
end;

procedure TFileAdapterTests.EveryMessageSurvivesAtTheDefaultQueueLimit;
var
  LIndex: Integer;
begin
  // The default MaxQueueSize is the designed limit, and a fast producer can
  // fill it in milliseconds: the writer has to keep draining, and the shutdown
  // pass has to move whatever is still queued to the file in one go. Draining
  // a full queue used to be O(n^2), stalling the writer thread for seconds.
  NewAdapter(True, FULL_QUEUE);
  for LIndex := 1 to FULL_QUEUE do
    FAdapter.WriteLog('', 'line ' + LIndex.ToString, nil, TLogLevel.Info);
  Release;

  Assert.AreEqual(FULL_QUEUE, TotalLines);
end;

procedure TFileAdapterTests.ASingleConfigurationIsFullyInitialized;
var
  LConfig: TFileLogConfig;
begin
  // A record result only has its managed fields initialized: everything else
  // has to be set explicitly or it carries whatever was on the stack
  LConfig := TFileLogConfig.NewSingle(TLogLevel.Info);

  Assert.AreEqual(Ord(TLogType.Single), Ord(LConfig.LogType));
  Assert.IsTrue(LConfig.RotateItems > 0, 'RotateItems was left uninitialized');
  Assert.IsTrue(LConfig.RotateSize > 0, 'RotateSize was left uninitialized');
  Assert.IsTrue(LConfig.MaxQueueSize > 0, 'the queue is unbounded by default');
end;

procedure TFileAdapterTests.ARotateConfigurationIsFullyInitialized;
var
  LConfig: TFileLogConfig;
begin
  LConfig := TFileLogConfig.NewRotate(TLogLevel.Info);

  Assert.AreEqual(Ord(TLogType.Rotate), Ord(LConfig.LogType));
  Assert.AreEqual(10, LConfig.RotateItems);
  Assert.IsTrue(LConfig.RotateSize > 0);
end;

initialization
  TDUnitX.RegisterTestFixture(TFileAdapterTests);

end.
