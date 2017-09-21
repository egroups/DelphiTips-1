unit TestCasesRecordUtils;

interface
  uses SysUtils,MiniTestFramework
   (* TODO -oUser -cTestCase1 Unit :
   (**)
      ,RecordUtils
   (**)
  ;
Procedure Setup;
Procedure Record_Clears_as_expected;
Procedure Clone_copies_values_as_expected;
Procedure Parse_Populates_record_as_expected;
Procedure AsValuePairs_Exports_values_as_Expected;
Procedure Implicit_Cast_To_Static_works_as_Expected;
Procedure Implicit_Cast_From_Static_works_as_Expected;
Procedure Implicit_Cast_To_String_works_as_Expected;
Procedure Implicit_Cast_From_String_works_as_Expected;
Procedure AsJSON_works_as_Expected;
Procedure FromJSON_works_as_Expected;
Procedure Parse_Array_Works_as_Expected;
Procedure AsValuePairs_Exports_Arrays_as_Expected;

Procedure TearDown;

Type
  TTestRecord = Record
    number : integer;
    text   : string;
    bool   : boolean;
    flNum  : single;
  End;

  TSerialisableRecord = TRecordSerializer<TTestRecord>;

  TSerialisableRecords = Array of TSerialisableRecord;


implementation

Procedure Setup;
begin
  {Prepare anything you want here.
   NOTE:
    you can prepare as many setups to the set as you like
    or simply add them inside the set Procedure
  }
end;


Procedure Record_Clears_as_expected;
var lResult : TSerialisableRecord;
begin
  NewTestCase('Static Type Clears as Expected');
  lResult.Clear;
  checkisTrue(lResult.Values.number=0);
  checkisTrue(lResult.Values.text='');
  checkisFalse(lResult.Values.bool);
  checkisTrue(lResult.Values.flNum=0);
end;

Procedure Clone_copies_values_as_expected;
var lResult,lClone : TSerialisableRecord;
begin
   lResult.Values.number := 5;
   lResult.Values.text := 'TestValue TEXT';
   lResult.Values.bool := false;
   lResult.Values.flNum := 5.663;
   lClone.clone(lResult.Values);
   checkisEqual(lResult.Values.number,lClone.Values.number);
   checkisEqual(lResult.Values.text,lClone.Values.text);
   checkisEqual(lResult.Values.bool,lClone.Values.bool);
   checkisEqual(lResult.Values.flNum,lClone.Values.flNum);
end;

Procedure Parse_Populates_record_as_expected;
var lExpected: String;
    lResult : TSerialisableRecord;
begin
  lExpected := 'number=5'#13#10+
               'text=TestValue TEXT'#13#10+
               'bool=False'#13#10+
               'flNum=5.663';
  lResult.Parse(lExpected);
  checkisFalse(lResult.Values.bool);
  checkisEqual(5,lResult.Values.number);
  checkisEqual('TestValue TEXT',lResult.Values.text);
  checkisEqual(5.663,trunc(lresult.Values.flNum*1000)/1000); // double conversion...
end;

Procedure Implicit_Cast_To_String_works_as_Expected;
var lResult : TSerialisableRecord;
    lExpected : string;
begin
  lExpected := 'number=5'#13#10+
             'text=TestValue TEXT'#13#10+
             'bool=False'#13#10+
             'flNum=0'#13#10;
   lResult.Values.number := 5;
   lResult.Values.text := 'TestValue TEXT';
   lResult.Values.bool := false;
   lResult.Values.flNum := 0;
   checkisEqual(lExpected,lResult);

end;

Procedure Implicit_Cast_From_String_works_as_Expected;
var lExpected: String;
    lResult : TSerialisableRecord;
begin
  lExpected := 'number=5'#13#10+
               'text=TestValue TEXT'#13#10+
               'bool=False'#13#10+
               'flNum=5.663';
  lResult := lExpected;
  lResult.Parse(lExpected);
  checkisFalse(lResult.Values.bool);
  checkisEqual(5,lResult.Values.number);
  checkisEqual('TestValue TEXT',lResult.Values.text);
  checkisEqual(5.663,trunc(lresult.Values.flNum*1000)/1000); // double conversion...

end;

Procedure AsValuePairs_Exports_values_as_Expected;
var lResult : TSerialisableRecord;
    lExpected : string;
begin
  lExpected := 'number=5'#13#10+
             'text=TestValue TEXT'#13#10+
             'bool=False'#13#10+
             'flNum=0'#13#10;
   lResult.Values.number := 5;
   lResult.Values.text := 'TestValue TEXT';
   lResult.Values.bool := false;
   lResult.Values.flNum := 0;
   checkisEqual(lExpected,lResult.AsValuePairs);
end;

Procedure Implicit_Cast_To_Static_works_as_Expected;
var lResult : TTestRecord;
var lSerialisable : TSerialisableRecord;
begin
   lSerialisable.Values.number := 5;
   lSerialisable.Values.text := 'TestValue TEXT';
   lSerialisable.Values.bool := false;
   lSerialisable.Values.flNum := 5.663;
   lResult := lSerialisable;
   checkisEqual(lSerialisable.Values.number,lResult.number);
   checkisEqual(lSerialisable.Values.text,lResult.text);
   checkisEqual(lResult.bool,lSerialisable.Values.bool);
   checkisEqual(lSerialisable.Values.flNum,lResult.flNum);
end;

Procedure Implicit_Cast_From_Static_works_as_Expected;
var lStatic : TTestRecord;
var lResult : TSerialisableRecord;
begin
   lStatic.number := 5;
   lStatic.text := 'TestValue TEXT';
   lStatic.bool := false;
   lStatic.flNum := 5.663;
   lResult := lStatic;
   checkisEqual(lResult.Values.number,lStatic.number);
   checkisEqual(lResult.Values.text,lStatic.text);
   checkisEqual(lResult.Values.bool,lStatic.bool);
   checkisEqual(lResult.Values.flNum,lStatic.flNum);
end;

Procedure AsJSON_works_as_Expected;
var lExpected: String;
    lRecord : TSerialisableRecord;
    lDblValue: Double;
begin
  lDblValue := 5.0;
  lExpected := '{"number":5,'+
                '"text":"TestValue TEXT is \"\"",'+
                '"bool":False,'+
                '"flNum":'+lDblValue.ToString+'}';
  lRecord.Values.number := 5;
  lRecord.Values.text := 'TestValue TEXT is ""';
  lRecord.Values.bool := false;
  lRecord.Values.flNum := lDblValue;
  checkIsEqual(lExpected,lRecord.AsJSON);

end;

Procedure FromJSON_works_as_Expected;
var lExpected: String;
    lResult : TSerialisableRecord;
    lDblValue: Double;
begin
  lDblValue := 5.0;
  lExpected := '{"number":5,'+
                '"text":"TestValue TEXT is \"\"",'+
                '"bool":False,'+
                '"flNum":'+lDblValue.ToString+'}';
  lResult.FromJSON(lExpected);
  checkisFalse(lResult.Values.bool);
  checkisEqual(lResult.Values.number,5);
  checkisEqual(lResult.Values.text,'TestValue TEXT is ""');
  checkisEqual(trunc(lresult.Values.flNum*1000)/1000,5); // double conversion...
end;

Procedure Parse_Array_Works_as_Expected;
var lExpected: String;
    lResult : TSerialisableRecord;
begin
  NewTestCase('Single Array Parses into Values');
  lExpected := 'number[0]=5'#13#10+
               'text[0]=TestValue TEXT'#13#10+
               'bool[0]=False'#13#10+
               'flNum[0]=5.663';
  checkisEqual(1,lResult.Parse(lExpected));
  checkisFalse(lResult.Values.bool);
  checkisEqual(5,lResult.Values.number);
  checkisEqual('TestValue TEXT',lResult.Values.text);
  checkisEqual(5.663,trunc(lresult.Values.flNum*1000)/1000); // double conversion...

  NewTestCase('Second Parse Appends to existing Array');
  lExpected := 'number[0]=6'#13#10+
               'text[0]=TestValue TEXT 2'#13#10+
               'bool[0]=True'#13#10+
               'flNum[0]=300.01';
  checkisEqual(1,lResult.Parse(lExpected,spmAppend),'Expected 1 Record to be added');
  checkisEqual(2,lResult.Count,'Expected Count to be 2');
  checkisFalse(lResult.AllValues[0].bool);
  checkisEqual(5,lResult.AllValues[0].number);
  checkisEqual('TestValue TEXT',lResult.AllValues[0].text);
  checkisEqual(5.663,trunc(lResult.AllValues[0].flNum*1000)/1000); // double conversion...
  checkisTrue(lResult.AllValues[1].bool);
  checkisEqual(6,lResult.AllValues[1].number);
  checkisEqual('TestValue TEXT 2',lResult.AllValues[1].text);
  checkisEqual(300.01,trunc(lResult.AllValues[1].flNum*1000)/1000); // double conversion...

  NewTestCase('Clear Array Works as Expected');
  lResult.Clear;
  Checkistrue(lResult.Values.number=0);
  Checkisequal(lresult.Count,0);


  NewTestCase('2 Arrays, starting at 0 Parse Correctly');
  lExpected := 'number[0]=5'#13#10+
               'text[0]=TestValue TEXT'#13#10+
               'bool[0]=False'#13#10+
               'flNum[0]=5.663'#13#10+
               'number[1]=6'#13#10+
               'text[1]=TestValue TEXT 2'#13#10+
               'bool[1]=True'#13#10+
               'flNum[1]=300.01';
  checkisEqual(2,lResult.Parse(lExpected,spmAppend),'Expected 2 Records to be added');
  checkisEqual(2,lResult.Count,'Expected Count to be 2');

  NewTestCase('Array Element 0 has Correct Values');
  checkisFalse(lResult.AllValues[0].bool);
  checkisEqual(5,lResult.AllValues[0].number);
  checkisEqual('TestValue TEXT',lResult.AllValues[0].text);
  checkisEqual(5.663,trunc(lResult.AllValues[0].flNum*1000)/1000); // double conversion...

  NewTestCase('Array Element 1 has Correct Values');
  checkisTrue(lResult.AllValues[1].bool);
  checkisEqual(6,lResult.AllValues[1].number);
  checkisEqual('TestValue TEXT 2',lResult.AllValues[1].text);
  checkisEqual(300.01,trunc(lResult.AllValues[1].flNum*1000)/1000); // double conversion...

  lResult.Clear;

  NewTestCase('2 Arrays, starting at 0 Parse Correctly');
  lExpected := 'number[0]=5'#13#10+
               'text[0]=TestValue TEXT'#13#10+
               'bool[0]=False'#13#10+
               'flNum[0]=5.663'#13#10+
               'number[1]=6'#13#10+
               'text[1]=TestValue TEXT 2'#13#10+
               'bool[1]=True'#13#10+
               'flNum[1]=300.01';
  checkisEqual(2,lResult.Parse(lExpected),'Expected 2 Records to be added');
  checkisEqual(2,lResult.Count,'Expected Count to be 2');

  NewTestCase('Array Element 0 has Correct Values');
  checkisFalse(lResult.AllValues[0].bool);
  checkisEqual(5,lResult.AllValues[0].number);
  checkisEqual('TestValue TEXT',lResult.AllValues[0].text);
  checkisEqual(5.663,trunc(lResult.AllValues[0].flNum*1000)/1000); // double conversion...

  NewTestCase('Array Element 1 has Correct Values');
  checkisTrue(lResult.AllValues[1].bool);
  checkisEqual(6,lResult.AllValues[1].number);
  checkisEqual('TestValue TEXT 2',lResult.AllValues[1].text);
  checkisEqual(300.01,trunc(lResult.AllValues[1].flNum*1000)/1000); // double conversion...

  lResult.Clear;

  NewTestCase('2 Arrays, starting at 0, skipping 1 and 2 Parse Correctly');
  lExpected := 'number[0]=5'#13#10+
               'text[0]=TestValue TEXT'#13#10+
               'bool[0]=False'#13#10+
               'flNum[0]=5.663'#13#10+
               'number[3]=6'#13#10+
               'text[3]=TestValue TEXT 3'#13#10+
               'bool[3]=True'#13#10+
               'flNum[3]=300.01';
  checkisEqual(2,lResult.Parse(lExpected),'Expected 2 Records to be added');
  checkisEqual(4,lResult.Count,'Expected Count to be 2');

  NewTestCase('Array Element 0 has Correct Values');
  checkisFalse(lResult.AllValues[0].bool);
  checkisEqual(5,lResult.AllValues[0].number);
  checkisEqual('TestValue TEXT',lResult.AllValues[0].text);
  checkisEqual(5.663,trunc(lResult.AllValues[0].flNum*1000)/1000); // double conversion...

  NewTestCase('Array Element 3 has Correct Values');
  checkisTrue(lResult.AllValues[3].bool);
  checkisEqual(6,lResult.AllValues[3].number);
  checkisEqual('TestValue TEXT 3',lResult.AllValues[3].text);
  checkisEqual(300.01,trunc(lResult.AllValues[3].flNum*1000)/1000); // double conversion...
end;

Procedure AsValuePairs_Exports_Arrays_as_Expected;
var lResult : TSerialisableRecord;
    lExpected, lExpected2 : string;
begin
  NewTestCase('Single Array Exports as array Values');
  lExpected :=
       'number[0]=5'#13#10+
       'text[0]=TestValue TEXT'#13#10+
       'bool[0]=False'#13#10+
       'flNum[0]=103'#13#10;
  lExpected2 :=
       'number=333'#13#10+
       'text=TestValue TEXT 2'#13#10+
       'bool=False'#13#10+
       'flNum=105'#13#10;
  checkisEqual(1,lResult.Parse(lExpected));
  checkisEqual(lExpected,lResult.AsValuePairs);

  NewTestCase('2 Array Exports as array Values');
  checkisEqual(1,lResult.Parse(lExpected2));
  checkisEqual(lExpected+lExpected2.Replace('=','[1]=',[rfReplaceAll])
                ,lResult.AsValuePairs);

  NewTestCase('2 Array Export Second Element as array Values');
  checkisEqual(lExpected2.Replace('=','[1]=',[rfReplaceAll])
                ,lResult.AsValuePairs(1));


end;


Procedure TearDown;
begin
  {Release anything you need to here}
end;

end.
