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
program DemoFormat;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Logify,
  Logify.Adapter.Console;

type
  /// <summary>
  ///   Formatter that overrides a single piece: the level name, padded to a
  ///   fixed width so the message column stays aligned. Everything else
  ///   keeps the default shape.
  /// </summary>
  TPaddedLevelFormatter = class(TLoggerFormatter)
  protected
    function FormatLevel(ALevel: TLogLevel): string; override;
  end;

  /// <summary>
  ///   Formatter that overrides the whole line layout: time, level and
  ///   message, no thread id or class name. Exceptions still render through
  ///   FormatException (the canonical exception renderer).
  /// </summary>
  TCompactFormatter = class(TLoggerFormatter)
  public
    function FormatMsg(const AMessage, AClassName: string; AException: Exception; ALevel: TLogLevel): string; override;
  end;

{ TPaddedLevelFormatter }

function TPaddedLevelFormatter.FormatLevel(ALevel: TLogLevel): string;
begin
  Result := ALevel.ToString.PadRight(8);
end;

{ TCompactFormatter }

function TCompactFormatter.FormatMsg(const AMessage, AClassName: string;
    AException: Exception; ALevel: TLogLevel): string;
begin
  Result := Format('%s [%s] %s', [FormatDateTime('hh:nn:ss', Now), ALevel.ToString, AMessage]);
  if AException <> nil then
    Result := Result + sLineBreak + FormatException(AException);
end;

procedure PrintBanner(const ABanner: string);
begin
  Writeln;
  Writeln('============================================================');
  Writeln(ABanner);
  Writeln('============================================================');
end;

/// <summary>
///   Raises EListError whose chain is EListError -> EArgumentException ->
///   EConvertError, nested through Exception.RaiseOuterException.
/// </summary>
procedure RaiseThreeLevelChain;
begin
  try
    try
      raise EConvertError.Create('the root cause');
    except
      Exception.RaiseOuterException(EArgumentException.Create('a middle layer failed'));
    end;
  except
    Exception.RaiseOuterException(EListError.Create('the operation failed'));
  end;
end;

var
  LRegistry: TLoggerAdapterRegistry;
  LAdapters: TArray<ILoggerAdapter>;
  LException: Exception;
begin
  LRegistry := TLoggerAdapterRegistry.Instance;

  { ------------------------------------------------------------------ }
  { Section 1: the default layout                                      }
  { ------------------------------------------------------------------ }
  LRegistry.RegisterFactory(
    TLogifyAdapterConsoleFactory.CreateAdapterFactory('default-layout', TLogLevel.Trace));

  PrintBanner('Section 1 - The default layout');
  Logger.LogInfo('a plain message');
  Logger.LogWarning('a warning with %s formatting', ['arguments']);
  Logger.LogError('an error, no exception attached');

  // Class-stamped loggers: the qualified class name is stamped and the
  // layout keeps only the part after the last dot
  TLoggerManager.GetLogger('Demo.Format.TFormatDemo').LogInfo('stamped with the class name');

  Logger.LogRawLine('=== a raw line: no timestamp, no level, no class ===', TLogLevel.Info);

  { ------------------------------------------------------------------ }
  { Section 2: exceptions and InnerException chains                    }
  { ------------------------------------------------------------------ }
  PrintBanner('Section 2 - Exceptions and InnerException chains');

  LException := EAccessViolation.Create('a single exception, no inner');
  try
    Logger.LogError(LException, 'one exception, no InnerException');
  finally
    LException.Free;
  end;

  try
    RaiseThreeLevelChain;
  except
    on E: Exception do
      Logger.LogCritical(E, 'a three-level InnerException chain');
  end;

  // No stack-trace provider (JCL, MadExcept...) is installed in this demo,
  // so each entry shows class + message only; with a provider the frames
  // would appear indented underneath their entry.

  { ------------------------------------------------------------------ }
  { Section 3: a custom formatter on one adapter, swapped on the fly    }
  { ------------------------------------------------------------------ }
  LRegistry.RegisterFactory('padded',
    TLogifyAdapterConsoleFactory.CreateAdapterFactory('padded-layout', TLogLevel.Trace));

  // Adapters are created lazily on first use; materialize this one now to
  // reach its Formatter property before anything is logged through it
  LAdapters := LRegistry.GetLoggerAdapters('padded');
  (LAdapters[0] as TLoggerAdapterHelper).Formatter := TPaddedLevelFormatter.Create;

  PrintBanner('Section 3 - TPaddedLevelFormatter: one piece overridden');
  TLoggerManager.GetCategoryLogger('padded').LogInfo('the level is padded');
  TLoggerManager.GetCategoryLogger('padded').LogError('so the message column stays aligned');

  (LAdapters[0] as TLoggerAdapterHelper).Formatter := TCompactFormatter.Create;
  PrintBanner('Section 3b - TCompactFormatter: whole layout overridden');
  TLoggerManager.GetCategoryLogger('padded').LogInfo('compact: time, level, message');
  try
    RaiseThreeLevelChain;
  except
    on E: Exception do
      TLoggerManager.GetCategoryLogger('padded').LogError(E, 'same chain, compact layout');
  end;

  { ------------------------------------------------------------------ }
  { Section 4: a registry-wide formatter class                         }
  { ------------------------------------------------------------------ }
  PrintBanner('Section 4 - TLoggerAdapterRegistry.FormatterClass');
  LRegistry.FormatterClass := TCompactFormatter;
  try
    LRegistry.RegisterFactory('compact',
      TLogifyAdapterConsoleFactory.CreateAdapterFactory('compact-layout', TLogLevel.Trace));

    // This adapter is created only now, after FormatterClass was set, so it
    // is born with the compact formatter
    TLoggerManager.GetCategoryLogger('compact').LogInfo('created after FormatterClass was set');
    try
      RaiseThreeLevelChain;
    except
      on E: Exception do
        TLoggerManager.GetCategoryLogger('compact').LogError(E, 'so this chain is compact too');
    end;
  finally
    // Existing adapters keep their formatter; only new ones would change
    LRegistry.FormatterClass := TLoggerFormatter;
  end;

  Writeln;
  Writeln('Demo complete.');
  // Pause when run interactively; pass --auto (scripts) to skip it
  if (ParamCount = 0) or (ParamStr(1) <> '--auto') then
  begin
    Write('Press Enter to exit...');
    Readln;
  end;
end.
