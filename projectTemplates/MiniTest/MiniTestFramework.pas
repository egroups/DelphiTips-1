unit MiniTestFramework;

interface

{$IFDEF VER120} {$DEFINE BEFOREVARIANTS} {$ENDIF}
{$IFDEF VER130} {$DEFINE BEFOREVARIANTS} {$ENDIF}

uses SysUtils, windows
{$IFNDEF BEFOREVARIANTS}
    , Variants
{$ENDIF}
    ;

Const
  FRAMEWORK_VERSION = '2.0.0.1';
  DEFAULT_TOTALS_FORMAT =
    'Run>Sets:%-3d Cases:%-3d Tests:%-4d Passed:%-4d Failed:%-3d Skipped:%-3d Errors:%-3d';
  DEFAULT_SET_FORMAT =
    'Set>Cases:%-4d Tests:%-4d Passed:%-4d Failed:%-4d Skipped:%-4d Errors:%-4d';
  DEFAULT_CASE_FORMAT =
    '  Results> Passed:%-5d Failed:%-5d Skipped:%-5d Errors:%-5d';
  DEFAULT_SET_NAME = 'SET';
  FINAL_SET_NAME = '__';

  PASS_FAIL: array [0 .. 3] of string = ('PASS', 'SKIP', 'FAIL', 'ERR ');
  FOREGROUND_DEFAULT = 7;

  DEFAULT_SCREEN_WIDTH = 80;
  FOREGROUND_CYAN = 3;
  FOREGROUND_YELLOW = 6;
  FOREGROUND_PURPLE = 5;

  clTitle = FOREGROUND_YELLOW;
  clError = FOREGROUND_RED or FOREGROUND_INTENSITY;
  clPass = FOREGROUND_GREEN;
  clMessage = FOREGROUND_CYAN;
  clDefault = FOREGROUND_DEFAULT;
  clSkipped = FOREGROUND_PURPLE;

Type
  TComparitorType = Variant;

  TTestCaseProcedure = Procedure();

  TSkipType = (skipFalse, skipTrue, skipCase);

  TTestSet = Record
    SetName: string;
    Execute: TTestCaseProcedure;
    TestCaseName: string;
    Skip: TSkipType;
    ExpectedException: string;
  end;

const
  SKIPPED = skipTrue;
  Skip = skipTrue; // alternate

var
  MiniTestCases: Array of TTestSet;

  SkippingSet, IgnoreSkip: boolean;
  CreatingSets: boolean = false;

  ExpectedException, ExpectedSetException, LastSetName, CurrentSetName,
    CurrentTestCaseName, CurrentTestCaseLabel: string;
  TotalPassedTests: integer = 0;
  TotalFailedTests: integer = 0;
  TotalSkippedTests: integer = 0;
  TotalErroredTests: integer = 0;
  TotalCases: integer = 0;
  TotalSets: integer = 0;

  CasePassedTests, CaseFailedTests, CaseErrors, CaseSkippedTests: integer;
  SetCases, SetPassedTests, SetFailedTests, SetErrors, SetSkippedTests: integer;

  TotalOutputFormat, SetOutputFormat, CaseOutputFormat: string;

Procedure Title(AText: string);

Procedure AddTestSet(ATestCaseName: string; AProcedure: TTestCaseProcedure;
  ASkipped: TSkipType = skipFalse; AExpectedException: string = '');
{$IFNDEF BEFOREVARIANTS}deprecated; {$ENDIF} // wrong naming convention.
Procedure AddTestCase(ATestCaseName: string; AProcedure: TTestCaseProcedure;
  ASkipped: TSkipType = skipFalse; AExpectedException: string = '');
Procedure PrepareSet(AProcedure: TTestCaseProcedure);
Procedure FinaliseSet(AProcedure: TTestCaseProcedure);
Procedure FinalizeSet(AProcedure: TTestCaseProcedure);
Procedure RunTestSets;
Procedure SkipTestCases(ACaseId: integer);

Procedure NewTest(ACase: string; ATestCaseName: string = '');
Procedure NewSet(ASetName: string);
Procedure NewCase(ATestCaseName: string);
Procedure NewTestCase(ACase: string; ATestCaseName: string = '');
{$IFNDEF BEFOREVARIANTS}deprecated; {$ENDIF} // wrong naming convention.
Procedure NextTestSet(ASetName: string);
Procedure NextTestCase(ACaseName: string; ASkipped: TSkipType = skipFalse);
Function CheckIsEqual(AExpected, AResult: TComparitorType;
  AMessage: string = ''; ASkipped: TSkipType = skipFalse): boolean;
Function CheckIsTrue(AResult: boolean; AMessage: string = '';
  ASkipped: TSkipType = skipFalse): boolean;
Function CheckIsFalse(AResult: boolean; AMessage: string = '';
  ASkipped: TSkipType = skipFalse): boolean;
Function CheckNotEqual(AResult1, AResult2: TComparitorType;
  AMessage: string = ''; ASkipped: TSkipType = skipFalse): boolean;
Procedure ExpectException(AExceptionClassName: string;
  AExpectForSet: boolean = false);
Procedure CheckException(AException: Exception);
Function NotImplemented(AMessage: string = ''): boolean;
Function DontSkip: TSkipType;
Function TotalTests: integer;
Procedure TestSummary;
procedure CaseResults;
Function ConsoleScreenWidth: integer;
Procedure Print(AText: String; AColour: smallint = FOREGROUND_DEFAULT);
Procedure PrintLn(AText: String; AColour: smallint = FOREGROUND_DEFAULT);

implementation

Const
  NIL_EXCEPTION_CLASSNAME = 'NilException';
  NO_EXCEPTION_EXPECTED = 'No Exceptions';

Type
  TCheckTestType = (cttComparison, cttSkip, cttException);

{$IFDEF BEFOREVARIANTS}
  TvarType = integer;
{$ENDIF}

var
  SameTestCounter: integer = 0;
  LastTestCaseLabel: string;
  SetCounter: integer = 0;

  /// ////////  SCREEN MANAGEMENT \\\\\\\\\\\\\\\\\

var
  Screen_width: integer = -1;
  Console_Handle: THandle = 0;

Function CanDisplayCaseName(ACaseName: string): boolean;
begin
  Result := (ACaseName <> '') and (not(CreatingSets));
end;

Function NextSetName: string;
begin
  inc(SetCounter);
  Result := Format(DEFAULT_SET_NAME + ' %u', [SetCounter]);
end;

Function TotalTests: integer;
begin
  Result := TotalPassedTests + TotalFailedTests + TotalSkippedTests +
    TotalErroredTests + CasePassedTests + CaseFailedTests + CaseSkippedTests +
    CaseErrors;
end;

Function ConsoleHandle: THandle;
begin
  if Console_Handle = 0 then
    Console_Handle := GetStdHandle(STD_OUTPUT_HANDLE);
  Result := Console_Handle;
end;

procedure DoubleLine;
begin
  PrintLn(stringofchar('=', ConsoleScreenWidth));
end;

procedure SingleLine;
begin
  PrintLn(stringofchar('-', ConsoleScreenWidth));
end;

Procedure SetTextColour(AColour: smallint);
begin
  SetConsoleTextAttribute(ConsoleHandle, AColour);
end;

Function ConsoleScreenWidth: integer;
var
  lScreenInfo: TConsoleScreenBufferInfo;
begin
  if Screen_width = -1 then
  begin
    try
      GetConsoleScreenBufferInfo(ConsoleHandle, lScreenInfo);
      Screen_width := lScreenInfo.dwSize.X - 2;
    except
      Screen_width := DEFAULT_SCREEN_WIDTH;
    end;
  end;
  Result := Screen_width;
end;

Procedure Print(AText: String; AColour: smallint = FOREGROUND_DEFAULT);
begin
  SetTextColour(AColour);
  Write(AText);
  if AColour <> FOREGROUND_DEFAULT then
    SetTextColour(FOREGROUND_DEFAULT);
end;

Procedure PrintLn(AText: String; AColour: smallint = FOREGROUND_DEFAULT);
begin
  Print(AText + #13#10, AColour);
end;

Procedure AddTestSet(ATestCaseName: string; AProcedure: TTestCaseProcedure;
  ASkipped: TSkipType; AExpectedException: string);
begin
  AddTestCase(ATestCaseName, AProcedure, ASkipped, AExpectedException);
end;

Procedure AddTestCase(ATestCaseName: string; AProcedure: TTestCaseProcedure;
  ASkipped: TSkipType; AExpectedException: string);
var
  l: integer;
begin
  if length(CurrentSetName) = 0 then
    CurrentSetName := NextSetName;

  l := length(MiniTestCases);
  SetLength(MiniTestCases, l + 1);
  MiniTestCases[l].SetName := CurrentSetName;
  MiniTestCases[l].Execute := AProcedure;
  MiniTestCases[l].TestCaseName := ATestCaseName;
  MiniTestCases[l].Skip := ASkipped;
  MiniTestCases[l].ExpectedException := AExpectedException;
end;

Procedure PrepareSet(AProcedure: TTestCaseProcedure);
begin
  AddTestCase('', AProcedure);
end;

Procedure FinaliseSet(AProcedure: TTestCaseProcedure);
begin
  AddTestCase('', AProcedure);
  CurrentSetName := '';
  CreatingSets := false;
end;

Procedure FinalizeSet(AProcedure: TTestCaseProcedure);
begin
  // Americaniz(s)ed form
  FinaliseSet(AProcedure);
end;

Procedure Title(AText: string);
var
  PreSpace, PostSpace, TitleSpace: integer;
  lText: string;
  Procedure OutputRow(AMesg: string; lColour : smallint);
  begin
    PreSpace := trunc((TitleSpace - length(AMesg)) / 2);
    PostSpace := TitleSpace - PreSpace - length(AMesg);
    Print(stringofchar('=', PreSpace));
    Print('  ' + AMesg + '  ', lColour);
    PrintLn(stringofchar('=', PostSpace));
  end;
begin
  TitleSpace := ConsoleScreenWidth - 4;
  lText := 'DUnitm V-'+FRAMEWORK_VERSION;
  SetTextColour(clDefault);
  OutputRow(lText, clDefault);
  OutputRow(AText, clTitle);
  DoubleLine;
end;

function CaseHasErrors: smallint;
begin
  Result := 0;
  if CaseFailedTests + CaseErrors > 0 then
    Result := 2
  else if CaseSkippedTests > 0 then
    Result := 1;
end;

function SetHasErrors: smallint;
begin
  Result := 0;
  if SetFailedTests + SetErrors > 0 then
    Result := 2
  else if SetSkippedTests > 0 then
    Result := 1;
end;

function RunHasErrors: smallint;
var
  lSetResult: smallint;
begin
  Result := 0;
  if (TotalFailedTests + TotalErroredTests > 0) then
    Result := 2
  else if TotalSkippedTests > 0 then
    Result := 1;
  if Result = 2 then
    exit;
  lSetResult := CaseHasErrors;
  if lSetResult > Result then
    Result := lSetResult;
end;

Function ResultColour(AHasErrors: smallint): smallint;
var
  lIntesity: byte;
begin
  case AHasErrors AND 3 of
    0:
      Result := clPass;
    1:
      Result := clSkipped;
  else
    Result := clError;
  end;
  lIntesity := AHasErrors and 255 and
    (BACKGROUND_INTENSITY or FOREGROUND_INTENSITY);
  Result := Result or lIntesity;
end;

Function CaseIsEmpty: boolean;
begin
  Result := (CasePassedTests = 0) and (CaseFailedTests = 0) and
    (CaseSkippedTests = 0) and (CaseErrors = 0);
end;

procedure CaseResults;
begin

  if CaseIsEmpty then
    exit;

  PrintLn(Format(CaseOutputFormat, [CasePassedTests, CaseFailedTests,
    CaseSkippedTests, CaseErrors]), ResultColour(CaseHasErrors));

end;

Function SetIsEmpty: boolean;
begin
  Result := (SetPassedTests = 0) and (SetFailedTests = 0) and
    (SetSkippedTests = 0) and (SetErrors = 0);
end;

procedure SetResults;
begin

  if (SetIsEmpty) or (length(CurrentSetName) = 0) then
    exit;

  PrintLn(Format(SetOutputFormat, [SetCases, SetPassedTests + SetFailedTests +
    SetSkippedTests + SetErrors, SetPassedTests, SetFailedTests,
    SetSkippedTests, SetErrors]), ResultColour(SetHasErrors));

  SingleLine;
end;

Procedure TestSummary;
begin
  NextTestCase('');
  DoubleLine;
  PrintLn(Format(TotalOutputFormat, [TotalSets, TotalCases, TotalTests,
    TotalPassedTests, TotalFailedTests, TotalSkippedTests, TotalErroredTests]),
    ResultColour(RunHasErrors or FOREGROUND_INTENSITY));
  WriteLn('');
end;

Procedure SetHeading(ASetName: string);
var
  lHeading: string;
begin
  if length(ASetName) = 0 then
    exit;
  lHeading := 'Test Set:' + ASetName;
  PrintLn(lHeading, clTitle);
end;

/// //////// END SCREEN MANAGEMENT \\\\\\\\\\\\\\\\\

/// //////// TEST CASES  \\\\\\\\\\\\\\\\\

Procedure SkipTestCases(ACaseId: integer);
begin
  NewTest(MiniTestCases[ACaseId].TestCaseName);
  CheckIsTrue(false, 'Case Skipped', Skip);
end;

Procedure RunTestSets;
var
  i, l: integer;
begin
  CreatingSets := false;
  l := length(MiniTestCases);
  if l > 0 then
  begin
    LastSetName := MiniTestCases[0].SetName;
    NextTestSet(LastSetName);
  end;
  SetCases := 0;
  for i := 0 to l - 1 do
    Try
      if not assigned(MiniTestCases[i].Execute) then
        continue;

      if MiniTestCases[i].Skip = skipCase then
      begin
        SkipTestCases(i);
        continue;
      end;

      CurrentSetName := MiniTestCases[i].SetName;
      if MiniTestCases[i].TestCaseName <> '' then
        NextTestCase(MiniTestCases[i].TestCaseName, MiniTestCases[i].Skip);
      ExpectException(MiniTestCases[i].ExpectedException, true);
      MiniTestCases[i].Execute;
      LastSetName := CurrentSetName;
    except
      on e: Exception do
        CheckException(e);
    end;
  // Last Case is done, Need to Update the Final Set Results.
  CurrentSetName := FINAL_SET_NAME;
  NextTestCase('');

  // Destroy the Cases.
  SetLength(MiniTestCases, 0);
  LastSetName := '';
  CurrentSetName := '';
end;

Procedure NextTestSet(ASetName: string);
begin

  SetResults;

  if ASetName = FINAL_SET_NAME then
    ASetName := ''; // Finalising.

  if length(ASetName) > 0 then
  begin
    SetHeading(ASetName);
    inc(TotalSets);
  end;

  SetPassedTests := 0;
  SetFailedTests := 0;
  SetSkippedTests := 0;
  SetErrors := 0;
  SetCases := 0;

end;

Procedure NextTestCase(ACaseName: string; ASkipped: TSkipType);
var
  lHeading: string;
begin
  CaseResults;

  inc(SetPassedTests, CasePassedTests);
  inc(SetFailedTests, CaseFailedTests);
  inc(SetSkippedTests, CaseSkippedTests);
  inc(SetErrors, CaseErrors);

  if LastSetName <> CurrentSetName then
    NextTestSet(CurrentSetName);

  if CanDisplayCaseName(ACaseName) then
  begin
    lHeading := ' Test Case:' + ACaseName;
    PrintLn(lHeading, clTitle);
    inc(SetCases);
    inc(TotalCases);
  end;

  inc(TotalPassedTests, CasePassedTests);
  inc(TotalFailedTests, CaseFailedTests);
  inc(TotalSkippedTests, CaseSkippedTests);
  inc(TotalErroredTests, CaseErrors);
  SkippingSet := ASkipped <> skipFalse;
  IgnoreSkip := false;
  ExpectedSetException := '';
  CasePassedTests := 0;
  CaseFailedTests := 0;
  CaseSkippedTests := 0;
  CaseErrors := 0;
  SameTestCounter := 0;
  LastTestCaseLabel := '';
  CurrentTestCaseLabel := '';
  CurrentTestCaseName := ACaseName;
  ExpectedException := '';
end;

Procedure ExpectException(AExceptionClassName: string;
  AExpectForSet: boolean = false);
begin
  ExpectedException := AExceptionClassName;
  if AExpectForSet then
    ExpectedSetException := ExpectedException;
end;

function ValueAsString(AValue: TComparitorType): string;
var
  lType: TvarType;
begin
  lType := varType(AValue);
  case lType of
    varEmpty:
      Result := 'Empty';
    varNull:
      Result := 'null';
    varSingle, varDouble, varCurrency:
      Result := FloatToStr(AValue);
    varDate:
      Result := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', AValue);
    varBoolean:
      If (AValue) Then
        Result := 'True'
      else
        Result := 'False';

    varSmallint, varInteger, varVariant, varByte
{$IFNDEF BEFOREVARIANTS}
      , varInt64, varShortInt, varWord, varLongWord
{$ENDIF}
{$IFDEF UNICODE}
      , varUInt64
{$ENDIF}
      :
      Result := IntToStr(AValue);

{$IFDEF UNICODE}
    varUString,
{$ENDIF}
    varOleStr, varStrArg, varString:
      Result := AValue;

  else
    Result := 'Unsupported Type';
  end;

end;

Function CompareValues(AExpected, AResult: TComparitorType): boolean;
var
  lExpectedType, lResultType: TvarType;
  lExpectedIsInteger, lExpectedIsNumber, lExpectedIsString, lResultIsInteger,
    lResultIsNumber, lResultIsString: boolean;
begin
  Result := false;
  lExpectedType := varType(AExpected);
  lResultType := varType(AResult);

  if (lExpectedType + lResultType = 1) OR (lExpectedType + lResultType = 1) then
  begin
    Result := true;
    exit;
  end;

  if (lExpectedType = lResultType) then
  begin
    Result := (AExpected = AResult);
    exit;
  end;

  lResultIsInteger := lResultType in [varByte, varSmallint, varInteger
{$IFNDEF BEFOREVARIANTS} , varShortInt, varWord, varLongWord, varInt64
  {$ENDIF}
    ];
  if (lExpectedType = varBoolean) and (lResultIsInteger) then
  begin
    Result := (AExpected = (AResult = 0));
    exit;
  end;

  lExpectedIsInteger := lExpectedType in [varByte, varSmallint, varInteger
{$IFNDEF BEFOREVARIANTS} , varShortInt, varWord, varLongWord, varInt64
  {$ENDIF}
    ];

  if (lExpectedIsInteger and lResultIsInteger) then
  begin
    Result :=
{$IFDEF BEFOREVARIANTS}
      varAsType(AExpected, varInteger) = varAsType(AResult, varInteger);
{$ELSE}
      varAsType(AExpected, varInt64) = varAsType(AResult, varInt64);
{$ENDIF}
    exit;
  end;

  if (lResultType = varBoolean) and (lExpectedIsInteger) then
  begin
    Result := (AExpected = 0) = AResult;
    exit;
  end;

  lExpectedIsNumber := (lExpectedIsInteger) or
    (lExpectedType in [varSingle, varDouble, varCurrency]);
  lResultIsNumber := (lResultIsInteger) or
    (lResultType in [varSingle, varDouble, varCurrency]);

  if (lExpectedIsNumber and lResultIsNumber) then
  begin
    Result := double(AExpected) = double(AResult);
    exit;
  end;

  lExpectedIsString := (lExpectedType = varString) or
    (lExpectedType in [varOleStr, varStrArg]);
  lResultIsString := (lResultType = varString) or
    (lResultType in [varOleStr, varStrArg]);
  if (lExpectedIsString and lResultIsString) then
  begin
    Result := AResult = AExpected;
    exit;
  end;
end;

Function Check(IsEqual: boolean; AExpected, AResult: TComparitorType;
  AMessage: string; ATestType: TCheckTestType): boolean;
var
  lMessage, lCounter: string;
  lResult: integer;
  Outcome: boolean;
  lMessageColour: smallint;
begin
  Result := false;
  lMessageColour := clDefault;
  lResult := 0;
  try
    case ATestType Of
      cttSkip:
        begin
          lResult := 1;
          if AMessage = '' then
            lMessage := ' Test Skipped'
          else
            lMessage := ' ' + AMessage;
          lMessageColour := clSkipped;
          inc(CaseSkippedTests);
          exit;
        end;
      cttException:
        begin
          lMessageColour := clMessage;
          if AMessage = '' then
            lMessage := ' Exception.'
          else
            lMessage := ' ' + AMessage;
          if IsEqual then
          begin
            lResult := 0;
            inc(CasePassedTests);
          end
          else
          begin
            lResult := 3;
            inc(CaseErrors);
            lMessageColour := clMessage;
            lMessage := Format('%s   Expected:<%s>%s   Actual  :<%s>',
              [#13#10, ValueAsString(AExpected), #13#10,
              ValueAsString(AResult)])
          end;
        end;
    else // case
      begin
        try
          lMessage := '';
          Outcome := CompareValues(AExpected, AResult);
          lMessageColour := clPass;
          if IsEqual <> Outcome then
          begin
            lResult := 2;
            lMessageColour := clError;
            inc(CaseFailedTests);
            if AMessage = '' then
            begin
              if IsEqual then
                lMessage := Format('%s   Expected:<%s>%s   Actual  :<%s>',
                  [#13#10, ValueAsString(AExpected), #13#10,
                  ValueAsString(AResult)])
              else
                lMessage :=
                  Format('%s   Expected outcomes to differ, but both returned %s%s',
                  [#13#10, ValueAsString(AExpected)]);
            end
            else
              lMessage := #13#10'   ' + AMessage;
            exit;
          end;
          inc(CasePassedTests);
        except
          on e: Exception do
          begin
            if (e.ClassName = ExpectedException) then
            begin
              // At this level, it will only be exceptions
              // for Variant type comparisons
              lResult := 0;
              inc(CasePassedTests);
            end
            else
            begin
              lResult := 2;
              lMessageColour := clMessage;
              lMessage := #13#10'   Illegal Comparison Test Framework: ' +
                e.Message;
              inc(CaseErrors);
            end;
          end;
        end;
      end; // case else
    end; // case
  finally
    if LastTestCaseLabel = CurrentTestCaseLabel then
      inc(SameTestCounter)
    else
      SameTestCounter := 1;
    LastTestCaseLabel := CurrentTestCaseLabel;
    if SameTestCounter = 1 then
      lCounter := ''
    else
      lCounter := '-' + IntToStr(SameTestCounter);
    if CurrentTestCaseLabel = '' then
    begin
      CurrentTestCaseLabel := copy('Test for ' + CurrentTestCaseName, 1,
        ConsoleScreenWidth - 4);
      if lCounter = '' then
      begin
        lCounter := '-1';
        LastTestCaseLabel := CurrentTestCaseLabel;
      end;
      ExpectedException := ExpectedSetException;
      IgnoreSkip := false;
    end;

    Print(Format('  %s-', [PASS_FAIL[lResult]]), lMessageColour);
    Print(Format('%s%s', [CurrentTestCaseLabel, lCounter]));
    PrintLn(lMessage, lMessageColour);
    Result := (lResult = 0);
  end;
end;

function TestTypeFromSkip(ASkipped: TSkipType): TCheckTestType;
begin
  if (Not IgnoreSkip) and ((ASkipped = skipTrue) or SkippingSet) then
    Result := cttSkip
  else
    Result := cttComparison;
end;

Function DontSkip: TSkipType;
begin
  IgnoreSkip := true;
  Result := skipFalse;
end;

Function CheckIsEqual(AExpected, AResult: TComparitorType;
  AMessage: string = ''; ASkipped: TSkipType = skipFalse): boolean;
begin
  Result := false;
  try
    Result := Check(true, AExpected, AResult, AMessage,
      TestTypeFromSkip(ASkipped));
  except
    on e: Exception do
      CheckException(e);
  end;
end;

Function CheckNotEqual(AResult1, AResult2: TComparitorType; AMessage: string;
  ASkipped: TSkipType): boolean;
Begin
  Result := false;
  try
    Result := Check(false, AResult1, AResult2, AMessage,
      TestTypeFromSkip(ASkipped));
  except
    on e: Exception do
      CheckException(e);
  end;
end;

Function CheckIsTrue(AResult: boolean; AMessage: string;
  ASkipped: TSkipType): boolean;
begin
  Result := CheckIsEqual(true, AResult, AMessage, ASkipped);
end;

Function CheckIsFalse(AResult: boolean; AMessage: string;
  ASkipped: TSkipType): boolean;
begin
  Result := CheckIsEqual(false, AResult, AMessage, ASkipped);
end;

Procedure CheckException(AException: Exception);
var
  lExpected: string;
  lExceptionClassName: string;
  lExceptionMessage: string;
begin
  lExpected := ExpectedException;
  if (AException = nil) then
  begin
    lExceptionClassName := NIL_EXCEPTION_CLASSNAME;
    lExceptionMessage := NO_EXCEPTION_EXPECTED;
  end
  else
  begin
    lExceptionClassName := AException.ClassName;
    lExceptionMessage := AException.Message;
  end;

  if lExpected = '' then
    lExpected := NO_EXCEPTION_EXPECTED;
  Check((lExceptionClassName = lExpected) or (pos(lExpected, lExceptionMessage)
    > 0), lExpected, lExceptionClassName + ':' + lExceptionMessage, '',
    cttException);
end;

Function NotImplemented(AMessage: string = ''): boolean;
var
  lMessage: string;
begin
  if AMessage = '' then
    lMessage := 'Not Implemented'
  else
    lMessage := AMessage;
  Result := CheckIsTrue(true, lMessage, skipTrue);
end;

Procedure NewSet(ASetName: string);
begin
  CurrentSetName := ASetName;
  CreatingSets := true;
end;

Procedure NewCase(ATestCaseName: string);
begin
  NewTest('', ATestCaseName);
end;

procedure NewTestCase(ACase: string; ATestCaseName: string);
begin
  NewTest(ACase, ATestCaseName);
end;

procedure NewTest(ACase: string; ATestCaseName: string);
begin

  if (ATestCaseName <> '') and
    ((ACase = '') OR (CurrentTestCaseName <> ATestCaseName)) then
    NextTestCase(ATestCaseName);

  if (ACase <> '') then
    CurrentTestCaseLabel := ACase;
  ExpectedException := ExpectedSetException;
  IgnoreSkip := false;
end;

initialization

{$IFDEF CompilerVersion}
{$IF CompilerVersion >= 20.0}
  system.ReportMemoryLeaksOnShutdown := true;
{$IFEND}
{$ENDIF}
TotalOutputFormat := DEFAULT_TOTALS_FORMAT;
SetOutputFormat := DEFAULT_SET_FORMAT;
CaseOutputFormat := DEFAULT_CASE_FORMAT;

end.
