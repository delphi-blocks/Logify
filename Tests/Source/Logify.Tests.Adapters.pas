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
unit Logify.Tests.Adapters;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils,
  DUnitX.TestFramework,
  Logify,
  Logify.Adapter.Buffer,
  Logify.Adapter.Console,
  Logify.Adapter.Debug,
  Logify.Adapter.Files;

type
  /// <summary>
  ///   Base fixture writing through a buffer adapter into a TStrings we own,
  ///   so what an adapter produced can be asserted on.
  /// </summary>
  TBufferedAdapterFixture = class
  protected
    FTarget: TStringList;
    FAdapter: ILoggerAdapter;
    procedure UseLevel(ALevel: TLogLevel);
  public
    [Setup]
    procedure Setup; virtual;
    [TearDown]
    procedure TearDown; virtual;
  end;

  /// <summary>
  ///   Level filtering performed by TLoggerAdapterHelper
  /// </summary>
  [TestFixture]
  TLevelFilteringTests = class(TBufferedAdapterFixture)
  public
    [Test]
    procedure MessagesAtTheAdapterLevelAreWritten;
    [Test]
    procedure MessagesAboveTheAdapterLevelAreWritten;
    [Test]
    procedure MessagesBelowTheAdapterLevelAreDropped;
    [Test]
    procedure TheOffLevelIsNeverWritten;
    [Test]
    procedure AnAdapterAtTraceWritesEveryRealLevel;
    [Test]
    procedure RawLinesHonourTheAdapterLevel;
    [Test]
    procedure RawLinesAreWrittenVerbatim;
  end;

  /// <summary>
  ///   Every factory must hand its configured level to the adapter it builds.
  ///   Regression tests: the Debug adapter used to shadow the inherited FLevel
  ///   and the Console factory used to drop it entirely, so both logged at
  ///   their default level whatever the caller asked for.
  /// </summary>
  [TestFixture]
  TFactoryLevelTests = class
  private
    function LevelOf(const AAdapter: ILoggerAdapter): TLogLevel;
  public
    [Test]
    procedure DebugFactoryPropagatesTheLevel;
    [Test]
    procedure ConsoleFactoryPropagatesTheLevel;
    [Test]
    procedure BufferFactoryPropagatesTheLevel;
    [Test]
    procedure FilesFactoryPropagatesTheLevel;
    [Test]
    procedure UniqueNameDefaultsToTheClassName;
    [Test]
    procedure UniqueNameUsesTheConfiguredName;
  end;

  /// <summary>
  ///   Message formatting done by TLoggerAdapterHelper.FormatMsg
  /// </summary>
  [TestFixture]
  TFormattingTests = class(TBufferedAdapterFixture)
  public
    [Setup]
    procedure Setup; override;

    [Test]
    procedure TheMessageAndLevelAppearInTheLine;
    [Test]
    procedure AnEmptyClassNameIsLoggedAsDefault;
    [Test]
    procedure OnlyTheLastSegmentOfTheClassNameIsKept;
    [Test]
    procedure TheExceptionClassAndMessageAreAppended;
    [Test]
    procedure InnerExceptionsAreAppended;
    [Test]
    procedure NoExceptionInfoIsAppendedWithoutAnException;
  end;

implementation

uses
  Logify.Tests.Core;

{ TBufferedAdapterFixture }

procedure TBufferedAdapterFixture.Setup;
begin
  FTarget := TStringList.Create;
end;

procedure TBufferedAdapterFixture.TearDown;
begin
  // Release the adapter before the target it writes into
  FAdapter := nil;
  FreeAndNil(FTarget);
end;

procedure TBufferedAdapterFixture.UseLevel(ALevel: TLogLevel);
var
  LFactory: ILoggerAdapterFactory;
begin
  LFactory := TLogifyAdapterBufferFactory.CreateAdapterFactory(UniqueName, ALevel, FTarget);
  FAdapter := LFactory.CreateLoggerAdapter;
end;

{ TLevelFilteringTests }

procedure TLevelFilteringTests.MessagesAtTheAdapterLevelAreWritten;
begin
  UseLevel(TLogLevel.Warning);
  FAdapter.WriteLog('', 'exactly at the level', nil, TLogLevel.Warning);

  Assert.AreEqual(1, FTarget.Count);
  Assert.Contains(FTarget.Text, 'exactly at the level');
end;

procedure TLevelFilteringTests.MessagesAboveTheAdapterLevelAreWritten;
begin
  UseLevel(TLogLevel.Warning);
  FAdapter.WriteLog('', 'an error', nil, TLogLevel.Error);
  FAdapter.WriteLog('', 'a critical', nil, TLogLevel.Critical);

  Assert.AreEqual(2, FTarget.Count);
end;

procedure TLevelFilteringTests.MessagesBelowTheAdapterLevelAreDropped;
begin
  UseLevel(TLogLevel.Warning);
  FAdapter.WriteLog('', 'a trace', nil, TLogLevel.Trace);
  FAdapter.WriteLog('', 'a debug', nil, TLogLevel.Debug);
  FAdapter.WriteLog('', 'an info', nil, TLogLevel.Info);

  Assert.AreEqual(0, FTarget.Count, 'Messages below the adapter level must be dropped');
end;

procedure TLevelFilteringTests.TheOffLevelIsNeverWritten;
begin
  UseLevel(TLogLevel.Trace);
  FAdapter.WriteLog('', 'switched off', nil, TLogLevel.Off);
  FAdapter.WriteRawLine('switched off', TLogLevel.Off);

  Assert.AreEqual(0, FTarget.Count, 'TLogLevel.Off must never produce output');
end;

procedure TLevelFilteringTests.AnAdapterAtTraceWritesEveryRealLevel;
var
  LLevel: TLogLevel;
begin
  UseLevel(TLogLevel.Trace);
  for LLevel := TLogLevel.Trace to TLogLevel.Critical do
    FAdapter.WriteLog('', 'message', nil, LLevel);

  Assert.AreEqual(6, FTarget.Count);
end;

procedure TLevelFilteringTests.RawLinesHonourTheAdapterLevel;
begin
  UseLevel(TLogLevel.Error);
  FAdapter.WriteRawLine('below', TLogLevel.Info);
  FAdapter.WriteRawLine('at level', TLogLevel.Error);

  Assert.AreEqual(1, FTarget.Count);
  Assert.AreEqual('at level', FTarget[0]);
end;

procedure TLevelFilteringTests.RawLinesAreWrittenVerbatim;
begin
  UseLevel(TLogLevel.Trace);
  FAdapter.WriteRawLine('=== a banner ===', TLogLevel.Info);

  Assert.AreEqual('=== a banner ===', FTarget[0],
    'A raw line must carry no timestamp, thread id or level');
end;

{ TFactoryLevelTests }

function TFactoryLevelTests.LevelOf(const AAdapter: ILoggerAdapter): TLogLevel;
var
  LObject: TObject;
begin
  LObject := AAdapter as TObject;
  Assert.IsTrue(LObject is TLoggerAdapterHelper,
    LObject.ClassName + ' is expected to derive from TLoggerAdapterHelper');

  Result := TLoggerAdapterHelper(LObject).Level;
end;

procedure TFactoryLevelTests.DebugFactoryPropagatesTheLevel;
var
  LFactory: ILoggerAdapterFactory;
begin
  LFactory := TLogifyAdapterDebugFactory.CreateAdapterFactory(UniqueName, TLogLevel.Error);

  Assert.AreEqual(Ord(TLogLevel.Error), Ord(LevelOf(LFactory.CreateLoggerAdapter)));
end;

procedure TFactoryLevelTests.ConsoleFactoryPropagatesTheLevel;
var
  LFactory: ILoggerAdapterFactory;
begin
  LFactory := TLogifyAdapterConsoleFactory.CreateAdapterFactory(UniqueName, TLogLevel.Critical);

  Assert.AreEqual(Ord(TLogLevel.Critical), Ord(LevelOf(LFactory.CreateLoggerAdapter)));
end;

procedure TFactoryLevelTests.BufferFactoryPropagatesTheLevel;
var
  LFactory: ILoggerAdapterFactory;
begin
  LFactory := TLogifyAdapterBufferFactory.CreateAdapterFactory(UniqueName, TLogLevel.Warning, nil);

  Assert.AreEqual(Ord(TLogLevel.Warning), Ord(LevelOf(LFactory.CreateLoggerAdapter)));
end;

procedure TFactoryLevelTests.FilesFactoryPropagatesTheLevel;
var
  LFactory: ILoggerAdapterFactory;
  LAdapter: ILoggerAdapter;
begin
  LFactory := TLogifyAdapterFilesFactory.CreateAdapterFactory(UniqueName,
    procedure(var AConfig: TFileLogConfig)
    begin
      AConfig.Level := TLogLevel.Error;
      AConfig.Append := False;
      AConfig.SetLogName('logify-tests');
      AConfig.Path := TPath.Combine(TPath.GetTempPath, 'logify-tests');
      AConfig.Ext := 'log';
    end);

  LAdapter := LFactory.CreateLoggerAdapter;
  try
    Assert.AreEqual(Ord(TLogLevel.Error), Ord(LevelOf(LAdapter)));
  finally
    LAdapter := nil;
  end;
end;

procedure TFactoryLevelTests.UniqueNameDefaultsToTheClassName;
var
  LFactory: ILoggerAdapterFactory;
begin
  LFactory := TLogifyAdapterBufferFactory.CreateAdapterFactory(TLogLevel.Info, nil);

  Assert.AreEqual('TLogifyAdapterBufferFactory', LFactory.GetUniqueName);
end;

procedure TFactoryLevelTests.UniqueNameUsesTheConfiguredName;
var
  LFactory: ILoggerAdapterFactory;
begin
  LFactory := TLogifyAdapterBufferFactory.CreateAdapterFactory('my-buffer', TLogLevel.Info, nil);

  Assert.AreEqual('my-buffer', LFactory.GetUniqueName);
end;

{ TFormattingTests }

procedure TFormattingTests.Setup;
begin
  inherited;
  UseLevel(TLogLevel.Trace);
end;

procedure TFormattingTests.TheMessageAndLevelAppearInTheLine;
begin
  FAdapter.WriteLog('', 'the payload', nil, TLogLevel.Warning);

  Assert.Contains(FTarget[0], 'WARNING');
  Assert.Contains(FTarget[0], 'the payload');
end;

procedure TFormattingTests.AnEmptyClassNameIsLoggedAsDefault;
begin
  FAdapter.WriteLog('', 'no class', nil, TLogLevel.Info);

  Assert.Contains(FTarget[0], '[default]');
end;

procedure TFormattingTests.OnlyTheLastSegmentOfTheClassNameIsKept;
begin
  FAdapter.WriteLog('Demo.Form.Main.TfrmMain', 'qualified', nil, TLogLevel.Info);

  Assert.Contains(FTarget[0], '[TfrmMain]');
  Assert.DoesNotContain(FTarget[0], 'Demo.Form.Main');
end;

procedure TFormattingTests.TheExceptionClassAndMessageAreAppended;
var
  LException: Exception;
begin
  LException := EListError.Create('something broke');
  try
    FAdapter.WriteLog('', 'operation failed', LException, TLogLevel.Error);
  finally
    LException.Free;
  end;

  Assert.Contains(FTarget.Text, 'operation failed');
  Assert.Contains(FTarget.Text, 'EListError');
  Assert.Contains(FTarget.Text, 'something broke');
end;

procedure TFormattingTests.InnerExceptionsAreAppended;
begin
  try
    try
      raise Exception.Create('the root cause');
    except
      Exception.RaiseOuterException(EListError.Create('the outer failure'));
    end;
  except
    on E: Exception do
      FAdapter.WriteLog('', 'operation failed', E, TLogLevel.Error);
  end;

  Assert.Contains(FTarget.Text, 'the outer failure');
  Assert.Contains(FTarget.Text, '--- Caused by');
  Assert.Contains(FTarget.Text, 'the root cause');
end;

procedure TFormattingTests.NoExceptionInfoIsAppendedWithoutAnException;
begin
  FAdapter.WriteLog('', 'plain message', nil, TLogLevel.Info);

  Assert.DoesNotContain(FTarget.Text, 'Caused by');
  Assert.AreEqual(1, FTarget.Count);
end;

initialization
  TDUnitX.RegisterTestFixture(TLevelFilteringTests);
  TDUnitX.RegisterTestFixture(TFactoryLevelTests);
  TDUnitX.RegisterTestFixture(TFormattingTests);

end.
