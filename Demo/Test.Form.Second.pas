unit Test.Form.Second;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs,

  Logify, Vcl.StdCtrls;

type
  TfrmSecond = class(TForm)
    Button1: TButton;
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    MyLogger: ILogger;
  public
    { Public declarations }
  end;

var
  frmSecond: TfrmSecond;

implementation

{$R *.dfm}

procedure TfrmSecond.Button1Click(Sender: TObject);
begin
  MyLogger.LogDebug('Debug Log from the second from (MyLogger)');

  //MyLogger.LogDebug('My Logger Pointer: %d', [Integer(MyLogger)]);
end;

procedure TfrmSecond.FormCreate(Sender: TObject);
begin
  MyLogger := TLoggerManager.GetLogger(Self.ClassType);
end;

end.
