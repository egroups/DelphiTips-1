program TestRecordUtils;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  MiniTestFramework in '..\MiniTestFramework.pas',
  TestCasesRecordUtils in 'TestCasesRecordUtils.pas',
  RecordUtils in '..\RecordUtils.pas';

begin
  try
    PrepareSet(Setup);
    AddTestSet('Clear Record', Record_Clears_as_expected);
    AddTestSet('Clone Record', Clone_copies_values_as_expected,skip);
    AddTestSet('Parse ValuePairs', Parse_Populates_record_as_expected,skip);
    AddTestSet('As ValuePairs', AsValuePairs_Exports_values_as_Expected,skip);
    AddTestSet('Implicit Cast To Record',Implicit_Cast_To_Static_works_as_Expected,skip);
    AddTestSet('Implicit Cast To Serializable',Implicit_Cast_To_Static_works_as_Expected,skip);
    AddTestSet('Implicit Cast to String',Implicit_Cast_To_String_works_as_Expected,skip);
    AddTestSet('Implicit Cast FROM String',Implicit_Cast_From_String_works_as_Expected,skip);
    AddTestSet('As JSON Text',AsJSON_works_as_Expected,skip);
    AddTestSet('From JSON Text',FromJSON_works_as_Expected,skip);


    FinaliseSet(TearDown);

    Title('Test Cases For RecordUtils');
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
