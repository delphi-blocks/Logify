object frmMain: TfrmMain
  Left = 0
  Top = 0
  Margins.Left = 8
  Caption = 'Logify Demo'
  ClientHeight = 440
  ClientWidth = 919
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnShow = FormShow
  TextHeight = 15
  object btnLog: TButton
    Left = 207
    Top = 16
    Width = 101
    Height = 25
    Caption = 'Log Message'
    TabOrder = 0
    OnClick = btnLogClick
  end
  object btnDebugLogger: TButton
    Left = 448
    Top = 16
    Width = 137
    Height = 25
    Caption = 'Register Debug Logger'
    TabOrder = 1
    OnClick = btnDebugLoggerClick
  end
  object memoLog: TMemo
    AlignWithMargins = True
    Left = 8
    Top = 160
    Width = 903
    Height = 272
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
    Left = 448
    Top = 47
    Width = 137
    Height = 25
    Caption = 'Register Buffer Logger'
    TabOrder = 3
    OnClick = btnBufferLoggerClick
  end
  object btnLogException: TButton
    Left = 207
    Top = 47
    Width = 101
    Height = 25
    Caption = 'Log Exception'
    TabOrder = 4
    OnClick = btnLogExceptionClick
  end
  object btnLogFmt: TButton
    Left = 207
    Top = 78
    Width = 101
    Height = 25
    Caption = 'Log Formatted'
    TabOrder = 5
    OnClick = btnLogFmtClick
  end
  object btnMyLogger: TButton
    Left = 207
    Top = 109
    Width = 101
    Height = 25
    Caption = 'MyLogger Test'
    TabOrder = 6
    OnClick = btnMyLoggerClick
  end
  object grpLevel: TGroupBox
    Left = 8
    Top = 8
    Width = 185
    Height = 129
    Caption = 'Log Level '
    TabOrder = 7
    object rbLevelTrace: TRadioButton
      Left = 16
      Top = 30
      Width = 113
      Height = 17
      Caption = 'Trace'
      Checked = True
      TabOrder = 0
      TabStop = True
    end
    object rbLevelDebug: TRadioButton
      Left = 16
      Top = 53
      Width = 113
      Height = 17
      Caption = 'Debug'
      TabOrder = 1
    end
    object rbLevelInfo: TRadioButton
      Left = 16
      Top = 76
      Width = 113
      Height = 17
      Caption = 'Info'
      TabOrder = 2
    end
    object rbLevelWarning: TRadioButton
      Left = 96
      Top = 30
      Width = 113
      Height = 17
      Caption = 'Warning'
      TabOrder = 3
    end
    object rbLevelError: TRadioButton
      Left = 96
      Top = 53
      Width = 113
      Height = 17
      Caption = 'Error'
      TabOrder = 4
    end
    object rbLevelCritical: TRadioButton
      Left = 96
      Top = 76
      Width = 113
      Height = 17
      Caption = 'Critical'
      TabOrder = 5
    end
    object rbLevelOff: TRadioButton
      Left = 56
      Top = 99
      Width = 113
      Height = 17
      Caption = 'Off'
      TabOrder = 6
    end
  end
  object btnFileLogger: TButton
    Left = 448
    Top = 78
    Width = 137
    Height = 25
    Caption = 'Register File Logger'
    TabOrder = 8
    OnClick = btnFileLoggerClick
  end
  object ApplicationEvents1: TApplicationEvents
    Left = 464
    Top = 296
  end
end
