program BackupConfig;

{$APPTYPE CONSOLE}

uses
  Forms,
  SysUtils,
  Parser in 'Parser.pas',
  ooCalc in 'ooCalc.pas',
  StrUtils;

var
  InputFile, OutputFile : string;

{$R *.res}

begin
  Application.Initialize;
  if (ParamCount = 0) or ((ParamCount = 1) and (ParamStr(1) = '/?')) then ConsoleWriteLn('��������� �������: BackupConfig.exe ����_bacula-dir.conf ����.ods (��� ��������)');
  InputFile := '';
  OutputFile := '';
  if ParamCount = 2 then
    begin
      InputFile := ParamStr(1);
      OutputFile := ParamStr(2);
    end;
  if (RightStr(InputFile, 5) = '.conf') and FileExists(InputFile) and (RightStr(OutputFile, 4) = '.ods') and FileExists(OutputFile) then ConfToOds(InputFile, OutputFile);
  if (RightStr(InputFile, 4) = '.ods') and FileExists(InputFile) and (RightStr(OutputFile, 5) = '.conf') then OdsToConf(InputFile, OutputFile);
  Application.Run;
end.
