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
unit Test.Form.Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.AppEvnts,

  Logify,
  Logify.Adapter.Files,
  Logify.Adapter.Buffer,
  Logify.Adapter.Console,
  Logify.Adapter.Debug;

type
  TfrmMain = class(TForm)
    btnLog: TButton;
    btnDebugLogger: TButton;
    memoLog: TMemo;
    btnBufferLogger: TButton;
    btnLogException: TButton;
    btnLogFmt: TButton;
    ApplicationEvents1: TApplicationEvents;
    btnMyLogger: TButton;
    grpLevel: TGroupBox;
    rbLevelTrace: TRadioButton;
    rbLevelDebug: TRadioButton;
    rbLevelInfo: TRadioButton;
    rbLevelWarning: TRadioButton;
    rbLevelError: TRadioButton;
    rbLevelCritical: TRadioButton;
    rbLevelOff: TRadioButton;
    btnFileLogger: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnBufferLoggerClick(Sender: TObject);
    procedure btnDebugLoggerClick(Sender: TObject);
    procedure btnFileLoggerClick(Sender: TObject);
    procedure btnLogFmtClick(Sender: TObject);
    procedure btnLogClick(Sender: TObject);
    procedure btnLogExceptionClick(Sender: TObject);
    procedure btnMyLoggerClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    MyLogger: ILogger;

    function GetLevel: TLogLevel;
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

uses
  Test.Form.Second;

{$R *.dfm}

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  MyLogger := TLoggerManager.GetLogger(Self.ClassType);
end;

procedure TfrmMain.btnBufferLoggerClick(Sender: TObject);
begin
  TLoggerAdapterRegistry.Instance.RegisterFactory(
    TLogifyAdapterBufferFactory.CreateAdapterFactory(
      TLogLevel.Trace, memoLog.Lines));
end;

procedure TfrmMain.btnDebugLoggerClick(Sender: TObject);
begin
  TLoggerAdapterRegistry.Instance.RegisterFactory(
    TLogifyAdapterDebugFactory.CreateAdapterFactory(
      TLogLevel.Trace));
end;

procedure TfrmMain.btnFileLoggerClick(Sender: TObject);
begin
  TLoggerAdapterRegistry.Instance.RegisterFactory(
    TLogifyAdapterFilesFactory.CreateAdapterFactory(
      'default', procedure(var AConfig: TFileLogConfig)
      begin
        AConfig.Level := TLogLevel.Trace;
        AConfig.Append := True;
        AConfig.SetLogName('filetest');
        AConfig.Path := '../../';
        AConfig.Ext := 'log';
      end
  ));
end;

procedure TfrmMain.btnLogClick(Sender: TObject);
begin
  Logger.Log('Log Message', GetLevel);
end;

procedure TfrmMain.btnLogFmtClick(Sender: TObject);
begin
  Logger.Log('Formatted Log Message %d', [Random(100)], GetLevel);
end;

procedure TfrmMain.btnLogExceptionClick(Sender: TObject);
begin
  try
    raise Exception.Create('Application Error Message');
  except
    on E: Exception do
      Logger.Log(E, 'My Error Message', GetLevel);
  end;
end;

procedure TfrmMain.btnMyLoggerClick(Sender: TObject);
begin
  MyLogger.Log('My Message is: %s', ['Test Message'], GetLevel);

//  MyLogger.LogCritical('MyLogger Pointer: %d', [Integer(MyLogger)]);
//  Logger.LogCritical('Logger Pointer: %d', [Integer(Logger)]);
end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
  frmSecond.Show;
end;

function TfrmMain.GetLevel: TLogLevel;
begin
  Result := TLogLevel.Trace;

  if rbLevelTrace.Checked then
    Exit(TLogLevel.Trace);

  if rbLevelDebug.Checked then
    Exit(TLogLevel.Debug);

  if rbLevelInfo.Checked then
    Exit(TLogLevel.Info);

  if rbLevelWarning.Checked then
    Exit(TLogLevel.Warning);

  if rbLevelError.Checked then
    Exit(TLogLevel.Error);

  if rbLevelCritical.Checked then
    Exit(TLogLevel.Critical);

  if rbLevelOff.Checked then
    Exit(TLogLevel.Off);
end;

end.
