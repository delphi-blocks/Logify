object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'Test Logify'
  ClientHeight = 479
  ClientWidth = 740
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  TextHeight = 15
  object btnLogTrace: TButton
    Left = 8
    Top = 176
    Width = 75
    Height = 25
    Caption = 'LogTrace'
    TabOrder = 0
    OnClick = btnLogTraceClick
  end
  object btnDebugLogger: TButton
    Left = 8
    Top = 24
    Width = 185
    Height = 25
    Caption = 'Register Debug Logger'
    TabOrder = 1
    OnClick = btnDebugLoggerClick
  end
  object memoLog: TMemo
    Left = 0
    Top = 216
    Width = 740
    Height = 263
    Align = alBottom
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -16
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    TabOrder = 2
  end
  object btnBufferLogger: TButton
    Left = 8
    Top = 55
    Width = 185
    Height = 25
    Caption = 'Register Buffer Logger'
    TabOrder = 3
    OnClick = btnBufferLoggerClick
  end
end
