unit RecordUtils;

////////////////////////////////////////////////
// Copyright Glen Kleidon 2017                //
// Part of the Delphi Tips Repo               //
// https://github.com/glenkleidon/DelphiTips  //
////////////////////////////////////////////////

interface
   uses System.sysUtils, System.Classes, System.Rtti, System.Generics.collections;
   type PStrings = ^TStrings;
   
   Type TRecordSerializer<T> = Record
       Values : T;
       Procedure Clear;
       Procedure Clone(ARecord: T);
       Procedure Parse(AStrings:TStrings; AIndex: integer=-1); overload;
       Procedure Parse(AText: String; AIndex: integer=-1); overload;
       Function AsValuePairs(AIndex:integer =-1): string; overload;
       Procedure AsValuePairs(AStrings:TStrings; AIndex:integer =-1); overload;
       class operator Implicit(ASerializable: TRecordSerializer<T>): T;
       class operator Implicit(ARecord: T): TRecordSerializer<T>;
   end;

   function IndexedName(AId: string; AIndex: integer=-1): string;
   function ParseStringAsIndex(AId: string; AStrings: TStrings; AIndex: integer=-1): string;
   function AsValuePair(AId: string; AValue: string; AIndex: integer=-1; ALineEnding: string=''):string;
   function AsValuePairRow(AId: string; AValue: string; AIndex: integer=-1): string;
   Function RecordAsValuePairs(ATypeInfo: Pointer; APValue: Pointer; AIndex: integer = -1): string;
   Function ParseValuesToRecord(AStrings: TStrings; ATypeInfo: Pointer; APValue: Pointer; AIndex: integer = -1): string; overload;
   Function GetValuePairHeader(ATypeInfo: Pointer; APValue: Pointer): string;
   Procedure CloneRecord(ATypeInfo: Pointer; APRecordToClone: Pointer; APClonedRecord : Pointer );
   Procedure ClearRecord(ATypeInfo: Pointer; APValue: Pointer);


implementation

  uses System.TypInfo;

function IndexedName(AId: string; AIndex: integer=-1): string;
begin
 if (Aindex<0) then Result := AId else Result := format('%s[%u]',[AId, AIndex]);
end;


Function ParseValuesToRecord(AStrings: TStrings; ATypeInfo: Pointer; APValue: Pointer; AIndex: integer = -1): string;
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
  lDouble: Double;
  Buffer : Pointer;
begin
  lContext := TRTTIContext.Create;
  ltype := lContext.GetType(ATypeInfo);
  lFields := lType.getFields;
  lText:= TStringlist.create;
  try
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
           end;
           tkInteger,
           tkInt64:
           begin
              if tryStrToInt64(lValue,lInt) then
                  lField.SetValue(APValue,lInt)
              else raise Exception.Create('Invalid Integer Type Cast');
           end;
           tkFloat:
           begin
              if tryStrToFloat(lValue,lDouble) then
                  lField.SetValue(APValue,lDouble)
              else raise Exception.Create('Invalid Float Type Cast');
           end;
         else  lField.setValue(APValue, TValue(lValue));
         end;
      end;
    end;
    result := lText.text;
  finally
    freeAndNil(lText);
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
begin
 result := RecordAsValuePairs(TypeInfo(T), @self.Values, AIndex);
end;

procedure TRecordSerializer<T>.AsValuePairs(AStrings: TStrings; AIndex:integer =-1);
begin
  AStrings.Text := RecordAsValuePairs(TypeInfo(T), @self.Values, AIndex);
end;

procedure TRecordSerializer<T>.Clear;
begin
  clearRecord(TypeInfo(T),@self);
end;

procedure TRecordSerializer<T>.Clone(ARecord: T);
begin
  CloneRecord(TypeInfo(T),@Arecord, @Self);
end;

class operator TRecordSerializer<T>.Implicit(ARecord: T): TRecordSerializer<T>;
begin
   result.clone(ARecord);
end;

class operator TRecordSerializer<T>.Implicit(ASerializable: TRecordSerializer<T>): T;
begin
  CloneRecord(TypeInfo(T), @ASerializable.Values, @Result);  
end;

procedure TRecordSerializer<T>.Parse(AStrings: TStrings; AIndex: integer=-1);
begin
  ParseValuesToRecord(AStrings,TypeInfo(T),@Self.Values,AIndex);
end;

procedure TRecordSerializer<T>.Parse(AText: String; AIndex: integer=-1);
var lList: TStringlist;
begin
  lList:=TStringlist.Create;
  try
    lList.Text := AText;
    self.Parse(lList,AIndex);
  finally
    freeandnil(lList);
  end;
end;

end.