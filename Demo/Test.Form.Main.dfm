object frmMain: TfrmMain
  Left = 0
  Top = 0
  Margins.Left = 8
  Caption = 'Test Logify'
  ClientHeight = 502
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
    Top = 109
    Width = 75
    Height = 25
    Caption = 'LogTrace'
    TabOrder = 0
    OnClick = btnLogTraceClick
  end
  object btnDebugLogger: TButton
    Left = 8
    Top = 24
    Width = 137
    Height = 25
    Caption = 'Register Debug Logger'
    TabOrder = 1
    OnClick = btnDebugLoggerClick
  end
  object memoLog: TMemo
    AlignWithMargins = True
    Left = 8
    Top = 140
    Width = 724
    Height = 354
    Margins.Left = 8
    Margins.Right = 8
    Margins.Bottom = 8
    Align = alBottom
    Anchors = [akLeft, akTop, akRight, akBottom]
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -16
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    TabOrder = 2
    ExplicitLeft = 0
    ExplicitTop = 135
    ExplicitWidth = 740
    ExplicitHeight = 344
  end
  object btnBufferLogger: TButton
    Left = 151
    Top = 24
    Width = 137
    Height = 25
    Caption = 'Register Buffer Logger'
    TabOrder = 3
    OnClick = btnBufferLoggerClick
  end
  object btnLogDebug: TButton
    Left = 89
    Top = 109
    Width = 75
    Height = 25
    Caption = 'LogDebug'
    TabOrder = 4
    OnClick = btnLogDebugClick
  end
end
