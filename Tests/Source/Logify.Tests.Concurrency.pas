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
unit Logify.Tests.Concurrency;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Threading, System.Diagnostics,
  DUnitX.TestFramework,
  Logify;

type
  /// <summary>
  ///   Thread-safe sink: counts what reached it and how many instances of
  ///   itself were ever built.
  /// </summary>
  TCountingAdapter = class(TInterfacedObject, ILoggerAdapter)
  private class var
    FWritten: Integer;
    FInstances: Integer;
  public
    constructor Create;

    { ILoggerAdapter }
    procedure WriteLog(const AClassName, AMsg: string; AException: Exception; ALevel: TLogLevel);
    procedure WriteRawLine(const AMsg: string; ALevel: TLogLevel);

    class procedure Reset;
    class function Written: Integer;
    class function Instances: Integer;
  end;

  TCountingAdapterFactory = class(TLoggerAdapterFactory)
  public
    class function CreateAdapterFactory(const AName: string): TCountingAdapterFactory;
    function CreateLoggerAdapter: ILoggerAdapter; override;
  end;

  /// <summary>
  ///   An adapter that takes its time to build, like the files one waiting for
  ///   its writer thread. Signals AEntered as soon as construction starts, so
  ///   a test can measure what happens while it is under way.
  /// </summary>
  TSlowAdapterFactory = class(TLoggerAdapterFactory)
  private
    FDelay: Cardinal;
    FEntered: TEvent;
  public
    class function CreateAdapterFactory(const AName: string; ADelay: Cardinal;
      AEntered: TEvent): TSlowAdapterFactory;
    function CreateLoggerAdapter: ILoggerAdapter; override;
  end;

  /// <summary>
  ///   The registry is a process-wide singleton reached from every logging
  ///   call, so its dictionaries have to survive concurrent use.
  /// </summary>
  [TestFixture]
  TRegistryConcurrencyTests = class
  private const
    WORKERS = 8;
    ITERATIONS = 250;
    SLOW_ADAPTER_MS = 600;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ConcurrentFirstUseBuildsExactlyOneAdapter;
    [Test]
    procedure EveryConcurrentMessageReachesTheAdapter;
    [Test]
    procedure RegisteringWhileLoggingDoesNotCorruptTheRegistry;
    [Test]
    procedure ClearingWhileLoggingDoesNotCorruptTheRegistry;
    [Test]
    procedure ConcurrentCallsToLoggerShareOneInstance;
    [Test]
    procedure BuildingASlowAdapterDoesNotBlockAnotherCategory;
    [Test]
    procedure AnAdapterBuiltAfterItsFactoryIsGoneIsNotCached;
    [Test]
    procedure AListBuiltWhileTheRegistryChangesIsNotCached;
  end;

implementation

uses
  Logify.Tests.Core;

{ TCountingAdapter }

constructor TCountingAdapter.Create;
begin
  inherited Create;
  TInterlocked.Increment(FInstances);
end;

procedure TCountingAdapter.WriteLog(const AClassName, AMsg: string; AException: Exception; ALevel: TLogLevel);
begin
  TInterlocked.Increment(FWritten);
end;

procedure TCountingAdapter.WriteRawLine(const AMsg: string; ALevel: TLogLevel);
begin
  TInterlocked.Increment(FWritten);
end;

class procedure TCountingAdapter.Reset;
begin
  TInterlocked.Exchange(FWritten, 0);
  TInterlocked.Exchange(FInstances, 0);
end;

class function TCountingAdapter.Written: Integer;
begin
  Result := TInterlocked.CompareExchange(FWritten, 0, 0);
end;

class function TCountingAdapter.Instances: Integer;
begin
  Result := TInterlocked.CompareExchange(FInstances, 0, 0);
end;

{ TCountingAdapterFactory }

class function TCountingAdapterFactory.CreateAdapterFactory(const AName: string): TCountingAdapterFactory;
begin
  Result := TCountingAdapterFactory.Create();
  Result.Name := AName;
end;

function TCountingAdapterFactory.CreateLoggerAdapter: ILoggerAdapter;
begin
  // Widens the window in which a second thread could build a rival adapter
  Sleep(5);
  Result := TCountingAdapter.Create;
end;

{ TSlowAdapterFactory }

class function TSlowAdapterFactory.CreateAdapterFactory(const AName: string;
  ADelay: Cardinal; AEntered: TEvent): TSlowAdapterFactory;
begin
  Result := TSlowAdapterFactory.Create();
  Result.Name := AName;
  Result.FDelay := ADelay;
  Result.FEntered := AEntered;
end;

function TSlowAdapterFactory.CreateLoggerAdapter: ILoggerAdapter;
begin
  FEntered.SetEvent;
  Sleep(FDelay);
  Result := TCountingAdapter.Create;
end;

{ TRegistryConcurrencyTests }

procedure TRegistryConcurrencyTests.Setup;
begin
  TLoggerAdapterRegistry.Instance.Clear;
  TCountingAdapter.Reset;
end;

procedure TRegistryConcurrencyTests.TearDown;
begin
  TLoggerAdapterRegistry.Instance.Clear;
end;

procedure TRegistryConcurrencyTests.ConcurrentFirstUseBuildsExactlyOneAdapter;
begin
  // Nothing is cached yet: every worker races to create the adapter
  TLoggerAdapterRegistry.Instance.RegisterFactory(
    TCountingAdapterFactory.CreateAdapterFactory(UniqueName));

  TParallel.For(1, WORKERS,
    procedure(AIndex: Integer)
    begin
      Logger.LogError('concurrent cold start');
    end);

  Assert.AreEqual(1, TCountingAdapter.Instances,
    'The adapter must be created once and shared, whatever the thread count');
end;

procedure TRegistryConcurrencyTests.EveryConcurrentMessageReachesTheAdapter;
begin
  TLoggerAdapterRegistry.Instance.RegisterFactory(
    TCountingAdapterFactory.CreateAdapterFactory(UniqueName));

  TParallel.For(1, WORKERS,
    procedure(AIndex: Integer)
    var
      LIndex: Integer;
    begin
      for LIndex := 1 to ITERATIONS do
        Logger.LogError('concurrent message');
    end);

  Assert.AreEqual(WORKERS * ITERATIONS, TCountingAdapter.Written);
end;

procedure TRegistryConcurrencyTests.RegisteringWhileLoggingDoesNotCorruptTheRegistry;
var
  LChurnName: string;
begin
  TLoggerAdapterRegistry.Instance.RegisterFactory(
    TCountingAdapterFactory.CreateAdapterFactory(UniqueName));
  LChurnName := UniqueName;

  Assert.WillNotRaiseAny(
    procedure
    begin
      TParallel.For(1, WORKERS,
        procedure(AIndex: Integer)
        var
          LIndex: Integer;
        begin
          // A single worker churns the registry, the others keep logging
          // through it: registration used to mutate the dictionaries while
          // another thread was walking them.
          if AIndex = 1 then
            for LIndex := 1 to ITERATIONS do
            begin
              TLoggerAdapterRegistry.Instance.RegisterFactory(
                TCountingAdapterFactory.CreateAdapterFactory(LChurnName));
              TLoggerAdapterRegistry.Instance.UnregisterFactory(LChurnName);
            end
          else
            for LIndex := 1 to ITERATIONS do
              Logger.LogError('logged during churn');
        end);
    end);

  Assert.IsTrue(TCountingAdapter.Written > 0, 'Logging should have gone through');
end;

procedure TRegistryConcurrencyTests.ClearingWhileLoggingDoesNotCorruptTheRegistry;
begin
  TLoggerAdapterRegistry.Instance.RegisterFactory(
    TCountingAdapterFactory.CreateAdapterFactory(UniqueName));

  Assert.WillNotRaiseAny(
    procedure
    begin
      TParallel.For(1, WORKERS,
        procedure(AIndex: Integer)
        var
          LIndex: Integer;
        begin
          if AIndex = 1 then
            for LIndex := 1 to ITERATIONS do
              TLoggerAdapterRegistry.Instance.Clear
          else
            for LIndex := 1 to ITERATIONS do
              Logger.LogError('logged while the registry is wiped');
        end);
    end);
end;

procedure TRegistryConcurrencyTests.ConcurrentCallsToLoggerShareOneInstance;
var
  LExpected: ILogger;
  LMismatches: Integer;
begin
  // The global logger is created on first use, so every thread hammering it
  // has to end up with the one instance that won the publication race.
  LExpected := Logger;
  LMismatches := 0;

  TParallel.For(1, WORKERS,
    procedure(AIndex: Integer)
    var
      LIndex: Integer;
    begin
      for LIndex := 1 to ITERATIONS do
        if Logger <> LExpected then
          TInterlocked.Increment(LMismatches);
    end);

  Assert.AreEqual(0, LMismatches);
end;

procedure TRegistryConcurrencyTests.BuildingASlowAdapterDoesNotBlockAnotherCategory;
var
  LEntered: TEvent;
  LSlowCategory, LFastCategory: string;
  LSlowTask: ITask;
  LWatch: TStopwatch;
  LElapsed: Int64;
begin
  // Adapters used to be built while holding the registry lock, so the first
  // log call of a slow adapter (the files one waits up to 5 s for its writer)
  // stalled every other logging thread in the process.
  LSlowCategory := UniqueName;
  LFastCategory := UniqueName;

  LEntered := TEvent.Create(nil, True, False, '');
  try
    TLoggerAdapterRegistry.Instance.RegisterFactory(LSlowCategory,
      TSlowAdapterFactory.CreateAdapterFactory(UniqueName, SLOW_ADAPTER_MS, LEntered));
    TLoggerAdapterRegistry.Instance.RegisterFactory(LFastCategory,
      TCountingAdapterFactory.CreateAdapterFactory(UniqueName));

    LSlowTask := TTask.Run(
      procedure
      begin
        TLoggerManager.GetCategoryLogger(LSlowCategory).LogError('cold start of a slow adapter');
      end);
    try
      Assert.IsTrue(LEntered.WaitFor(5000) = TWaitResult.wrSignaled,
        'The slow adapter never started building');

      // Timed while the slow constructor is provably still running
      LWatch := TStopwatch.StartNew;
      TLoggerManager.GetCategoryLogger(LFastCategory).LogError('must not wait for the other category');
      LElapsed := LWatch.ElapsedMilliseconds;
    finally
      LSlowTask.Wait;
    end;

    Assert.IsTrue(LElapsed < SLOW_ADAPTER_MS div 2,
      Format('Logging waited %d ms for an unrelated adapter to be built', [LElapsed]));
  finally
    LEntered.Free;
  end;
end;

procedure TRegistryConcurrencyTests.AnAdapterBuiltAfterItsFactoryIsGoneIsNotCached;
var
  LEntered: TEvent;
  LCategory, LName: string;
  LSlowTask: ITask;
begin
  // Adapters are built outside the registry lock, so the registry can move
  // under a construction that is already under way: whatever comes out of it
  // must not be filed under a name that no longer belongs to that factory.
  LCategory := UniqueName;
  LName := UniqueName;

  LEntered := TEvent.Create(nil, True, False, '');
  try
    TLoggerAdapterRegistry.Instance.RegisterFactory(LCategory,
      TSlowAdapterFactory.CreateAdapterFactory(LName, SLOW_ADAPTER_MS, LEntered));

    LSlowTask := TTask.Run(
      procedure
      begin
        TLoggerManager.GetCategoryLogger(LCategory).LogError('built while being unregistered');
      end);
    try
      Assert.IsTrue(LEntered.WaitFor(5000) = TWaitResult.wrSignaled,
        'The slow adapter never started building');

      // The factory goes away while its adapter is still being constructed
      TLoggerAdapterRegistry.Instance.UnregisterFactory(LName);
    finally
      LSlowTask.Wait;
    end;

    Assert.IsNull(TLoggerAdapterRegistry.Instance.FindLoggerAdapter(LName),
      'the adapter of an unregistered factory was published into the cache');
  finally
    LEntered.Free;
  end;
end;

procedure TRegistryConcurrencyTests.AListBuiltWhileTheRegistryChangesIsNotCached;
var
  LEntered: TEvent;
  LCategory: string;
  LSlowTask: ITask;
  LBefore: Integer;
begin
  // Same window, seen from the category cache: a list assembled outside the
  // lock is stale if a factory joined the category meanwhile, and caching it
  // would hide that factory from every later call.
  LCategory := UniqueName;

  LEntered := TEvent.Create(nil, True, False, '');
  try
    TLoggerAdapterRegistry.Instance.RegisterFactory(LCategory,
      TSlowAdapterFactory.CreateAdapterFactory(UniqueName, SLOW_ADAPTER_MS, LEntered));

    LSlowTask := TTask.Run(
      procedure
      begin
        TLoggerManager.GetCategoryLogger(LCategory).LogError('the first message of the category');
      end);
    try
      Assert.IsTrue(LEntered.WaitFor(5000) = TWaitResult.wrSignaled,
        'The slow adapter never started building');

      // A second adapter joins the category while the first list is being built
      TLoggerAdapterRegistry.Instance.RegisterFactory(LCategory,
        TCountingAdapterFactory.CreateAdapterFactory(UniqueName));
    finally
      LSlowTask.Wait;
    end;

    LBefore := TCountingAdapter.Written;
    TLoggerManager.GetCategoryLogger(LCategory).LogError('both adapters must see this');

    Assert.AreEqual(2, TCountingAdapter.Written - LBefore,
      'a stale list was cached: the factory registered during the build is missing');
  finally
    LEntered.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRegistryConcurrencyTests);

end.
