unit RecordUtils;

////////////////////////////////////////////////
// Copyright Glen Kleidon 2017                //
// Part of the Delphi Tips Repo               //
// https://github.com/glenkleidon/DelphiTips  //
////////////////////////////////////////////////

interface
   uses System.sysUtils, System.Classes, System.Rtti, System.Generics.collections;
   type PStrings = ^TStrings;
   Type TSerializerParseMode = (spmAppend, spmUpdate);
   Type TArrayBounds = record
          Low : integer;
          High : integer;
   end;

   Type TRecordSerializer<T> = Record
     private
       fisArray : string;
       fIndex: integer;
       function getCount: integer;
       function getIsArray: boolean;
       procedure setIsArray(const Value: boolean);
     public
       Values : T;
       AllValues: Array of T;
       Procedure Clear;
       Procedure Clone(ARecord: T); overload;
       Procedure Clone(ARecord: TRecordSerializer<T>); overload;
       Function Parse(AStrings:TStrings; AMode: TSerializerParseMode=spmUpdate;
                             AIndex: integer=-1): integer; overload;
       Function Parse(AText: String; AMode: TSerializerParseMode = spmUpdate;
                             AIndex: integer=-1): integer; overload;
       Function AsValuePairs(AIndex:integer =-1): string; overload;
       Procedure AsValuePairs(AStrings:TStrings; AIndex:integer =-1); overload;
       Function AsJSON : String; overload;
       Procedure FromJSON(AJSON: string);
       class operator Implicit(ASerializable: TRecordSerializer<T>): T;
       class operator Implicit(ARecord: T): TRecordSerializer<T>;
       class operator Implicit(AText: string): TRecordSerializer<T>;
       class operator Implicit(ARecord: TRecordSerializer<T>): String;
       Property Count : integer read getCount;
       Property isArray: boolean read getIsArray write setIsArray;
   end;

   function IndexedName(AId: string; AIndex: integer=-1): string;
   function ParseStringAsIndex(AId: string; AStrings: TStrings; AIndex: integer=-1): string;
   function AsValuePair(AId: string; AValue: string; AIndex: integer=-1; ALineEnding: string=''):string;
   function AsValuePairRow(AId: string; AValue: string; AIndex: integer=-1): string;
   Function RecordAsValuePairs(ATypeInfo: Pointer; APValue: Pointer; AIndex: integer = -1): string;
   Function ParseValuesToRecord(AStrings: TStrings; ATypeInfo: Pointer; APValue: Pointer; AIndex: integer = -1): integer;
   Function GetValuePairHeader(ATypeInfo: Pointer; APValue: Pointer): string;
   Procedure CloneRecord(ATypeInfo: Pointer; APRecordToClone: Pointer; APClonedRecord : Pointer );
   Procedure ClearRecord(ATypeInfo: Pointer; APValue: Pointer);
   Function AsJSONPair(AId: string; AValue: string;AValueQuoted:boolean=true):string;
   Function RecordAsJSON(ATypeInfo: Pointer; APValue: Pointer; AIndex: integer = -1): string;
   Procedure ParseJSONtoRecord(AString: String; ATypeInfo: Pointer; APValue: Pointer);
   Function JSONToValuePairs(AJSON:string):String;
   Function GetIndexBounds(AStrings: TStrings): TArrayBounds;


implementation

  uses System.TypInfo,System.StrUtils;

Function GetIndexBounds(AStrings: TStrings): TArrayBounds;
var p,q,r: integer;
    v,c : integer;
    lText, lRow: string;
begin
  Result.Low := MaxInt;
  Result.High := -1;
  p := pos('[',AStrings.Text);
  try
    if p<1 then exit;
    for lRow in AStrings do
    begin
      lText := copy(lRow,1,pos('=',lRow)-1);
      p := pos('[',lText);
      q := posex(']',lText,p);
      if (p>0) and (q>0) then
      begin
        // 123456789
        // id[0]   5-3-1 = 1
        val(copy(ltext,p+1,q-p-1),v,c);
        if c>0 then continue;
        if v<result.Low then Result.Low:=v;
        if v>Result.High then Result.High:=v;
      end else exit;
    end;
  finally
    if Result.Low=MaxInt then Result.Low := Result.High;
  end;
end;

Function JSONToValuePairs(AJSON:string):String;
begin
   // simple implementation assumes single object, no spacing
   Result := AJSON
       .Replace('{','')
       .Replace('\"',#1,[rfReplaceAll])
       .Replace('\\',#2,[rfReplaceAll])
       .Replace('"','',[rfReplaceAll])
       .Replace(':','=',[rfReplaceAll])
       .Replace(',',#13#10,[rfReplaceAll])
       .Replace(#1,'"',[rfReplaceAll])
       .Replace(#2,'\',[rfReplaceAll])
    ;
    Result := copy(Result,1,Result.length-1);
end;

function IndexedName(AId: string; AIndex: integer=-1): string;
begin
 if (Aindex<0) then Result := AId else Result := format('%s[%u]',[AId, AIndex]);
end;

Function ParseValuesToRecord(AStrings: TStrings; ATypeInfo: Pointer; APValue: Pointer; AIndex: integer = -1): integer;
var
  ltype: TRTTIType;
  lfield: TRttiField;
  lfields: TArray<TRttiField>;
  lContext: TRTTIContext;
  lText : TStringlist;
  lPrefix : string;
  lSuffix : String;
  lTValue,lTDefaultValue : TValue;
  lValue : string;
  lInt: Int64;
  lSingle: Single;
  lDouble: Double;
  Buffer : Pointer;
  p:integer;
begin
  Result := 0;
  lContext := TRTTIContext.Create;
  ltype := lContext.GetType(ATypeInfo);
  lFields := lType.getFields;
  lPrefix := IndexedName(ltype.Name,AIndex);
  lSuffix := format('[%u]',[AIndex]);
  for lfield in lFields do
  begin
    if lField.FieldType.IsRecord then
    begin
      // Add records here.
    end else
    begin
       lValue := AStrings.values[lField.Name];
       if LValue.length=0 then lValue := AStrings.values[lField.Name+lSuffix];
       if LValue.length=0 then lValue := AStrings.values[lPrefix+lField.Name];
       if lValue.length=0 then continue;
       case lField.FieldType.TypeKind of
         tkEnumeration:
         begin
           lTValue.Make(getEnumValue(lField.FieldType.Handle,lValue),lField.FieldType.Handle,lTvalue);
           lField.setValue(APValue, lTValue);
           inc(result);
         end;
         tkInteger,
         tkInt64:
         begin
            if tryStrToInt64(lValue,lInt) then
                lField.SetValue(APValue,lInt)
            else raise Exception.Create('Invalid Integer Type Cast');
            inc(result);
         end;
         tkFloat:
         begin
            p := pos('.',lValue);
            if (p=0) or (lValue.Length-p<7) then
            begin
              if tryStrToFloat(lValue,lSingle) then
                  lField.SetValue(APValue,lSingle)
              else raise Exception.Create('Invalid Float Single Type Cast');
            end else
            begin
              if tryStrToFloat(lValue,lDouble) then
                  lField.SetValue(APValue,lDouble)
              else raise Exception.Create('Invalid Float Double Type Cast');
            end;
            inc(result);
         end;
       else
       begin
          lField.setValue(APValue, TValue(lValue));
          Inc(Result);
       end;
       end;
    end;
  end;
end;

Function RecordAsValuePairs(ATypeInfo: Pointer; APValue: Pointer; AIndex: integer = -1): string;
var
  ltype: TRTTIType;
  lfield: TRttiField;
  lfields: TArray<TRttiField>;
  lText : TStringlist;
  lPrefix : string;
  lValue : string;
  lTValue : TValue;
  p:integer;
begin
  ltype := TRTTIContext.Create.GetType(ATypeInfo);
  lFields := lType.getFields;
  lText:= TStringlist.create;
  try
    lPrefix := IndexedName(ltype.Name,AIndex);
    for lfield in lFields do
    begin
      if lField.FieldType.IsRecord then
      begin
        // Add records here.
      end else
      begin
        lValue := AsValuePair(lField.Name,lField.getValue(APValue).ToString, AIndex,#13#10);
        if lValue.Length>0 then lText.Add(lValue);
      end;
    end;
    result := lText.text;
  finally
    freeAndNil(lText);
  end;
end;

Function RecordAsJSON(ATypeInfo: Pointer; APValue: Pointer; AIndex: integer = -1): string;
var
  ltype: TRTTIType;
  lfield: TRttiField;
  lfields: TArray<TRttiField>;
  lComma : string;
  lValue : string;
  lTValue : TValue;
  lNoQuotes: Boolean;
  lBoolHandle: PTypeInfo;
begin
  Result := '{';
  ltype := TRTTIContext.Create.GetType(ATypeInfo);
  lFields := lType.getFields;
  lComma := '';
  lBoolHandle := typeInfo(Boolean);
  for lfield in lFields do
  begin
    if lField.FieldType.IsRecord then
    begin
      // Add records here.
      continue;
    end;
    lValue := lField.getValue(APValue).ToString;
    if lValue.Length=0 then continue;
    lNoQuotes :=
       ((lField.FieldType.TypeKind in [tkInteger,tkFloat,tkInt64])
         or (lField.FieldType.Handle=lBoolHandle));
    lValue := lComma+AsJsonPair(lField.Name,lValue,not lNoQuotes);
    Result := Result+(lValue);
    lComma := ',';
  end;
  Result := Result + '}';
end;

Procedure ParseJSONtoRecord(AString: String; ATypeInfo: Pointer; APValue: Pointer);
begin
  raise Exception.Create('Not Implemented');
end;


function ParseStringAsIndex(AId: string; AStrings: TStrings; AIndex: integer=-1): string;
var lSuffix : string;
begin
  if AIndex=-1 then lSuffix := '' else lSuffix := format('[%u]',[AIndex]);
  result := AStrings.Values[Aid+lSuffix];
end;

function AsValuePairRow(AId: string; AValue: string; AIndex: integer=-1): string;
begin
  result :=  AsValuePair(AId, AValue, AIndex,#13#10);
end;

function AsValuePair(AId: string; AValue: string; AIndex: integer=-1; ALineEnding: string=''):string;
var lSuffix : string;
begin
  result := '';
  if AValue.Length>0 then
  begin
    if AIndex=-1 then lSuffix := '' else lSuffix := format('[%u]',[AIndex]);
    result := format('%s%s=%s',[AId,lSuffix,
            AValue.replace(#13#10,#10,[rfReplaceAll]).
            replace(#13,#10,[rfReplaceAll])
            ]);
  end;
end;

function AsJSONPair(AId: string; AValue: string;AValueQuoted:boolean=true):string;
var lformat : string;
    function JSONEscape(Atext: string): string;
    begin
      result := atext.Replace('\','\\',[rfReplaceAll])
             .Replace('"','\"',[rfReplaceAll]);
    end;
begin
  result := '';
  if AValueQuoted then lformat := '"%s":"%s"' else lformat:='"%s":%s';
  Result := format(lformat,[JSONEscape(AId),JSONEscape(AValue)]);
end;


Procedure ClearRecord(ATypeInfo: Pointer; APValue: Pointer);
var
  ltype: TRTTIType;
  lfield: TRttiField;
  lfields: TArray<TRttiField>;
  lPrefix : string;
  lValue : TValue;
begin
  ltype := TRTTIContext.Create.GetType(ATypeInfo);
  lFields := lType.getFields;
  for lfield in lFields do
  begin
    if lField.FieldType.IsRecord then
    begin
      // Add client records here.
    end else
    begin
      case lField.FieldType.TypeKind of
        tkInteger, tkFloat, tkInt64: lField.SetValue(APValue,0);
        tkChar,tkWChar : lField.SetValue(APValue,#0);
        tkEnumeration:
        begin
           lValue.Make(0,lField.FieldType.Handle,lValue);
           lField.setValue(APValue, lValue);
        end;
        tkString,tkLString,tkUString : lField.SetValue(APValue,'');
      end; // case;
    end;
  end;
end;

procedure CloneRecord(ATypeInfo: Pointer; APRecordToClone: Pointer; APClonedRecord : Pointer );
var
  ltype: TRTTIType;
  lfield: TRttiField;
  lfields: TArray<TRttiField>;
  lPrefix : string;
  lValue : TValue;
begin
  ltype := TRTTIContext.Create.GetType(ATypeInfo);
  lFields := lType.getFields;
  for lfield in lFields do
  begin
    if lField.FieldType.IsRecord then
    begin
      // Add client records here.
    end else
    begin
      lValue := lField.getValue(APRecordToClone);
      lField.SetValue(APClonedRecord,lValue);
    end;
  end;
end;

Function GetValuePairHeader(ATypeInfo: Pointer; APValue: Pointer): string;
var
  ltype: TRTTIType;
  lPrefix : string;
  lValue : TValue;
  lDynArray : TRttiDynamicArrayType;
  lArray : TRttiArrayType;
  l : integer;
  lName: string;
  function NameAndLength(AName: string; ACount: integer): string;
  begin
    if Acount>=0 then
      Result := format('%s[]%sRecordCount=%u', [AName,#13#10,ACount])
    else Result := AName+'[]';
  end;
begin
  Result := '';
  ltype := TRTTIContext.Create.GetType(ATypeInfo);
  if not (lType.TypeKind in [tkRecord,tkArray,tkDynArray]) then exit;

  case lType.TypeKind of
    tkArray:
      begin
        lArray := lType as TRttiArrayType;
        if lArray.ElementType.TypeKind<>tkRecord then exit;
        Result := NameAndLength(lArray.ElementType.Name,lArray.TotalElementCount);
      end;
    tkDynArray:
      begin
        lDynArray := lType as TRttiDynamicArrayType;
        if lDynArray.ElementType.TypeKind<>tkRecord then exit;

        lName := lDynArray.ElementType.Name;
        l := -1;
        if APValue<>nil then
        begin
          TValue.Make(ApValue,lDynArray.Handle,lValue);
          l := lValue.GetArrayLength;
        end;
        Result := 'RecordType='+NameAndLength(lName, l);
      end;
  else
     begin
      Result := Result + 'RecordType='+lType.Name;
      exit;
     end;
  end; // case
end;

{ TRecordSerializer<T> }

function TRecordSerializer<T>.AsValuePairs(AIndex:integer =-1): string;
var i,l :integer;
begin
 if (self.Count=0) then
 begin
   result := RecordAsValuePairs(TypeInfo(T), @self.Values, AIndex);
 end else if (AIndex>=0) and (Aindex<Count-1) then
 begin
   result := RecordAsValuePairs(TypeInfo(T), @self.AllValues[AIndex], AIndex);
 end else
 begin
   l := self.Count-1;
   for i := 0 to l do
   begin
     result := result + RecordAsValuePairs(TypeInfo(T), @self.AllValues[i], i);
   end;
 end;
end;

function TRecordSerializer<T>.AsJSON: String;
begin
  result := RecordAsJSON(typeInfo(T),@Self.Values);
end;

procedure TRecordSerializer<T>.AsValuePairs(AStrings: TStrings; AIndex:integer =-1);
begin
  AStrings.Text := RecordAsValuePairs(TypeInfo(T), @self.Values, AIndex);
end;

procedure TRecordSerializer<T>.Clear;
begin
  clearRecord(TypeInfo(T),@self.Values);
  setlength(AllValues,0);
  findex := -1;
  fIsArray := '';
end;

procedure TRecordSerializer<T>.Clone(ARecord: TRecordSerializer<T>);
begin
  CloneRecord(TypeInfo(T),@Arecord.Values, @Self);
end;

procedure TRecordSerializer<T>.Clone(ARecord: T);
begin
  CloneRecord(TypeInfo(T),@Arecord, @Self.Values);
end;

procedure TRecordSerializer<T>.FromJSON(AJSON: string);
begin
 self.Parse(JSONToValuePairs(AJSON));
end;

function TRecordSerializer<T>.getCount: integer;
begin
  result := length(Self.AllValues);
  if result>0 then fIsArray:='True';
end;

function TRecordSerializer<T>.getIsArray: boolean;
begin
  result := (Count>0) or (fIsArray='True');
end;

class operator TRecordSerializer<T>.Implicit(ARecord: T): TRecordSerializer<T>;
begin
   result.clone(ARecord);
end;

class operator TRecordSerializer<T>.Implicit(ASerializable: TRecordSerializer<T>): T;
begin
  CloneRecord(TypeInfo(T), @ASerializable.Values, @Result);
end;

Function TRecordSerializer<T>.Parse(AText: String; AMode: TSerializerParseMode=spmUpdate;
          AIndex: integer=-1): integer; 
var lList : TStringlist;
begin
  lList := TStringlist.create;
  try
     lList.Text := AText;
     lList.Sorted := true;
     result := Self.Parse(lList,Amode,AIndex);
  finally
    freeandnil(lList);
  end;
end;

procedure TRecordSerializer<T>.setIsArray(const Value: boolean);
begin
  if Value then
  begin
    if self.Count=0 then 
    begin
      setlength(AllValues,1);
      fIndex := 0;
      CloneREcord(TypeInfo(T),@Values,@AllValues[0]);
    end;
    fIsArray:='True';
  end else
  begin
    if (self.Count>0) then Setlength(AllValues,0);
    fIsArray:='';
    fIndex := -1;
  end;
end;

Function TRecordSerializer<T>.Parse(AStrings: TStrings; AMode: TSerializerParseMode=spmUpdate;
             AIndex: integer=-1): integer;  
var lIndex,
    I,SI,MaxID :integer;
    bounds : TArrayBounds;
    lList : TStringlist;
    lIsArray : boolean;
    lOffset : integer;
begin
  Result := 0;
  MaxID := self.Count-1;
  lOffset := 0;

  bounds.high := -1; bounds.low := -1;
  bounds := GetIndexBounds(AStrings);
  
  // should it be an array now considering the data
  lIsArray := // was it previously an Array?
               isArray OR 
               // has arrays but index not specified
              ((AIndex<0) and (bounds.High<>-1)) OR
               // has index Specified AND there are indexes specified
              ((AIndex>=0) and (Bounds.High>=0));

  // We might need to change the Mode if this has just become an array
  if (AMode=spmUpdate) and (self.isArray <> lIsArray) then
  begin
    AMode := spmAppend;
    lOffset := -1; // need to offset start point by 1
  end;
              
  self.isArray := lIsArray;

  // is there only 1 element to Set ?
  if ( (not lIsArray) and (Amode=spmUpdate) ) then
  begin
    if (ParseValuesToRecord(AStrings, TypeInfo(T), @Self.Values, AIndex)>0) then
       result := 1;
    exit;
  end;

  if ((lIsArray) and (AIndex>=0) ) then
  begin
    if Bounds.High=-1 then 
    begin
      bounds.Low := AIndex;
      bounds.High := AIndex;
      AIndex := -1;
    end;
    if (MaxId<bounds.high) then
    begin
      if AMode=spmUpdate then
       raise Exception.Create(
        format('Index out of bounds %u',[bounds.high]))
      else SetLength(Self.AllValues,bounds.High)
    end;
    if (ParseValuesToRecord(AStrings, TypeInfo(T), @Self.AllValues[bounds.High], AIndex)>0) then
       result := 1;
    exit;
  end;
  
  // Potentially more than 1 record
  if AMode=spmAppend then SI := self.Count+lOffset else SI:=bounds.Low;
  
  for I := bounds.Low to bounds.High do
  begin
    if (si>Count-1) then
    begin
      if AMode=spmUpdate then raise Exception.Create(
        format('Index out of bounds %u',[si]))
      else SetLength(Self.AllValues,si+1)
    end;
    if ParseValuesToRecord(AStrings,TypeInfo(T),@Self.AllValues[si],i)>0 then
    begin
      inc(result);
    end;
    inc(si);
  end;
  if (Self.count=1) and (Result=1) then
  begin
     findex := 0;
     self.Clone(Self.AllValues[0]);
  end;
end;


class operator TRecordSerializer<T>.Implicit(
  AText: string): TRecordSerializer<T>;
begin
   Result.Parse(AText);
end;

class operator TRecordSerializer<T>.Implicit(
  ARecord: TRecordSerializer<T>): String;
begin
   Result := ARecord.AsValuePairs;
end;

end.