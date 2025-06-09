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
    Left = 480
    Top = 8
    Width = 75
    Height = 25
    Caption = 'LogTrace'
    TabOrder = 0
    OnClick = btnLogTraceClick
  end
  object btnDebugLogger: TButton
    Left = 8
    Top = 8
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
  end
  object btnBufferLogger: TButton
    Left = 8
    Top = 39
    Width = 137
    Height = 25
    Caption = 'Register Buffer Logger'
    TabOrder = 3
    OnClick = btnBufferLoggerClick
  end
  object btnLogDebug: TButton
    Left = 480
    Top = 39
    Width = 75
    Height = 25
    Caption = 'LogDebug'
    TabOrder = 4
    OnClick = btnLogDebugClick
  end
  object btnLogInfo: TButton
    Left = 480
    Top = 70
    Width = 75
    Height = 25
    Caption = 'LogInfo'
    TabOrder = 5
    OnClick = btnLogInfoClick
  end
  object btnLogWarning: TButton
    Left = 480
    Top = 104
    Width = 75
    Height = 25
    Caption = 'LogWarning'
    TabOrder = 6
    OnClick = btnLogWarningClick
  end
  object btnLogTraceEx: TButton
    Left = 587
    Top = 8
    Width = 145
    Height = 25
    Caption = 'LogTrace+Exception'
    TabOrder = 7
    OnClick = btnLogTraceExClick
  end
  object btnLogDebugEx: TButton
    Left = 587
    Top = 39
    Width = 145
    Height = 25
    Caption = 'LogDebug+Exception'
    TabOrder = 8
  end
end
