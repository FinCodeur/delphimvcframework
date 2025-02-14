// *************************************************************************** }
//
// Delphi MVC Framework
//
// Copyright (c) 2010-2021 Daniele Teti and the DMVCFramework Team
//
// https://github.com/danieleteti/delphimvcframework
//
// ***************************************************************************
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// ***************************************************************************

unit MVCFramework.SQLGenerators.PostgreSQL;

interface

uses
  System.Rtti,
  System.Generics.Collections,
  FireDAC.Phys.FB,
  FireDAC.Phys.FBDef,
  MVCFramework.ActiveRecord,
  MVCFramework.Commons,
  MVCFramework.RQL.Parser;

type
  TMVCSQLGeneratorPostgreSQL = class(TMVCSQLGenerator)
  protected
    function GetCompilerClass: TRQLCompilerClass; override;
  public
    function CreateSelectSQL(
      const TableName: string;
      const Map: TFieldsMap;
      const PKFieldName: string;
      const PKOptions: TMVCActiveRecordFieldOptions): string; override;
    function CreateInsertSQL(
      const TableName: string;
      const Map: TFieldsMap;
      const PKFieldName: string;
      const PKOptions: TMVCActiveRecordFieldOptions): string; override;
    function CreateUpdateSQL(
      const TableName: string;
      const Map: TFieldsMap;
      const PKFieldName: string;
      const PKOptions: TMVCActiveRecordFieldOptions): string; override;
    function CreateDeleteSQL(
      const TableName: string;
      const Map: TFieldsMap;
      const PKFieldName: string;
      const PKOptions: TMVCActiveRecordFieldOptions): string; override;
    function CreateDeleteAllSQL(
      const TableName: string): string; override;
    function CreateSelectByPKSQL(
      const TableName: string;
      const Map: TFieldsMap; const PKFieldName: string;
      const PKOptions: TMVCActiveRecordFieldOptions): string; override;
    function CreateSQLWhereByRQL(
      const RQL: string;
      const Mapping: TMVCFieldsMapping;
      const UseArtificialLimit: Boolean;
      const UseFilterOnly: Boolean;
      const MaxRecordCount: UInt32 = TMVCConstants.MAX_RECORD_COUNT): string; override;
    function CreateSelectCount(
      const TableName: string): string; override;
    function GetSequenceValueSQL(const PKFieldName: string;
      const SequenceName: string;
      const Step: Integer = 1): string; override;
  end;

implementation

{
  All identifiers (including column names) that are not double-quoted are folded to
  lower case in PostgreSQL. Column names that were created with double-quotes and thereby
  retained upper-case letters (and/or other syntax violations) have to be double-quoted
  for the rest of their life.
}

uses
  System.SysUtils,
  MVCFramework.RQL.AST2PostgreSQL;

function TMVCSQLGeneratorPostgreSQL.CreateInsertSQL(const TableName: string; const Map: TFieldsMap;
  const PKFieldName: string; const PKOptions: TMVCActiveRecordFieldOptions): string;
var
  lKeyValue: TPair<TRttiField, TFieldInfo>;
  lSB: TStringBuilder;
  lPKInInsert: Boolean;
begin
  lPKInInsert := (not PKFieldName.IsEmpty) and (not(TMVCActiveRecordFieldOption.foAutoGenerated in PKOptions));
  lPKInInsert := lPKInInsert and (not(TMVCActiveRecordFieldOption.foReadOnly in PKOptions));
  lSB := TStringBuilder.Create;
  try
    lSB.Append('INSERT INTO ' + GetTableNameForSQL(TableName) + ' (');
    if lPKInInsert then
    begin
      lSB.Append(GetFieldNameForSQL(PKFieldName) + ',');
    end;

    for lKeyValue in Map do
    begin
      // if not(foTransient in lKeyValue.Value.FieldOptions) then
      if lKeyValue.Value.Writeable then
      begin
        lSB.Append(GetFieldNameForSQL(lKeyValue.Value.FieldName) + ',');
      end;
    end;
    lSB.Remove(lSB.Length - 1, 1);
    lSB.Append(') values (');
    if lPKInInsert then
    begin
      lSB.Append(':' + GetParamNameForSQL(PKFieldName) + ',');
    end;
    for lKeyValue in Map do
    begin
      if lKeyValue.Value.Writeable then
      begin
        lSB.Append(':' + GetParamNameForSQL(lKeyValue.Value.FieldName) + ',');
      end;
    end;
    lSB.Remove(lSB.Length - 1, 1);
    lSB.Append(')');

    if TMVCActiveRecordFieldOption.foAutoGenerated in PKOptions then
    begin
      lSB.Append(' RETURNING ' + GetFieldNameForSQL(PKFieldName));
    end;
    Result := lSB.ToString;
  finally
    lSB.Free;
  end;
end;

function TMVCSQLGeneratorPostgreSQL.CreateSelectByPKSQL(
  const TableName: string;
  const Map: TFieldsMap; const PKFieldName: string;
  const PKOptions: TMVCActiveRecordFieldOptions): string;
begin
  if PKFieldName.IsEmpty then
  begin
    raise EMVCActiveRecord.Create('No primary key provided. [HINT] Define a primary key field adding foPrimaryKey in field options.');
  end;

  Result := CreateSelectSQL(TableName, Map, PKFieldName, PKOptions) + ' WHERE ' +
    GetFieldNameForSQL(PKFieldName) + '= :' + GetParamNameForSQL(PKFieldName); // IntToStr(PrimaryKeyValue);
end;

function TMVCSQLGeneratorPostgreSQL.CreateSelectCount(
  const TableName: string): string;
begin
  Result := 'SELECT count(*) FROM ' + GetTableNameForSQL(TableName);
end;

function TMVCSQLGeneratorPostgreSQL.CreateSelectSQL(const TableName: string;
  const Map: TFieldsMap; const PKFieldName: string;
  const PKOptions: TMVCActiveRecordFieldOptions): string;
begin
  Result := 'SELECT ' + TableFieldsDelimited(Map, PKFieldName, ',') + ' FROM ' + GetTableNameForSQL(TableName);
end;

function TMVCSQLGeneratorPostgreSQL.CreateSQLWhereByRQL(
  const RQL: string;
  const Mapping: TMVCFieldsMapping;
  const UseArtificialLimit: Boolean;
  const UseFilterOnly: Boolean;
  const MaxRecordCount: UInt32): string;
var
  lPostgreSQLCompiler: TRQLPostgreSQLCompiler;
begin
  lPostgreSQLCompiler := TRQLPostgreSQLCompiler.Create(Mapping);
  try
    GetRQLParser(MaxRecordCount).Execute(RQL, Result, lPostgreSQLCompiler, UseArtificialLimit, UseFilterOnly);
  finally
    lPostgreSQLCompiler.Free;
  end;
end;

function TMVCSQLGeneratorPostgreSQL.CreateUpdateSQL(const TableName: string; const Map: TFieldsMap;
  const PKFieldName: string; const PKOptions: TMVCActiveRecordFieldOptions): string;
var
  lPair: TPair<TRttiField, TFieldInfo>;
begin
  Result := 'UPDATE ' + GetTableNameForSQL(TableName) + ' SET ';
  for lPair in Map do
  begin
    if lPair.Value.Writeable then
    begin
      Result := Result + GetFieldNameForSQL(lPair.Value.FieldName) + ' = :' +
        GetParamNameForSQL(lPair.Value.FieldName) + ',';
    end;
  end;
  Result[Length(Result)] := ' ';
  if not PKFieldName.IsEmpty then
  begin
    Result := Result + ' where ' + GetFieldNameForSQL(PKFieldName) + '= :' + GetParamNameForSQL(PKFieldName);
  end;
end;

function TMVCSQLGeneratorPostgreSQL.GetCompilerClass: TRQLCompilerClass;
begin
  Result := TRQLPostgreSQLCompiler;
end;

function TMVCSQLGeneratorPostgreSQL.GetSequenceValueSQL(const PKFieldName,
  SequenceName: string; const Step: Integer): string;
begin
  Result := Format('SELECT nextval(''%s'') %s', [SequenceName, GetFieldNameForSQL(PKFieldName)]);
end;

function TMVCSQLGeneratorPostgreSQL.CreateDeleteAllSQL(
  const TableName: string): string;
begin
  Result := 'DELETE FROM ' + GetTableNameForSQL(TableName);
end;

function TMVCSQLGeneratorPostgreSQL.CreateDeleteSQL(const TableName: string; const Map: TFieldsMap;
  const PKFieldName: string; const PKOptions: TMVCActiveRecordFieldOptions): string;
begin
  Result := CreateDeleteAllSQL(TableName) + ' WHERE ' + GetFieldNameForSQL(PKFieldName) + '=:' +
    GetParamNameForSQL(PKFieldName);
end;

initialization

TMVCSQLGeneratorRegistry.Instance.RegisterSQLGenerator('postgresql', TMVCSQLGeneratorPostgreSQL);

finalization

TMVCSQLGeneratorRegistry.Instance.UnRegisterSQLGenerator('postgresql');

end.
