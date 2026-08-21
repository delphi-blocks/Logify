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
///   Logify.Syslog carries no POSIX dependency on purpose, so the whole
///   mapping onto the syslog protocol is testable on any platform.
/// </summary>
unit Logify.Tests.Syslog;

interface

uses
  System.SysUtils, System.Classes,
  DUnitX.TestFramework,
  Logify,
  Logify.Syslog;

type
  /// <summary>
  ///   The enum ordinals are the protocol codes: if these drift, every
  ///   priority on the wire is wrong.
  /// </summary>
  [TestFixture]
  TSyslogCodeTests = class
  public
    [Test]
    [TestCase('kernel',   '0,0')]
    [TestCase('user',     '1,8')]
    [TestCase('daemon',   '3,24')]
    [TestCase('authpriv', '10,80')]
    [TestCase('local0',   '16,128')]
    [TestCase('local6',   '22,176')]
    [TestCase('local7',   '23,184')]
    procedure FacilityCodesMatchTheProtocol(AOrdinal, AShifted: Integer);

    [Test]
    procedure SeverityCodesMatchTheProtocol;
    [Test]
    procedure TheLocalFacilitiesSkipTheReservedRange;
    [Test]
    procedure OptionCodesAreTheOpenlogBits;
    [Test]
    procedure AnEmptyOptionSetIsZero;
  end;

  /// <summary>
  ///   TLogLevel to syslog severity, and the composed priority
  /// </summary>
  [TestFixture]
  TSyslogPriorityTests = class
  private
    FConfig: TSyslogConfig;
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure TraceAndDebugBothMapToDebug;
    [Test]
    procedure TheOtherLevelsMapOneToOne;
    [Test]
    procedure PriorityCombinesFacilityAndSeverity;
    [Test]
    procedure TheFacilityChangesThePriority;
    [Test]
    procedure FacilityCodeLeavesTheSeverityBitsClear;
    [Test]
    procedure LogMaskCoversEverythingUpToTheLevel;
  end;

  /// <summary>
  ///   Level filtering owned by the adapter's configuration
  /// </summary>
  [TestFixture]
  TSyslogConfigTests = class
  public
    [Test]
    procedure TheDefaultIsUserFacilityAtInfo;
    [Test]
    procedure LevelsBelowTheConfiguredOneAreRejected;
    [Test]
    procedure TheOffLevelIsAlwaysRejected;
    [Test]
    procedure OpenLogIsOnlyNeededWhenSomethingIsConfigured;
    [Test]
    procedure ANegativeMaxLengthBecomesUnlimited;
  end;

  /// <summary>
  ///   Payload layout (TSyslogFormatter) and record splitting
  /// </summary>
  [TestFixture]
  TSyslogMessageTests = class
  private
    FFormatter: TSyslogFormatter;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TheClassAndLevelAreCarriedInThePayload;
    [Test]
    procedure AnEmptyClassNameBecomesDefault;
    [Test]
    procedure OnlyTheLastSegmentOfTheClassNameIsKept;
    [Test]
    procedure NoTimestampIsAddedBecauseSyslogAddsOne;
    [Test]
    procedure AnExceptionIsAppendedThroughTheFormatter;

    [Test]
    procedure ASingleLineStaysOneRecord;
    [Test]
    procedure EachLineBecomesItsOwnRecord;
    [Test]
    procedure BlankLinesAreDropped;
    [Test]
    procedure WindowsAndUnixLineEndingsBothSplit;
    [Test]
    procedure SplittingOffKeepsOneRecord;
    [Test]
    procedure SplittingOffTruncatesInsteadOfWrapping;
    [Test]
    procedure LongLinesAreWrappedAtTheLimit;
    [Test]
    procedure AZeroLimitDisablesWrapping;
    [Test]
    procedure AnEmptyMessageProducesNoRecord;
  end;

implementation

/// <summary>
///   A set constructor cannot be typecast, so it reaches the record helper
///   through a parameter instead.
/// </summary>
function CodeOf(AOptions: TSyslogOptions): Integer;
begin
  Result := AOptions.ToCode;
end;

{ TSyslogCodeTests }

procedure TSyslogCodeTests.FacilityCodesMatchTheProtocol(AOrdinal, AShifted: Integer);
var
  LFacility: TSyslogFacility;
begin
  LFacility := TSyslogFacility(AOrdinal);

  Assert.AreEqual(AOrdinal, LFacility.ToCode);
  Assert.AreEqual(AShifted, LFacility.ToCode shl 3,
    'The facility has to sit above the three severity bits');
end;

procedure TSyslogCodeTests.SeverityCodesMatchTheProtocol;
begin
  Assert.AreEqual(0, TSyslogSeverity.Emergency.ToCode);
  Assert.AreEqual(1, TSyslogSeverity.Alert.ToCode);
  Assert.AreEqual(2, TSyslogSeverity.Critical.ToCode);
  Assert.AreEqual(3, TSyslogSeverity.Error.ToCode);
  Assert.AreEqual(4, TSyslogSeverity.Warning.ToCode);
  Assert.AreEqual(5, TSyslogSeverity.Notice.ToCode);
  Assert.AreEqual(6, TSyslogSeverity.Info.ToCode);
  Assert.AreEqual(7, TSyslogSeverity.Debug.ToCode);
end;

procedure TSyslogCodeTests.TheLocalFacilitiesSkipTheReservedRange;
begin
  // 12..15 are reserved (ntp, audit, alert, clock): Local0 must land on 16,
  // which only holds if the reserved entries are present in the enum.
  Assert.AreEqual(11, TSyslogFacility.FTP.ToCode);
  Assert.AreEqual(16, TSyslogFacility.Local0.ToCode);
  Assert.AreEqual(23, TSyslogFacility.Local7.ToCode);
end;

procedure TSyslogCodeTests.OptionCodesAreTheOpenlogBits;
begin
  Assert.AreEqual($01, CodeOf([TSyslogOption.PID]));
  Assert.AreEqual($02, CodeOf([TSyslogOption.Console]));
  Assert.AreEqual($04, CodeOf([TSyslogOption.Delay]));
  Assert.AreEqual($08, CodeOf([TSyslogOption.NoDelay]));
  Assert.AreEqual($10, CodeOf([TSyslogOption.NoWait]));
  Assert.AreEqual($20, CodeOf([TSyslogOption.PrintError]));

  Assert.AreEqual($09, CodeOf([TSyslogOption.PID, TSyslogOption.NoDelay]));
end;

procedure TSyslogCodeTests.AnEmptyOptionSetIsZero;
var
  LOptions: TSyslogOptions;
begin
  LOptions := [];
  Assert.AreEqual(0, LOptions.ToCode);
end;

{ TSyslogPriorityTests }

procedure TSyslogPriorityTests.Setup;
begin
  FConfig := TSyslogConfig.Default;
  FConfig.Level := TLogLevel.Trace;
end;

procedure TSyslogPriorityTests.TraceAndDebugBothMapToDebug;
begin
  // Logify has more levels than syslog has severities
  Assert.AreEqual(Ord(TSyslogSeverity.Debug), Ord(TSyslogSeverity.FromLevel(TLogLevel.Trace)));
  Assert.AreEqual(Ord(TSyslogSeverity.Debug), Ord(TSyslogSeverity.FromLevel(TLogLevel.Debug)));
end;

procedure TSyslogPriorityTests.TheOtherLevelsMapOneToOne;
begin
  Assert.AreEqual(Ord(TSyslogSeverity.Info), Ord(TSyslogSeverity.FromLevel(TLogLevel.Info)));
  Assert.AreEqual(Ord(TSyslogSeverity.Warning), Ord(TSyslogSeverity.FromLevel(TLogLevel.Warning)));
  Assert.AreEqual(Ord(TSyslogSeverity.Error), Ord(TSyslogSeverity.FromLevel(TLogLevel.Error)));
  Assert.AreEqual(Ord(TSyslogSeverity.Critical), Ord(TSyslogSeverity.FromLevel(TLogLevel.Critical)));
end;

procedure TSyslogPriorityTests.PriorityCombinesFacilityAndSeverity;
begin
  FConfig.Facility := TSyslogFacility.User;

  // user (1) shl 3 or info (6) = 14, the textbook syslog example
  Assert.AreEqual(14, FConfig.PriorityFor(TLogLevel.Info));
end;

procedure TSyslogPriorityTests.TheFacilityChangesThePriority;
begin
  FConfig.Facility := TSyslogFacility.Local6;

  // local6 (22) shl 3 or error (3) = 179
  Assert.AreEqual(179, FConfig.PriorityFor(TLogLevel.Error));
end;

procedure TSyslogPriorityTests.FacilityCodeLeavesTheSeverityBitsClear;
begin
  FConfig.Facility := TSyslogFacility.Daemon;

  Assert.AreEqual(24, FConfig.FacilityCode);
  Assert.AreEqual(0, FConfig.FacilityCode and $07,
    'openlog() wants the facility alone, with no severity in the low bits');
end;

procedure TSyslogPriorityTests.LogMaskCoversEverythingUpToTheLevel;
begin
  FConfig.Level := TLogLevel.Warning;

  // LOG_UPTO(warning=4) = (1 shl 5) - 1 = 31
  Assert.AreEqual(31, FConfig.LogMask);
end;

{ TSyslogConfigTests }

procedure TSyslogConfigTests.TheDefaultIsUserFacilityAtInfo;
var
  LConfig: TSyslogConfig;
begin
  LConfig := TSyslogConfig.Default;

  Assert.AreEqual(Ord(TSyslogFacility.User), Ord(LConfig.Facility));
  Assert.AreEqual(Ord(TLogLevel.Info), Ord(LConfig.Level));
  Assert.IsTrue(LConfig.SplitLines, 'A stack trace should arrive readable by default');
  Assert.IsFalse(LConfig.UseLogMask, 'Logify should be the only filter by default');
end;

procedure TSyslogConfigTests.LevelsBelowTheConfiguredOneAreRejected;
var
  LConfig: TSyslogConfig;
begin
  LConfig := TSyslogConfig.Default;
  LConfig.Level := TLogLevel.Warning;

  Assert.IsFalse(LConfig.Accepts(TLogLevel.Trace));
  Assert.IsFalse(LConfig.Accepts(TLogLevel.Debug));
  Assert.IsFalse(LConfig.Accepts(TLogLevel.Info));
  Assert.IsTrue(LConfig.Accepts(TLogLevel.Warning));
  Assert.IsTrue(LConfig.Accepts(TLogLevel.Error));
  Assert.IsTrue(LConfig.Accepts(TLogLevel.Critical));
end;

procedure TSyslogConfigTests.TheOffLevelIsAlwaysRejected;
var
  LConfig: TSyslogConfig;
begin
  LConfig := TSyslogConfig.Default;
  LConfig.Level := TLogLevel.Trace;

  Assert.IsFalse(LConfig.Accepts(TLogLevel.Off));
end;

procedure TSyslogConfigTests.OpenLogIsOnlyNeededWhenSomethingIsConfigured;
var
  LConfig: TSyslogConfig;
begin
  LConfig := TSyslogConfig.Default;
  LConfig.Options := [];
  LConfig.AppName := '';
  Assert.IsFalse(LConfig.NeedsOpenLog, 'syslog() opens itself and tags with argv[0]');

  LConfig.AppName := 'mydaemon';
  Assert.IsTrue(LConfig.NeedsOpenLog);

  LConfig.AppName := '';
  LConfig.Options := [TSyslogOption.PID];
  Assert.IsTrue(LConfig.NeedsOpenLog);
end;

procedure TSyslogConfigTests.ANegativeMaxLengthBecomesUnlimited;
var
  LConfig: TSyslogConfig;
begin
  LConfig := TSyslogConfig.Default;
  LConfig.MaxLength := -10;

  Assert.AreEqual(0, LConfig.MaxLength);
end;

{ TSyslogMessageTests }

procedure TSyslogMessageTests.Setup;
begin
  FFormatter := TSyslogFormatter.Create;
end;

procedure TSyslogMessageTests.TearDown;
begin
  FFormatter.Free;
end;

procedure TSyslogMessageTests.TheClassAndLevelAreCarriedInThePayload;
var
  LPayload: string;
begin
  // FormatMsg takes (AMessage, AClassName), the reverse of WriteLog
  LPayload := FFormatter.FormatMsg('the message', 'TfrmMain', nil, TLogLevel.Warning);

  Assert.Contains(LPayload, '[TfrmMain]');
  Assert.Contains(LPayload, 'WARNING');
  Assert.Contains(LPayload, 'the message');
end;

procedure TSyslogMessageTests.AnEmptyClassNameBecomesDefault;
begin
  Assert.Contains(FFormatter.FormatMsg('the message', '', nil, TLogLevel.Info), '[default]');
end;

procedure TSyslogMessageTests.OnlyTheLastSegmentOfTheClassNameIsKept;
var
  LPayload: string;
begin
  LPayload := FFormatter.FormatMsg('the message', 'Demo.Form.Main.TfrmMain', nil, TLogLevel.Info);

  Assert.Contains(LPayload, '[TfrmMain]');
  Assert.DoesNotContain(LPayload, 'Demo.Form.Main');
end;

procedure TSyslogMessageTests.NoTimestampIsAddedBecauseSyslogAddsOne;
var
  LPayload: string;
begin
  LPayload := FFormatter.FormatMsg('the message', 'TfrmMain', nil, TLogLevel.Info);

  // The default formatter's template starts with an ISO 8601 date; this one
  // must not
  Assert.IsFalse(LPayload.StartsWith(FormatDateTime('yyyy', Now)),
    'syslog records the timestamp itself, repeating it wastes the line');
end;

procedure TSyslogMessageTests.AnExceptionIsAppendedThroughTheFormatter;
var
  LException: Exception;
  LPayload: string;
begin
  LException := EListError.Create('the failure');
  try
    LPayload := FFormatter.FormatMsg('the operation failed', 'TfrmMain', LException, TLogLevel.Error);
  finally
    LException.Free;
  end;

  Assert.Contains(LPayload, 'the operation failed');
  Assert.Contains(LPayload, 'EListError: the failure');
end;

procedure TSyslogMessageTests.ASingleLineStaysOneRecord;
var
  LRecords: TArray<string>;
begin
  LRecords := SplitMessage('one line', 1024, True);

  Assert.AreEqual(1, Length(LRecords));
  Assert.AreEqual('one line', LRecords[0]);
end;

procedure TSyslogMessageTests.EachLineBecomesItsOwnRecord;
var
  LRecords: TArray<string>;
begin
  LRecords := SplitMessage('first'#10'second'#10'third', 1024, True);

  Assert.AreEqual(3, Length(LRecords));
  Assert.AreEqual('first', LRecords[0]);
  Assert.AreEqual('second', LRecords[1]);
  Assert.AreEqual('third', LRecords[2]);
end;

procedure TSyslogMessageTests.BlankLinesAreDropped;
var
  LRecords: TArray<string>;
begin
  LRecords := SplitMessage('first'#10#10'second'#10, 1024, True);

  Assert.AreEqual(2, Length(LRecords), 'An empty syslog record carries nothing');
end;

procedure TSyslogMessageTests.WindowsAndUnixLineEndingsBothSplit;
begin
  Assert.AreEqual(2, Length(SplitMessage('a'#13#10'b', 1024, True)), 'CRLF');
  Assert.AreEqual(2, Length(SplitMessage('a'#10'b', 1024, True)), 'LF');
  Assert.AreEqual(2, Length(SplitMessage('a'#13'b', 1024, True)), 'CR');
end;

procedure TSyslogMessageTests.SplittingOffKeepsOneRecord;
var
  LRecords: TArray<string>;
begin
  LRecords := SplitMessage('first'#10'second'#10'third', 1024, False);

  Assert.AreEqual(1, Length(LRecords));
end;

procedure TSyslogMessageTests.SplittingOffTruncatesInsteadOfWrapping;
var
  LRecords: TArray<string>;
begin
  LRecords := SplitMessage(StringOfChar('x', 100), 10, False);

  Assert.AreEqual(1, Length(LRecords));
  Assert.AreEqual(10, LRecords[0].Length);
end;

procedure TSyslogMessageTests.LongLinesAreWrappedAtTheLimit;
var
  LRecords: TArray<string>;
begin
  LRecords := SplitMessage(StringOfChar('x', 25), 10, True);

  Assert.AreEqual(3, Length(LRecords));
  Assert.AreEqual(10, LRecords[0].Length);
  Assert.AreEqual(10, LRecords[1].Length);
  Assert.AreEqual(5, LRecords[2].Length);
end;

procedure TSyslogMessageTests.AZeroLimitDisablesWrapping;
var
  LRecords: TArray<string>;
begin
  LRecords := SplitMessage(StringOfChar('x', 5000), 0, True);

  Assert.AreEqual(1, Length(LRecords));
  Assert.AreEqual(5000, LRecords[0].Length);
end;

procedure TSyslogMessageTests.AnEmptyMessageProducesNoRecord;
begin
  Assert.AreEqual(0, Length(SplitMessage('', 1024, True)));
  Assert.AreEqual(0, Length(SplitMessage('', 1024, False)));
end;

initialization
  TDUnitX.RegisterTestFixture(TSyslogCodeTests);
  TDUnitX.RegisterTestFixture(TSyslogPriorityTests);
  TDUnitX.RegisterTestFixture(TSyslogConfigTests);
  TDUnitX.RegisterTestFixture(TSyslogMessageTests);

end.
