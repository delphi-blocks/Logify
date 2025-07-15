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
program DemoUI;

uses
  Vcl.Forms,
  Logify in '..\..\Source\Logify.pas',
  Logify.Adapter.Buffer in '..\..\Source\Logify.Adapter.Buffer.pas',
  Logify.Adapter.Console in '..\..\Source\Logify.Adapter.Console.pas',
  Logify.Adapter.Debug in '..\..\Source\Logify.Adapter.Debug.pas',
  Logify.Adapter.Files in '..\..\Source\Logify.Adapter.Files.pas',
  Demo.Form.Main in 'Demo.Form.Main.pas' {frmMain},
  Demo.Form.Second in 'Demo.Form.Second.pas' {frmSecond};

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.CreateForm(TfrmSecond, frmSecond);
  Application.Run;
end.
