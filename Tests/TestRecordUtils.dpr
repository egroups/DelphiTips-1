program TestRecordUtils;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  MiniTestFramework in '..\MiniTestFramework.pas',
  TestCasesRecordUtils in 'TestCasesRecordUtils.pas',
  RecordUtils in '..\RecordUtils.pas';

begin
  try

    Title('Test Cases For Tools used for RecordUtils');
    PrepareSet(nil);
    AddTestSet('JSON to Value Pairs', JSONTOValuePairs_Works_as_Expected);
    FinaliseSet(nil);
    RunTestSets;
    TestSummary;

//
//
    Title('Test Cases For RecordUtils');
    PrepareSet(Setup);
    AddTestSet('Clear Record', Record_Clears_as_expected);
    AddTestSet('Clone Record', Clone_copies_values_as_expected);
    AddTestSet('Parse ValuePairs', Parse_Populates_record_as_expected);
    AddTestSet('As ValuePairs', AsValuePairs_Exports_values_as_Expected);
    AddTestSet('Implicit Cast To Record',Implicit_Cast_To_Static_works_as_Expected);
    AddTestSet('Implicit Cast To Serializable',Implicit_Cast_To_Static_works_as_Expected);
    AddTestSet('Implicit Cast to String',Implicit_Cast_To_String_works_as_Expected);
    AddTestSet('Implicit Cast FROM String',Implicit_Cast_From_String_works_as_Expected);
    AddTestSet('As JSON Text',AsJSON_works_as_Expected);
    AddTestSet('From JSON Text',FromJSON_works_as_Expected);
    AddTestSet('Parse Array Update',Parse_Array_Update_Works_as_Expected);
    AddTestSet('Parse Array Append',Parse_Array_Works_as_Expected);
    AddTestSet('As ValuePairs for Arrays',AsValuePairs_Exports_Arrays_as_Expected);
    AddTestSet('As JSON for Arrays',AsJSON_Exports_Arrays_as_Expected);

    AddTestSet('Parse Array Update with Out of Bounds',Parse_Array_Update_Exceptions_Detected_as_expected,
                  false,'Index out of bounds');
    AddTestSet('Parse Array Update with Exceptions',Parse_Array_Exceptions_Detected_as_expected,
                false,'Cannot update records, no index specified');
    FinaliseSet(TearDown);

    RunTestSets;
    TestSummary;

    if sameText(Paramstr(1),'/p') then ReadLn;
    ExitCode := TotalErroredTestCases+TotalFailedTestCases;
  except
    on E: Exception do
	  Begin
      Writeln(
          'Test Framework Exception: ',
          'Test case:' ,CurrentTestClass,';',CurrentTestCase,
          E.Message);
		  ExitCode := 1;
	  end;
  end;
end.
