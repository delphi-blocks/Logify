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
  System.SysUtils, System.Classes, System.SyncObjs, System.Threading,
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
  ///   The registry is a process-wide singleton reached from every logging
  ///   call, so its dictionaries have to survive concurrent use.
  /// </summary>
  [TestFixture]
  TRegistryConcurrencyTests = class
  private const
    WORKERS = 8;
    ITERATIONS = 250;
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

initialization
  TDUnitX.RegisterTestFixture(TRegistryConcurrencyTests);

end.
