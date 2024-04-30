unit Test.Form.Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,

  Logify,
  Logify.Logger.Buffer,
  Logify.Logger.OutputDebug;

type
  TDebugLogFactory = class(TLoggerFactory)
    function CreateLogger: ILogger; override;
  end;

  TBufferLogFactory = class(TLoggerFactory)
    function CreateLogger: ILogger; override;
  end;

  TfrmMain = class(TForm)
    btnLogTrace: TButton;
    btnDebugLogger: TButton;
    memoLog: TMemo;
    btnBufferLogger: TButton;
    btnLogDebug: TButton;
    procedure btnBufferLoggerClick(Sender: TObject);
    procedure btnDebugLoggerClick(Sender: TObject);
    procedure btnLogDebugClick(Sender: TObject);
    procedure btnLogTraceClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

procedure TfrmMain.btnBufferLoggerClick(Sender: TObject);
begin
  TLoggerRegistry.Instance.RegisterFactoryClass(TBufferLogFactory);
end;

procedure TfrmMain.btnDebugLoggerClick(Sender: TObject);
begin
  TLoggerRegistry.Instance.RegisterFactoryClass(TDebugLogFactory);
end;

procedure TfrmMain.btnLogDebugClick(Sender: TObject);
begin
  Logger.LogDebug('Debugging some code');
end;

procedure TfrmMain.btnLogTraceClick(Sender: TObject);
begin
  Logger.LogTrace('Tracing something');
end;

{ TDebugLogFactory }

function TDebugLogFactory.CreateLogger: ILogger;
begin
  Result := TOutputDebugLogger.Create;
end;

{ TBufferLogFactory }

function TBufferLogFactory.CreateLogger: ILogger;
begin
  var logger := TBufferLogger.Create;
  logger.SetDestination(frmMain.memoLog.Lines);
  Result := logger;
end;

end.
