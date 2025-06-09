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
program LogifyTest;

uses
  Vcl.Forms,
  Test.Form.Main in 'Test.Form.Main.pas' {frmMain},
  Logify.Adapter.Buffer in '..\Source\Logify.Adapter.Buffer.pas',
  Logify.Adapter.Console in '..\Source\Logify.Adapter.Console.pas',
  Logify.Adapter.Debug in '..\Source\Logify.Adapter.Debug.pas',
  Logify.Adapter.Files in '..\Source\Logify.Adapter.Files.pas',
  Logify in '..\Source\Logify.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
