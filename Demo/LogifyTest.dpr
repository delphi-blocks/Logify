program LogifyTest;

uses
  Vcl.Forms,
  Test.Form.Main in 'Test.Form.Main.pas' {frmMain},
  Logify.Logger.Buffer in '..\Logify.Logger.Buffer.pas',
  Logify.Logger.OutputDebug in '..\Logify.Logger.OutputDebug.pas',
  Logify in '..\Logify.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
