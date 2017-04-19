unit Parser;

interface

uses
  Forms, SysUtils, Variants, Classes, ooCalc, ExtCtrls, StrUtils, Windows, Math;

procedure ConfToOds(InputFile, OutputFile : string);
procedure OdsToConf(InputFile, OutputFile : string);
procedure ConsoleWriteLn(const S: string);
function CleanStr(Value: String): String;


var
  Calc : TopofCalc;

implementation

procedure ConsoleWriteLn(const S: string);
var
  NewStr: string;
begin
  SetLength(NewStr, Length(S));
  CharToOem(PChar(S), PChar(NewStr));
  WriteLn(NewStr);
end;


function CleanStr(Value: String): String;
var
  RepF : TReplaceFlags;
  s : string;
begin
  RepF := [rfReplaceAll, rfIgnoreCase];
  s := StringReplace(Value, Chr(9), ' ', RepF);
  s := StringReplace(s, Chr(9), ' ', RepF);
  s := StringReplace(s, Chr(9), ' ', RepF);
  s := StringReplace(s, '"', '', RepF);
  s := StringReplace(s, '"', '', RepF);
  s := StringReplace(s, ' ', '', RepF);
  Result := AnsiLowerCase(Trim(s));
end;

procedure ConfToOds(InputFile, OutputFile : string);
var
  ConfFile : TextFile;
  RepF : TReplaceFlags;
  Servers : array of string;
  i, p, k, n1, n2 : integer;
  t, s : string;
  EndOfBlock, Exclude : boolean;
begin
  SetLength(Servers, 1);
  Calc := TopofCalc.OpenTable(OutputFile, False);
  if Calc.ProgLoaded then
    begin
      AssignFile(ConfFile, InputFile);
      Reset(ConfFile);
      while not EOF(ConfFile) do
        begin
          ReadLn(ConfFile, s);
          if LeftStr(CleanStr(s), 8) = 'fileset{' then
            begin
              ReadLn(ConfFile, s);
              if LeftStr(CleanStr(s), 5) = 'name=' then
                begin
                  i := High(Servers) + 1;
                  SetLength(Servers, i + 1);
                  s := StringReplace(CleanStr(s), 'name=', '', RepF);
                  Servers[i] := s;
                end;
            end;
        end;

      repeat //Сортировка
      p := 0;
      for k := 1 to High(Servers) - 1 do
        begin
          if Servers[k] > Servers[k + 1] then
            begin
              t := Servers[k];
              Servers[k] := Servers[k + 1];
              Servers[k + 1] := t;
              p := p + 1;
            end;
        end;
      until p = 0;

      Calc.ActivateSheetByIndex(1);
      Calc.SetCellText(1, 1, 'Сервер');
      Calc.SetCellText(1, 2, 'Копировать');
      Calc.SetCellText(1, 3, 'Исключить');
      n1 := 1;
      n2 := 1;
      for k := 1 to High(Servers) - 1 do
        begin
          Reset(ConfFile);
          while not EOF(ConfFile) do
            begin
              ReadLn(ConfFile, s);
              if LeftStr(CleanStr(s), 8) = 'fileset{' then
                begin
                  ReadLn(ConfFile, s);
                  if CleanStr(s) = 'name=' + Servers[k] then
                    begin
                      n1 := Max(n1, n2) + 2;
                      n2 := n1;
                      Calc.SetCellText(n1, 1, Servers[k]);
                      Calc.Bold(n1 ,1);
                      n1 := n1 + 1;
                      n2 := n2 + 1;
                      EndOfBlock := False;
                      Exclude := False;
                      while (not EOF(ConfFile)) and (not EndOfBlock) do
                        begin
                          ReadLn(ConfFile, s);
                          if LeftStr(CleanStr(s), 8) = 'fileset{' then EndOfBlock := True;
                          if LeftStr(CleanStr(s), 7) = 'exclude' then Exclude := True;
                          if (not EndOfBlock) and (LeftStr(CleanStr(s), 5) = 'file=') then
                            begin
                              if not Exclude then
                                begin
                                  Calc.SetCellText(n1, 2, ' ' + StringReplace(CleanStr(s), 'file=', '', RepF));
                                  n1 := n1 + 1;
                                end else
                                begin
                                  Calc.SetCellText(n2, 3, ' ' + StringReplace(CleanStr(s), 'file=', '', RepF));
                                  n2 := n2 + 1;
                                end;
                            end;
                        end;
                    end;
                end;
            end;
        end;
      Calc.ActivateSheetByIndex(2);
      Calc.SetCellText(1, 1, 'Сервер');
      Calc.SetCellText(1, 2, 'Пароль');
      n1 := 1;
      for k := 1 to High(Servers) - 1 do
        begin
          Reset(ConfFile);
          n1 := n1 + 1;          
          while not EOF(ConfFile) do
            begin
              ReadLn(ConfFile, s);
              if LeftStr(CleanStr(s), 7) = 'client{' then
                begin
                  ReadLn(ConfFile, s);
                  if CleanStr(s) = 'name=' + Servers[k] + '-fd' then
                    begin
                      Calc.SetCellText(n1, 1, Servers[k]);
                      Calc.Bold(n1 ,1);
                      EndOfBlock := False;
                      while (not EOF(ConfFile)) and (not EndOfBlock) do
                        begin
                          ReadLn(ConfFile, s);
                          if LeftStr(CleanStr(s), 1) = '}' then EndOfBlock := True;
                          if (not EndOfBlock) and (LeftStr(CleanStr(s), 9) = 'password=') then
                            begin
                              s := StringReplace(CleanStr(s), 'password=', '', RepF);
                              s := StringReplace(s, '#passwordforfiledaemon', '', RepF);
                              Calc.SetCellText(n1, 2, s);
                            end;
                        end;
                    end;
                end;
            end;
          Reset(ConfFile);
          while not EOF(ConfFile) do
            begin
              ReadLn(ConfFile, s);
              if LeftStr(CleanStr(s), 4) = 'job{' then
                begin
                  ReadLn(ConfFile, s);
                  if CleanStr(s) = 'name=' + Servers[k] + '-daily' then
                    begin
                      EndOfBlock := False;
                      while (not EOF(ConfFile)) and (not EndOfBlock) do
                        begin
                          ReadLn(ConfFile, s);
                          if LeftStr(CleanStr(s), 1) = '}' then EndOfBlock := True;
                          if (not EndOfBlock) and (LeftStr(CleanStr(s), 8) = 'storage=') then
                            begin
                              s := StringReplace(CleanStr(s), 'storage=', '', RepF);
                              Calc.SetCellText(n1, 3, s);
                            end;
                        end;
                    end;
                end;
            end;
        end;

      CloseFile(ConfFile);
      Calc.SaveDoc;
    end;
  try
    Calc.Destroy;
  except
  end;
end;

procedure OdsToConf(InputFile, OutputFile : string);
var
  ConfFile : TextFile;
  i, n, k, p ,f : integer;
  LastLine : boolean;
  Servers : array of string;
  t : string;
begin
  Calc := TopofCalc.OpenTable(InputFile, False);
  if Calc.ProgLoaded then
    begin
      AssignFile(ConfFile, OutputFile);
      Rewrite(ConfFile);
      Calc.ActivateSheetByIndex(1);
      SetLength(Servers, 1);
      n := 2;
      LastLine := False;
      while not LastLine do
        begin
          LastLine := True;
          for i := 1 to 3 do if (CleanStr(Calc.GetCellText(n + i, 1)) <> '') or (CleanStr(Calc.GetCellText(n + i, 2)) <> '') or (CleanStr(Calc.GetCellText(n + i, 3)) <> '') then LastLine := False;
          if CleanStr(Calc.GetCellText(n, 1)) <> '' then
            begin
              i := High(Servers) + 1;
              SetLength(Servers, i + 1);
              Servers[i] := CleanStr(Calc.GetCellText(n, 1));
            end;
          n := n + 1;
        end;
      repeat //Сортировка
      p := 0;
      for k := 1 to High(Servers) - 1 do
        begin
          if Servers[k] > Servers[k + 1] then
            begin
              t := Servers[k];
              Servers[k] := Servers[k + 1];
              Servers[k + 1] := t;
              p := p + 1;
            end;
        end;
      until p = 0;

      Write(ConfFile, UTF8Encode('#======= Файл конфигурации Bacula Director =======') + Chr(10));
      Write(ConfFile, '' + Chr(10));
      Write(ConfFile, 'Director {' + Chr(10));
      Write(ConfFile, '  Name = srv05i.Company.ru-dir' + Chr(10));
      Write(ConfFile, '  DIRport = 9101' + Chr(10));
      Write(ConfFile, '  QueryFile = "/etc/bacula/query.sql"' + Chr(10));
      Write(ConfFile, '  WorkingDirectory = "/var/lib/bacula"' + Chr(10));
      Write(ConfFile, '  PidDirectory = "/var/run"' + Chr(10));
      Write(ConfFile, '  Maximum Concurrent Jobs = 7' + Chr(10));
      Write(ConfFile, '  Password = "yILsdvlU/XHwOU+5TuJn3nMD9chyIdonHP3fmlaDA3w+"' + Chr(10));
      Write(ConfFile, '  Messages = Daemon' + Chr(10));
      Write(ConfFile, '}' + Chr(10));
      Write(ConfFile, '' + Chr(10));
      Write(ConfFile, '' + Chr(10));

      for k := 1 to High(Servers) - 1 do
        begin
          Write(ConfFile, UTF8Encode('#=== Настройки резервного копирования сервера ') + Servers[k] + UTF8Encode('.Company.ru ===') + Chr(10));
          n := 2;
          LastLine := False;
          while not LastLine do
            begin
              LastLine := True;
              for i := 1 to 3 do if (CleanStr(Calc.GetCellText(n + i, 1)) <> '') or (CleanStr(Calc.GetCellText(n + i, 2)) <> '') or (CleanStr(Calc.GetCellText(n + i, 3)) <> '') then LastLine := False;
              if CleanStr(Calc.GetCellText(n, 1)) = Servers[k] then
                begin
                  Write(ConfFile, 'Client {' + Chr(10));
                  Write(ConfFile, '  Name = ' + CleanStr(Calc.GetCellText(n, 1)) + '-fd' + Chr(10));
                  Write(ConfFile, '  Address = ' + Servers[k] + '.Company.ru' + Chr(10));
                  Write(ConfFile, '  FDPort = 9102' + Chr(10));
                  Write(ConfFile, '  Catalog = MyCatalog' + Chr(10));
                  Calc.ActivateSheetByIndex(2);
                  Write(ConfFile, '  Password = "' + CleanStr(Calc.GetCellText(k + 1, 2)) + '"' + Chr(10));
                  Calc.ActivateSheetByIndex(1);
                  Write(ConfFile, '  File Retention = 7 days' + Chr(10));
                  Write(ConfFile, '  Job Retention = 7 days' + Chr(10));
                  Write(ConfFile, '  AutoPrune = yes' + Chr(10));
                  Write(ConfFile, '}' + Chr(10));
                  Write(ConfFile, '' + Chr(10));
                end;
              n := n + 1;
            end;
          n := 2;
          LastLine := False;
          while not LastLine do
            begin
              LastLine := True;
              for i := 1 to 3 do if (CleanStr(Calc.GetCellText(n + i, 1)) <> '') or (CleanStr(Calc.GetCellText(n + i, 2)) <> '') or (CleanStr(Calc.GetCellText(n + i, 3)) <> '') then LastLine := False;
              if CleanStr(Calc.GetCellText(n, 1)) = Servers[k] then
                begin
                  Write(ConfFile, 'FileSet {' + Chr(10));
                  Write(ConfFile, '  Name = "' + Servers[k] + '"' + Chr(10));
                  Write(ConfFile, '  Include {' + Chr(10));
                  Write(ConfFile, '    Options {' + Chr(10));
                  Write(ConfFile, '    signature = MD5' + Chr(10));
                  Write(ConfFile, '    compression = GZIP' + Chr(10));
                  Write(ConfFile, '    onefs=no' + Chr(10));
                  Write(ConfFile, '  }' + Chr(10));
                  f := n + 1;
                  while CleanStr(Calc.GetCellText(f, 2)) <> '' do
                    begin
                      Write(ConfFile, '  File = ' + CleanStr(Calc.GetCellText(f, 2)) + Chr(10));
                      f := f + 1;
                    end;
                  Write(ConfFile, '  }' + Chr(10));
                  Write(ConfFile, '  Exclude {' + Chr(10));
                  f := n + 1;
                  while CleanStr(Calc.GetCellText(f, 3)) <> '' do
                    begin
                      Write(ConfFile, '  File = ' + CleanStr(Calc.GetCellText(f, 3)) + Chr(10));
                      f := f + 1;
                    end;
                  Write(ConfFile, '  }' + Chr(10));
                  Write(ConfFile, '}' + Chr(10));
                  Write(ConfFile, '' + Chr(10));
                end;
              n := n + 1;
            end;
          n := 2;
          LastLine := False;
          while not LastLine do
            begin
              LastLine := True;
              for i := 1 to 3 do if (CleanStr(Calc.GetCellText(n + i, 1)) <> '') or (CleanStr(Calc.GetCellText(n + i, 2)) <> '') or (CleanStr(Calc.GetCellText(n + i, 3)) <> '') then LastLine := False;
              if CleanStr(Calc.GetCellText(n, 1)) = Servers[k] then
                begin
                  Write(ConfFile, 'Schedule {' + Chr(10));
                  Write(ConfFile, '  Name = "' + Servers[k] + '-daily"' + Chr(10));
                  Write(ConfFile, '  Run = Full 1st sun at 23:05' + Chr(10));
                  Write(ConfFile, '  Run = Differential 2nd-5th sun at 23:05' + Chr(10));
                  Write(ConfFile, '  Run = Incremental mon-sun at 02:00' + Chr(10));
                  Write(ConfFile, '}' + Chr(10));
                  Write(ConfFile, '' + Chr(10));
                end;
              n := n + 1;
            end;
          n := 2;
          LastLine := False;
          while not LastLine do
            begin
              LastLine := True;
              for i := 1 to 3 do if (CleanStr(Calc.GetCellText(n + i, 1)) <> '') or (CleanStr(Calc.GetCellText(n + i, 2)) <> '') or (CleanStr(Calc.GetCellText(n + i, 3)) <> '') then LastLine := False;
              if CleanStr(Calc.GetCellText(n, 1)) = Servers[k] then
                begin
                  Write(ConfFile, 'Job {' + Chr(10));
                  Write(ConfFile, '  Name = "' + Servers[k] + '-daily"' + Chr(10));
                  Write(ConfFile, '  Client = ' + Servers[k] + '-fd' + Chr(10));
                  Write(ConfFile, '  Write Bootstrap = "/var/lib/bacula/' + Servers[k] + '-daily.bsr"' + Chr(10));
                  Write(ConfFile, '  Type = Backup' + Chr(10));
                  Write(ConfFile, '  Maximum Concurrent Jobs = 7' + Chr(10));
                  Write(ConfFile, '  Enabled = yes' + Chr(10));
                  Write(ConfFile, '  Level = Full' + Chr(10));
                  Write(ConfFile, '  FileSet = "' + Servers[k] + '"' + Chr(10));
                  Write(ConfFile, '  Messages = Standard' + Chr(10));
                  Write(ConfFile, '  Pool = ' + Servers[k] + '-daily' + Chr(10));
                  Write(ConfFile, '  Schedule = ' + Servers[k] + '-daily' + Chr(10));
                  Calc.ActivateSheetByIndex(2);
                  Write(ConfFile, '  Storage = ' + CleanStr(Calc.GetCellText(k + 1, 3)) + Chr(10));
                  Calc.ActivateSheetByIndex(1);
                  Write(ConfFile, '  Prune Volumes = no' + Chr(10));
                  Write(ConfFile, '}' + Chr(10));
                  Write(ConfFile, '' + Chr(10));
                end;
              n := n + 1;
            end;
          n := 2;
          LastLine := False;
          while not LastLine do
            begin
              LastLine := True;
              for i := 1 to 3 do if (CleanStr(Calc.GetCellText(n + i, 1)) <> '') or (CleanStr(Calc.GetCellText(n + i, 2)) <> '') or (CleanStr(Calc.GetCellText(n + i, 3)) <> '') then LastLine := False;
              if CleanStr(Calc.GetCellText(n, 1)) = Servers[k] then
                begin
                  Write(ConfFile, 'Job {' + Chr(10));
                  Write(ConfFile, '  Name = "' + Servers[k] + '-Restore"' + Chr(10));
                  Write(ConfFile, '  Type = Restore' + Chr(10));
                  Write(ConfFile, '  Client=' + Servers[k] + '-fd' + Chr(10));
                  Write(ConfFile, '  FileSet="' + Servers[k] + '"' + Chr(10));
                  Calc.ActivateSheetByIndex(2);
                  Write(ConfFile, '  Storage = ' + CleanStr(Calc.GetCellText(k + 1, 3)) + Chr(10));
                  Calc.ActivateSheetByIndex(1);
                  Write(ConfFile, '  Pool = ' + Servers[k] + '-daily' + Chr(10));
                  Write(ConfFile, '  Messages = Standard' + Chr(10));
                  Write(ConfFile, '  Where = /var/backup/bacula-restores' + Chr(10));
                  Write(ConfFile, '}' + Chr(10));
                  Write(ConfFile, '' + Chr(10));
                end;
              n := n + 1;
            end;
          n := 2;
          LastLine := False;
          while not LastLine do
            begin
              LastLine := True;
              for i := 1 to 3 do if (CleanStr(Calc.GetCellText(n + i, 1)) <> '') or (CleanStr(Calc.GetCellText(n + i, 2)) <> '') or (CleanStr(Calc.GetCellText(n + i, 3)) <> '') then LastLine := False;
              if CleanStr(Calc.GetCellText(n, 1)) = Servers[k] then
                begin
                  Write(ConfFile, 'Pool {' + Chr(10));
                  Write(ConfFile, '  Name = ' + Servers[k] + '-daily' + Chr(10));
                  Write(ConfFile, '  Pool Type = Backup' + Chr(10));
                  Write(ConfFile, '  Recycle = yes' + Chr(10));
                  Write(ConfFile, '  AutoPrune = yes' + Chr(10));
                  Write(ConfFile, '  Volume Retention = 7 days' + Chr(10));
                  Write(ConfFile, '  LabelFormat = "' + Servers[k] + '-daily-"' + Chr(10));
                  Write(ConfFile, '}' + Chr(10));
                  Write(ConfFile, '' + Chr(10));
                end;
              n := n + 1;
            end;
        end;
      CloseFile(ConfFile);
    end;
  try
    Calc.Destroy;
  except
  end;
end;


end.
