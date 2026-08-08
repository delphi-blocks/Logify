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
unit Logify.Tests.Core;

interface

uses
  System.SysUtils, System.Classes,
  DUnitX.TestFramework,
  Logify,
  Logify.Adapter.Buffer;

type
  /// <summary>
  ///   TLogLevel and its record helper
  /// </summary>
  [TestFixture]
  TLogLevelTests = class
  public
    [Test]
    procedure ToStringReturnsTheUpperCaseName;
    [Test]
    procedure LevelsAreOrderedFromTraceToOff;
    [Test]
    procedure FromStringRoundTripsToString;
  end;

  /// <summary>
  ///   The global Logger and TLoggerManager
  /// </summary>
  [TestFixture]
  TLoggerTests = class
  public
    [Test]
    procedure LoggerIsUsableWithoutAnyRegistration;
    [Test]
    procedure LoggerAlwaysReturnsTheSameInstance;
    [Test]
    procedure LoggingWithoutAdaptersDoesNothing;
    [Test]
    procedure GetLoggerAcceptsAClassAClassNameAndAGenericArgument;
  end;

  /// <summary>
  ///   GetFullExceptionInfo, public so that adapters implementing
  ///   ILoggerAdapter directly can render exceptions the same way
  /// </summary>
  [TestFixture]
  TExceptionInfoTests = class
  public
    [Test]
    procedure ANilExceptionYieldsAnEmptyString;
    [Test]
    procedure TheClassAndMessageAreReported;
    [Test]
    procedure TheInnerExceptionChainIsWalked;
    [Test]
    procedure ThereIsNoTrailingLineBreak;
  end;

  /// <summary>
  ///   Loggers bound to a category other than "default"
  /// </summary>
  [TestFixture]
  TCategoryLoggerTests = class
  private
    FCategory: string;
    FCategoryTarget: TStringList;
    FDefaultTarget: TStringList;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ACategoryLoggerReachesItsOwnAdapters;
    [Test]
    procedure ACategoryLoggerDoesNotReachTheDefaultAdapters;
    [Test]
    procedure TheDefaultLoggerDoesNotReachTheCategoryAdapters;
    [Test]
    procedure ACategoryLoggerStampsTheClassName;
    [Test]
    procedure TheGenericOverloadStampsTheClassName;
    [Test]
    procedure ALoggerForAnUnusedCategoryIsInert;
  end;

  /// <summary>
  ///   TLoggerAdapterRegistry: factory registration, lookup and adapter caching
  /// </summary>
  [TestFixture]
  TRegistryTests = class
  private
    /// <summary>
    ///   A buffer factory with no target: these tests never inspect the
    ///   output, and the registry outlives the fixture, so the adapter must
    ///   not hold a pointer to anything owned by a test.
    /// </summary>
    function NewFactory(const AName: string): ILoggerAdapterFactory;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure InstanceIsASingleton;
    [Test]
    procedure FindFactoryReturnsTheRegisteredFactory;
    [Test]
    procedure FindFactoryReturnsNilWhenTheNameIsUnknown;
    [Test]
    procedure GetFactoryRaisesWhenTheNameIsUnknown;
    [Test]
    procedure GetLoggerAdaptersReturnsOnlyTheRequestedCategory;
    [Test]
    procedure GetLoggerAdaptersReturnsNothingForAnUnusedCategory;
    [Test]
    procedure GetLoggerAdaptersCachesTheAdapterInstance;
    [Test]
    procedure RegisteringTheSameNameTwiceRaises;
    [Test]
    procedure UnregisterFactoryRemovesIt;
    [Test]
    procedure UnregisterFactoryIgnoresAnUnknownName;
    [Test]
    procedure UnregisterFactoryAcceptsTheFactoryItself;
    [Test]
    procedure UnregisterFactoryDropsTheCachedAdapter;
    [Test]
    procedure AFactoryCanBeRegisteredAgainAfterUnregistering;
    [Test]
    procedure UnregisterCategoryLeavesTheOtherCategoriesAlone;
    [Test]
    procedure ClearEmptiesTheRegistry;
  end;

function UniqueName: string;

implementation

var
  _Counter: Integer;

function UniqueName: string;
begin
  Inc(_Counter);
  Result := Format('test-%d', [_Counter]);
end;

{ TLogLevelTests }

procedure TLogLevelTests.ToStringReturnsTheUpperCaseName;
begin
  Assert.AreEqual('TRACE', TLogLevel.Trace.ToString);
  Assert.AreEqual('DEBUG', TLogLevel.Debug.ToString);
  Assert.AreEqual('INFO', TLogLevel.Info.ToString);
  Assert.AreEqual('WARNING', TLogLevel.Warning.ToString);
  Assert.AreEqual('ERROR', TLogLevel.Error.ToString);
  Assert.AreEqual('CRITICAL', TLogLevel.Critical.ToString);
  Assert.AreEqual('OFF', TLogLevel.Off.ToString);
end;

procedure TLogLevelTests.LevelsAreOrderedFromTraceToOff;
begin
  // The whole level-filtering mechanism relies on this ordering
  Assert.IsTrue(TLogLevel.Trace < TLogLevel.Debug);
  Assert.IsTrue(TLogLevel.Debug < TLogLevel.Info);
  Assert.IsTrue(TLogLevel.Info < TLogLevel.Warning);
  Assert.IsTrue(TLogLevel.Warning < TLogLevel.Error);
  Assert.IsTrue(TLogLevel.Error < TLogLevel.Critical);
  Assert.IsTrue(TLogLevel.Critical < TLogLevel.Off);
end;

procedure TLogLevelTests.FromStringRoundTripsToString;
var
  LLevel: TLogLevel;
  LParsed: TLogLevel;
begin
  for LLevel := Low(TLogLevel) to High(TLogLevel) do
  begin
    LParsed := TLogLevel.Off;
    LParsed.FromString(LLevel.ToString);
    Assert.AreEqual(Ord(LLevel), Ord(LParsed),
      'Round-trip failed for ' + LLevel.ToString);
  end;
end;

{ TLoggerTests }

procedure TLoggerTests.LoggerIsUsableWithoutAnyRegistration;
begin
  // The library is built around this: a logger is always available
  Assert.IsNotNull(Logger);
end;

procedure TLoggerTests.LoggerAlwaysReturnsTheSameInstance;
var
  LFirst, LSecond: ILogger;
begin
  LFirst := Logger;
  LSecond := Logger;
  Assert.IsTrue(LFirst = LSecond, 'Logger returned two different instances');
end;

procedure TLoggerTests.LoggingWithoutAdaptersDoesNothing;
var
  LLogger: ILogger;
  LException: Exception;
begin
  // A logger bound to a class nobody registered adapters for must be inert
  LLogger := TLoggerManager.GetLogger('Nobody.Listens.Here');
  LException := Exception.Create('never raised');
  try
    Assert.WillNotRaiseAny(
      procedure
      begin
        LLogger.LogTrace('trace');
        LLogger.LogInfo('info %d', [42]);
        LLogger.LogError(LException, 'error');
        LLogger.LogRawLine('raw', TLogLevel.Info);
      end);
  finally
    LException.Free;
  end;
end;

procedure TLoggerTests.GetLoggerAcceptsAClassAClassNameAndAGenericArgument;
begin
  Assert.IsNotNull(TLoggerManager.GetLogger(TStringList));
  Assert.IsNotNull(TLoggerManager.GetLogger('TStringList'));
  Assert.IsNotNull(TLoggerManager.GetLogger<TStringList>());
end;

{ TExceptionInfoTests }

procedure TExceptionInfoTests.ANilExceptionYieldsAnEmptyString;
begin
  Assert.AreEqual('', GetFullExceptionInfo(nil));
end;

procedure TExceptionInfoTests.TheClassAndMessageAreReported;
var
  LException: Exception;
begin
  LException := EListError.Create('the failure');
  try
    Assert.Contains(GetFullExceptionInfo(LException), 'EListError');
    Assert.Contains(GetFullExceptionInfo(LException), 'the failure');
  finally
    LException.Free;
  end;
end;

procedure TExceptionInfoTests.TheInnerExceptionChainIsWalked;
var
  LInfo: string;
begin
  try
    try
      raise Exception.Create('the root cause');
    except
      Exception.RaiseOuterException(EListError.Create('the outer failure'));
    end;
  except
    on E: Exception do
      LInfo := GetFullExceptionInfo(E);
  end;

  Assert.Contains(LInfo, 'the outer failure');
  Assert.Contains(LInfo, '--- Caused by');
  Assert.Contains(LInfo, 'the root cause');
end;

procedure TExceptionInfoTests.ThereIsNoTrailingLineBreak;
var
  LException: Exception;
  LInfo: string;
begin
  LException := Exception.Create('the failure');
  try
    LInfo := GetFullExceptionInfo(LException);
  finally
    LException.Free;
  end;

  Assert.IsFalse(LInfo.EndsWith(#10), 'A trailing break would produce an empty syslog record');
  Assert.IsFalse(LInfo.EndsWith(#13));
end;

{ TCategoryLoggerTests }

procedure TCategoryLoggerTests.Setup;
begin
  TLoggerAdapterRegistry.Instance.Clear;

  FCategory := UniqueName;
  FCategoryTarget := TStringList.Create;
  FDefaultTarget := TStringList.Create;

  TLoggerAdapterRegistry.Instance.RegisterFactory(FCategory,
    TLogifyAdapterBufferFactory.CreateAdapterFactory(UniqueName, TLogLevel.Trace, FCategoryTarget));
  TLoggerAdapterRegistry.Instance.RegisterFactory(DEFAULT_CATEGORY,
    TLogifyAdapterBufferFactory.CreateAdapterFactory(UniqueName, TLogLevel.Trace, FDefaultTarget));
end;

procedure TCategoryLoggerTests.TearDown;
begin
  // The registry owns the adapters writing into the targets: it has to let
  // go of them before the targets are freed
  TLoggerAdapterRegistry.Instance.Clear;
  FreeAndNil(FCategoryTarget);
  FreeAndNil(FDefaultTarget);
end;

procedure TCategoryLoggerTests.ACategoryLoggerReachesItsOwnAdapters;
begin
  TLoggerManager.GetCategoryLogger(FCategory).LogInfo('for the category');

  Assert.AreEqual(1, FCategoryTarget.Count);
  Assert.Contains(FCategoryTarget.Text, 'for the category');
end;

procedure TCategoryLoggerTests.ACategoryLoggerDoesNotReachTheDefaultAdapters;
begin
  TLoggerManager.GetCategoryLogger(FCategory).LogInfo('for the category');

  Assert.AreEqual(0, FDefaultTarget.Count,
    'A category logger must not spill into the default category');
end;

procedure TCategoryLoggerTests.TheDefaultLoggerDoesNotReachTheCategoryAdapters;
begin
  Logger.LogInfo('for the default category');

  Assert.AreEqual(1, FDefaultTarget.Count);
  Assert.AreEqual(0, FCategoryTarget.Count);
end;

procedure TCategoryLoggerTests.ACategoryLoggerStampsTheClassName;
begin
  TLoggerManager.GetCategoryLogger(FCategory, TStringList).LogInfo('from a class');

  Assert.Contains(FCategoryTarget[0], '[TStringList]');
end;

procedure TCategoryLoggerTests.TheGenericOverloadStampsTheClassName;
begin
  TLoggerManager.GetCategoryLogger<TStringList>(FCategory).LogInfo('from a generic argument');

  Assert.Contains(FCategoryTarget[0], '[TStringList]');
end;

procedure TCategoryLoggerTests.ALoggerForAnUnusedCategoryIsInert;
begin
  TLoggerManager.GetCategoryLogger('nobody-registered-this').LogError('into the void');

  Assert.AreEqual(0, FCategoryTarget.Count);
  Assert.AreEqual(0, FDefaultTarget.Count);
end;

{ TRegistryTests }

procedure TRegistryTests.Setup;
begin
  // Now that the registry can be reset, every test starts from a known state
  TLoggerAdapterRegistry.Instance.Clear;
end;

procedure TRegistryTests.TearDown;
begin
  TLoggerAdapterRegistry.Instance.Clear;
end;

function TRegistryTests.NewFactory(const AName: string): ILoggerAdapterFactory;
begin
  Result := TLogifyAdapterBufferFactory.CreateAdapterFactory(AName, TLogLevel.Trace, nil);
end;

procedure TRegistryTests.InstanceIsASingleton;
begin
  Assert.IsNotNull(TLoggerAdapterRegistry.Instance);
  Assert.AreSame(TLoggerAdapterRegistry.Instance, TLoggerAdapterRegistry.Instance);
end;

procedure TRegistryTests.FindFactoryReturnsTheRegisteredFactory;
var
  LName: string;
  LFactory: ILoggerAdapterFactory;
begin
  LName := UniqueName;
  LFactory := NewFactory(LName);
  TLoggerAdapterRegistry.Instance.RegisterFactory(UniqueName, LFactory);

  Assert.IsTrue(LFactory = TLoggerAdapterRegistry.Instance.FindFactory(LName));
end;

procedure TRegistryTests.FindFactoryReturnsNilWhenTheNameIsUnknown;
begin
  Assert.IsNull(TLoggerAdapterRegistry.Instance.FindFactory('never-registered'));
end;

procedure TRegistryTests.GetFactoryRaisesWhenTheNameIsUnknown;
begin
  Assert.WillRaise(
    procedure
    begin
      TLoggerAdapterRegistry.Instance.GetFactory('never-registered');
    end,
    ELogifyException);
end;

procedure TRegistryTests.GetLoggerAdaptersReturnsOnlyTheRequestedCategory;
var
  LWanted, LOther: string;
begin
  LWanted := UniqueName;
  LOther := UniqueName;

  TLoggerAdapterRegistry.Instance.RegisterFactory(LWanted, NewFactory(UniqueName));
  TLoggerAdapterRegistry.Instance.RegisterFactory(LOther, NewFactory(UniqueName));

  Assert.AreEqual(1, Length(TLoggerAdapterRegistry.Instance.GetLoggerAdapters(LWanted)));
  Assert.AreEqual(1, Length(TLoggerAdapterRegistry.Instance.GetLoggerAdapters(LOther)));
end;

procedure TRegistryTests.GetLoggerAdaptersReturnsNothingForAnUnusedCategory;
begin
  Assert.AreEqual(0, Length(TLoggerAdapterRegistry.Instance.GetLoggerAdapters('no-such-category')));
end;

procedure TRegistryTests.GetLoggerAdaptersCachesTheAdapterInstance;
var
  LCategory: string;
  LFirst, LSecond: TArray<ILoggerAdapter>;
begin
  LCategory := UniqueName;
  TLoggerAdapterRegistry.Instance.RegisterFactory(LCategory, NewFactory(UniqueName));

  LFirst := TLoggerAdapterRegistry.Instance.GetLoggerAdapters(LCategory);
  LSecond := TLoggerAdapterRegistry.Instance.GetLoggerAdapters(LCategory);

  Assert.AreEqual(1, Length(LFirst));
  Assert.AreEqual(1, Length(LSecond));
  Assert.IsTrue(LFirst[0] = LSecond[0],
    'The adapter should be created once and cached, not rebuilt per call');
end;

procedure TRegistryTests.RegisteringTheSameNameTwiceRaises;
var
  LName: string;
  LCategory: string;
begin
  LName := UniqueName;
  LCategory := UniqueName;
  TLoggerAdapterRegistry.Instance.RegisterFactory(LCategory, NewFactory(LName));

  // Documents current behaviour: the registry keys on the factory unique name,
  // so a clashing name is rejected even in a different category
  Assert.WillRaiseAny(
    procedure
    begin
      TLoggerAdapterRegistry.Instance.RegisterFactory(UniqueName, NewFactory(LName));
    end);
end;

procedure TRegistryTests.UnregisterFactoryRemovesIt;
var
  LName: string;
begin
  LName := UniqueName;
  TLoggerAdapterRegistry.Instance.RegisterFactory(UniqueName, NewFactory(LName));
  Assert.IsNotNull(TLoggerAdapterRegistry.Instance.FindFactory(LName));

  TLoggerAdapterRegistry.Instance.UnregisterFactory(LName);

  Assert.IsNull(TLoggerAdapterRegistry.Instance.FindFactory(LName));
end;

procedure TRegistryTests.UnregisterFactoryIgnoresAnUnknownName;
begin
  Assert.WillNotRaiseAny(
    procedure
    begin
      TLoggerAdapterRegistry.Instance.UnregisterFactory('never-registered');
      TLoggerAdapterRegistry.Instance.UnregisterFactory(ILoggerAdapterFactory(nil));
    end);
end;

procedure TRegistryTests.UnregisterFactoryAcceptsTheFactoryItself;
var
  LName: string;
  LFactory: ILoggerAdapterFactory;
begin
  LName := UniqueName;
  LFactory := NewFactory(LName);
  TLoggerAdapterRegistry.Instance.RegisterFactory(UniqueName, LFactory);

  TLoggerAdapterRegistry.Instance.UnregisterFactory(LFactory);

  Assert.IsNull(TLoggerAdapterRegistry.Instance.FindFactory(LName));
end;

procedure TRegistryTests.UnregisterFactoryDropsTheCachedAdapter;
var
  LName, LCategory: string;
  LFirst, LSecond: TArray<ILoggerAdapter>;
begin
  LName := UniqueName;
  LCategory := UniqueName;

  TLoggerAdapterRegistry.Instance.RegisterFactory(LCategory, NewFactory(LName));
  LFirst := TLoggerAdapterRegistry.Instance.GetLoggerAdapters(LCategory);

  TLoggerAdapterRegistry.Instance.UnregisterFactory(LName);
  TLoggerAdapterRegistry.Instance.RegisterFactory(LCategory, NewFactory(LName));
  LSecond := TLoggerAdapterRegistry.Instance.GetLoggerAdapters(LCategory);

  Assert.AreEqual(1, Length(LFirst));
  Assert.AreEqual(1, Length(LSecond));
  Assert.IsFalse(LFirst[0] = LSecond[0],
    'The adapter cached for the old factory must not survive the unregister');
end;

procedure TRegistryTests.AFactoryCanBeRegisteredAgainAfterUnregistering;
var
  LName: string;
begin
  LName := UniqueName;
  TLoggerAdapterRegistry.Instance.RegisterFactory(UniqueName, NewFactory(LName));
  TLoggerAdapterRegistry.Instance.UnregisterFactory(LName);

  Assert.WillNotRaiseAny(
    procedure
    begin
      TLoggerAdapterRegistry.Instance.RegisterFactory(UniqueName, NewFactory(LName));
    end);
end;

procedure TRegistryTests.UnregisterCategoryLeavesTheOtherCategoriesAlone;
var
  LDoomed, LKept: string;
begin
  LDoomed := UniqueName;
  LKept := UniqueName;

  TLoggerAdapterRegistry.Instance.RegisterFactory(LDoomed, NewFactory(UniqueName));
  TLoggerAdapterRegistry.Instance.RegisterFactory(LDoomed, NewFactory(UniqueName));
  TLoggerAdapterRegistry.Instance.RegisterFactory(LKept, NewFactory(UniqueName));

  TLoggerAdapterRegistry.Instance.UnregisterCategory(LDoomed);

  Assert.AreEqual(0, Length(TLoggerAdapterRegistry.Instance.GetLoggerAdapters(LDoomed)));
  Assert.AreEqual(1, Length(TLoggerAdapterRegistry.Instance.GetLoggerAdapters(LKept)));
end;

procedure TRegistryTests.ClearEmptiesTheRegistry;
var
  LName, LCategory: string;
begin
  LName := UniqueName;
  LCategory := UniqueName;
  TLoggerAdapterRegistry.Instance.RegisterFactory(LCategory, NewFactory(LName));
  TLoggerAdapterRegistry.Instance.GetLoggerAdapters(LCategory);

  TLoggerAdapterRegistry.Instance.Clear;

  Assert.IsNull(TLoggerAdapterRegistry.Instance.FindFactory(LName));
  Assert.AreEqual(0, Length(TLoggerAdapterRegistry.Instance.GetLoggerAdapters(LCategory)));
end;

initialization
  TDUnitX.RegisterTestFixture(TLogLevelTests);
  TDUnitX.RegisterTestFixture(TLoggerTests);
  TDUnitX.RegisterTestFixture(TExceptionInfoTests);
  TDUnitX.RegisterTestFixture(TCategoryLoggerTests);
  TDUnitX.RegisterTestFixture(TRegistryTests);

end.
