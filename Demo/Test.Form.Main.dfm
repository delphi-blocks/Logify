object frmMain: TfrmMain
  Left = 0
  Top = 0
  Margins.Left = 8
  Caption = 'Logify Demo'
  ClientHeight = 413
  ClientWidth = 925
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnShow = FormShow
  DesignSize = (
    925
    413)
  TextHeight = 15
  object btnLogTrace: TButton
    Left = 665
    Top = 8
    Width = 75
    Height = 25
    Anchors = [akTop, akRight]
    Caption = 'LogTrace'
    TabOrder = 0
    OnClick = btnLogTraceClick
    ExplicitLeft = 725
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
    Width = 909
    Height = 265
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
    ExplicitWidth = 724
    ExplicitHeight = 354
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
    Left = 665
    Top = 39
    Width = 75
    Height = 25
    Anchors = [akTop, akRight]
    Caption = 'LogDebug'
    TabOrder = 4
    OnClick = btnLogDebugClick
    ExplicitLeft = 725
  end
  object btnLogInfo: TButton
    Left = 665
    Top = 70
    Width = 75
    Height = 25
    Anchors = [akTop, akRight]
    Caption = 'LogInfo'
    TabOrder = 5
    OnClick = btnLogInfoClick
    ExplicitLeft = 725
  end
  object btnLogWarning: TButton
    Left = 665
    Top = 104
    Width = 75
    Height = 25
    Anchors = [akTop, akRight]
    Caption = 'LogWarning'
    TabOrder = 6
    OnClick = btnLogWarningClick
    ExplicitLeft = 725
  end
  object btnLogTraceEx: TButton
    Left = 772
    Top = 8
    Width = 145
    Height = 25
    Anchors = [akTop, akRight]
    Caption = 'LogTrace+Exception'
    TabOrder = 7
    OnClick = btnLogTraceExClick
    ExplicitLeft = 832
  end
  object btnLogDebugEx: TButton
    Left = 772
    Top = 39
    Width = 145
    Height = 25
    Anchors = [akTop, akRight]
    Caption = 'LogDebug+Exception'
    TabOrder = 8
    OnClick = btnLogDebugExClick
    ExplicitLeft = 832
  end
  object btnMyLogger: TButton
    Left = 312
    Top = 8
    Width = 105
    Height = 25
    Caption = 'MyLogger Test'
    TabOrder = 9
    OnClick = btnMyLoggerClick
  end
  object ApplicationEvents1: TApplicationEvents
    Left = 328
    Top = 96
  end
end
