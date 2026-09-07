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
///   The error adapter writes straight to the process standard error, so the
///   only way to assert on what it produced is to point stderr somewhere the
///   test can read back: these tests redirect it to a temporary file for the
///   duration of each test and restore it afterwards.
/// </summary>
unit Logify.Tests.Error;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils,
  DUnitX.TestFramework,
  Logify,
  Logify.Adapter.Error;

type
  /// <summary>
  ///   Redirects the process standard error into a temporary file and reads
  ///   it back. The redirection has to be in place before the adapter writes
  ///   its first line, because that is when the adapter resolves the stream.
  /// </summary>
  TStdErrCapture = class
  private
    FFileName: string;
    FStream: TFileStream;
    FActive: Boolean;
    {$IFDEF MSWINDOWS}
    FSaved: THandle;
    {$ENDIF}
    {$IFDEF POSIX}
    FSaved: Integer;
    {$ENDIF}
    procedure Redirect;
  public
    destructor Destroy; override;

    /// <summary>
    ///   Sends standard error to a fresh temporary file.
    /// </summary>
    procedure Start;
    /// <summary>
    ///   Leaves the process with no usable standard error at all, the way a
    ///   Windows GUI application started without a console is.
    /// </summary>
    procedure Detach;
    /// <summary>
    ///   Puts the original standard error back. Safe to call twice.
    /// </summary>
    procedure Stop;

    /// <summary>
    ///   Everything written while the capture was running, decoded as UTF-8.
    ///   Stops the capture first, so what the adapter wrote is complete.
    /// </summary>
    function Text: string;
    /// <summary>
    ///   The captured text split into lines.
    /// </summary>
    function Lines: TStringList;
  end;

  /// <summary>
  ///   TLogifyAdapterError: what actually lands on the standard error stream
  /// </summary>
  [TestFixture]
  TErrorAdapterTests = class
  private const
    // Characters outside any single byte code page: they survive the trip
    // only if the line really is written as UTF-8 (or as UTF-16 to a console)
    NON_ASCII = 'caf' + #$00E8 + ' ' + #$4E2D;
  private
    FCapture: TStdErrCapture;
    FAdapter: ILoggerAdapter;
    procedure UseLevel(ALevel: TLogLevel);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure AMessageReachesStandardError;
    [Test]
    procedure TheLineCarriesTheStandardLayout;
    [Test]
    procedure MessagesBelowTheAdapterLevelNeverReachStandardError;
    [Test]
    procedure TheOffLevelIsNeverWritten;
    [Test]
    procedure EveryMessageIsOneLine;
    [Test]
    procedure TheLastLineIsTerminated;
    [Test]
    procedure RawLinesAreWrittenVerbatim;
    [Test]
    procedure RawLinesHonourTheAdapterLevel;
    [Test]
    procedure TheExceptionBlockFollowsTheMessage;
    [Test]
    procedure NonAsciiSurvivesAsUtf8;
    [Test]
    procedure WritingWithoutAStandardErrorIsHarmless;
    [Test]
    procedure TheAdapterIsReachedThroughTheRegistry;
  end;

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  {$IFDEF POSIX}
  Posix.Unistd,
  {$ENDIF}
  Logify.Tests.Core;

{ TStdErrCapture }

destructor TStdErrCapture.Destroy;
begin
  Stop;
  if not FFileName.IsEmpty and TFile.Exists(FFileName) then
    TFile.Delete(FFileName);

  inherited;
end;

procedure TStdErrCapture.Redirect;
begin
  {$IFDEF MSWINDOWS}
  FSaved := GetStdHandle(STD_ERROR_HANDLE);
  {$ENDIF}
  {$IFDEF POSIX}
  FSaved := dup(STDERR_FILENO);
  {$ENDIF}
  FActive := True;
end;

procedure TStdErrCapture.Start;
begin
  if FActive then
    Exit;

  FFileName := TPath.Combine(TPath.GetTempPath, 'logify-stderr-' + UniqueName + '.txt');
  // The stream owns the file; the adapter only writes through the handle it
  // is given, so nothing else may hold the file exclusively
  FStream := TFileStream.Create(FFileName, fmCreate or fmShareDenyNone);

  Redirect;
  {$IFDEF MSWINDOWS}
  SetStdHandle(STD_ERROR_HANDLE, FStream.Handle);
  {$ENDIF}
  {$IFDEF POSIX}
  // On POSIX the stream handle is the file descriptor
  dup2(Integer(FStream.Handle), STDERR_FILENO);
  {$ENDIF}
end;

procedure TStdErrCapture.Detach;
begin
  if FActive then
    Exit;

  Redirect;
  {$IFDEF MSWINDOWS}
  // No handle at all: what GetStdHandle reports for a GUI process
  SetStdHandle(STD_ERROR_HANDLE, 0);
  {$ENDIF}
  {$IFDEF POSIX}
  __close(STDERR_FILENO);
  {$ENDIF}
end;

procedure TStdErrCapture.Stop;
begin
  if not FActive then
    Exit;

  {$IFDEF MSWINDOWS}
  SetStdHandle(STD_ERROR_HANDLE, FSaved);
  {$ENDIF}
  {$IFDEF POSIX}
  dup2(FSaved, STDERR_FILENO);
  __close(FSaved);
  {$ENDIF}
  FActive := False;

  // Closing the file after stderr points elsewhere again
  FreeAndNil(FStream);
end;

function TStdErrCapture.Text: string;
begin
  Stop;

  if FFileName.IsEmpty or not TFile.Exists(FFileName) then
    Exit('');

  Result := TFile.ReadAllText(FFileName, TEncoding.UTF8);
end;

function TStdErrCapture.Lines: TStringList;
begin
  Result := TStringList.Create;
  try
    Result.Text := Text;
  except
    Result.Free;
    raise;
  end;
end;

{ TErrorAdapterTests }

procedure TErrorAdapterTests.Setup;
begin
  FCapture := TStdErrCapture.Create;
  FCapture.Start;
end;

procedure TErrorAdapterTests.TearDown;
begin
  // The adapter holds the redirected stream handle: let it go before the
  // capture restores stderr and removes the file
  FAdapter := nil;
  FreeAndNil(FCapture);
end;

procedure TErrorAdapterTests.UseLevel(ALevel: TLogLevel);
var
  LFactory: ILoggerAdapterFactory;
begin
  LFactory := TLogifyAdapterErrorFactory.CreateAdapterFactory(UniqueName, ALevel);
  FAdapter := LFactory.CreateLoggerAdapter;
end;

procedure TErrorAdapterTests.AMessageReachesStandardError;
begin
  UseLevel(TLogLevel.Info);
  FAdapter.WriteLog('', 'on the error stream', nil, TLogLevel.Warning);

  Assert.Contains(FCapture.Text, 'on the error stream');
end;

procedure TErrorAdapterTests.TheLineCarriesTheStandardLayout;
var
  LLine: string;
begin
  UseLevel(TLogLevel.Trace);
  FAdapter.WriteLog('Demo.Form.Main.TfrmMain', 'the payload', nil, TLogLevel.Error);

  LLine := FCapture.Text;
  Assert.Contains(LLine, 'ERROR');
  Assert.Contains(LLine, '[TfrmMain]');
  Assert.Contains(LLine, 'the payload');
end;

procedure TErrorAdapterTests.MessagesBelowTheAdapterLevelNeverReachStandardError;
begin
  UseLevel(TLogLevel.Warning);
  FAdapter.WriteLog('', 'a trace', nil, TLogLevel.Trace);
  FAdapter.WriteLog('', 'an info', nil, TLogLevel.Info);

  Assert.AreEqual('', FCapture.Text,
    'Nothing below the adapter level may reach the error stream');
end;

procedure TErrorAdapterTests.TheOffLevelIsNeverWritten;
begin
  UseLevel(TLogLevel.Trace);
  FAdapter.WriteLog('', 'switched off', nil, TLogLevel.Off);
  FAdapter.WriteRawLine('switched off', TLogLevel.Off);

  Assert.AreEqual('', FCapture.Text, 'TLogLevel.Off must never produce output');
end;

procedure TErrorAdapterTests.EveryMessageIsOneLine;
var
  LLines: TStringList;
begin
  UseLevel(TLogLevel.Trace);
  FAdapter.WriteLog('', 'first', nil, TLogLevel.Info);
  FAdapter.WriteLog('', 'second', nil, TLogLevel.Info);
  FAdapter.WriteLog('', 'third', nil, TLogLevel.Info);

  LLines := FCapture.Lines;
  try
    Assert.AreEqual(3, LLines.Count);
    Assert.Contains(LLines[0], 'first');
    Assert.Contains(LLines[1], 'second');
    Assert.Contains(LLines[2], 'third');
  finally
    LLines.Free;
  end;
end;

procedure TErrorAdapterTests.TheLastLineIsTerminated;
begin
  UseLevel(TLogLevel.Trace);
  FAdapter.WriteLog('', 'terminated', nil, TLogLevel.Info);

  // A message that left its line open would run into the next one
  Assert.IsTrue(FCapture.Text.EndsWith(sLineBreak),
    'Every message must terminate its own line');
end;

procedure TErrorAdapterTests.RawLinesAreWrittenVerbatim;
var
  LLines: TStringList;
begin
  UseLevel(TLogLevel.Trace);
  FAdapter.WriteRawLine('=== a banner ===', TLogLevel.Info);

  LLines := FCapture.Lines;
  try
    Assert.AreEqual('=== a banner ===', LLines[0],
      'A raw line must carry no timestamp, thread id or level');
  finally
    LLines.Free;
  end;
end;

procedure TErrorAdapterTests.RawLinesHonourTheAdapterLevel;
var
  LLines: TStringList;
begin
  UseLevel(TLogLevel.Error);
  FAdapter.WriteRawLine('below', TLogLevel.Info);
  FAdapter.WriteRawLine('at level', TLogLevel.Error);

  LLines := FCapture.Lines;
  try
    Assert.AreEqual(1, LLines.Count);
    Assert.AreEqual('at level', LLines[0]);
  finally
    LLines.Free;
  end;
end;

procedure TErrorAdapterTests.TheExceptionBlockFollowsTheMessage;
var
  LException: Exception;
  LText: string;
begin
  UseLevel(TLogLevel.Trace);

  LException := EListError.Create('something broke');
  try
    FAdapter.WriteLog('', 'operation failed', LException, TLogLevel.Error);
  finally
    LException.Free;
  end;

  LText := FCapture.Text;
  Assert.Contains(LText, 'operation failed');
  Assert.Contains(LText, 'EListError');
  Assert.Contains(LText, 'something broke');
end;

procedure TErrorAdapterTests.NonAsciiSurvivesAsUtf8;
begin
  UseLevel(TLogLevel.Trace);
  FAdapter.WriteRawLine(NON_ASCII, TLogLevel.Info);

  // Read back as UTF-8: bytes written in any other encoding would not decode
  // to the string that went in
  Assert.Contains(FCapture.Text, NON_ASCII);
end;

procedure TErrorAdapterTests.WritingWithoutAStandardErrorIsHarmless;
begin
  FCapture.Stop;
  FCapture.Detach;
  try
    UseLevel(TLogLevel.Trace);

    Assert.WillNotRaiseAny(
      procedure
      begin
        FAdapter.WriteLog('', 'nowhere to go', nil, TLogLevel.Error);
        FAdapter.WriteRawLine('nowhere to go', TLogLevel.Error);
      end,
      'A process without a standard error must still be able to log');
  finally
    FCapture.Stop;
  end;
end;

procedure TErrorAdapterTests.TheAdapterIsReachedThroughTheRegistry;
var
  LCategory: string;
begin
  LCategory := UniqueName;
  TLoggerAdapterRegistry.Instance.RegisterFactory(LCategory,
    TLogifyAdapterErrorFactory.CreateAdapterFactory(UniqueName, TLogLevel.Info));
  try
    TLoggerManager.GetCategoryLogger(LCategory).LogWarning('through the registry');
  finally
    // The registry caches the adapter, and with it the redirected handle
    TLoggerAdapterRegistry.Instance.UnregisterCategory(LCategory);
  end;

  Assert.Contains(FCapture.Text, 'through the registry');
end;

initialization
  TDUnitX.RegisterTestFixture(TErrorAdapterTests);

end.
