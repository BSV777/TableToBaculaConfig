unit ooCalc;

interface

uses
  SysUtils, Variants, ComObj;

type TTipooCalc = (ttcError, ttcNone, ttcExcel, ttcOpenOffice);

type TopofCalc = class(TObject)
    Document : Variant;
    DeskTop : Variant;
    Programa : Variant;
    Tipoo : TTipooCalc;
    FileName : string;
    ActiveSheet : Variant;
    Visible : boolean;
    fVisible : boolean;
    function GetIsExcel: boolean;
    function GetIsOpenOffice: boolean;
    function GetProgLoaded: boolean;
    function GetDocLoaded: boolean;
    procedure LoadProg;
    procedure NewDoc;
    procedure CloseDoc;
    procedure CloseProg;
    constructor CreateTable(MyTipoo: TTipooCalc; MakeVisible: boolean);
    procedure LoadDoc;
    constructor OpenTable(Name: string; MakeVisible: boolean);
    destructor Destroy; override;
    function SaveDoc: boolean;
    function PrintDoc: boolean;
    procedure ShowPrintPreview;
    procedure SetVisible(v: boolean);
    function GetCountSheets: integer;
    function ActivateSheetByIndex(nIndex: integer): boolean;
    function ActivateSheetByName(SheetName: string; CaseSensitive: boolean): boolean;
    function GetActiveSheetName: string;
    procedure SetActiveSheetName(NewName: string);
    function IsActiveSheetProtected: boolean;
    procedure AddNewSheet(NewName: string);
    function GetCellText(row, col: integer): string;
    procedure SetCellText(row, col: integer; Txt: string);
    function GetCellColor(row, col: integer): longint;
    function GetCellTextByName(Range: string): string;
    procedure SetCellTextByName(Range: string; Txt: string);
    procedure FontSize(row,col:integer;oosize:integer);
    procedure Bold(row,col: integer);
    procedure ColumnWidth(col,  width: integer); //Width in 1/100 of mm.
    function FileNameToURL(FileName: string): string;
    function ooCreateValue(ooName: string; ooData: variant): variant;
    procedure ooDispatch(ooCommand: string; ooParams: variant);
  private
  public
    property IsExcel : boolean read GetIsExcel;
    property IsOpenOffice : boolean read GetIsOpenOffice;
    property ProgLoaded : boolean read GetProgLoaded;
    property DocLoaded : boolean read GetDocLoaded;
    property ActiveSheetName : string read GetActiveSheetName;
  end;


implementation


//при работе с таблицами, информаци€ о типе документа может принимать следующие состо€ни€:

//данные функции определ€ет тип приложени€

function  TopofCalc.GetIsExcel: boolean;
begin
  result:= (Tipoo=ttcExcel);
end;

function  TopofCalc.GetIsOpenOffice: boolean;
begin
  result:= (Tipoo=ttcOpenOffice);
end;

//и произведена ли его загрузка

function TopofCalc.GetProgLoaded: boolean;
begin
  result:= not (VarIsEmpty(Programa) or VarIsNull(Programa));
end;

function TopofCalc.GetDocLoaded: boolean;
begin
  result:= not (VarIsEmpty(Document) or VarIsNull(Document));
end;

//запуск приложени€Е

procedure TopofCalc.LoadProg;
begin
  if ProgLoaded then CloseProg;
  if ((UpperCase(ExtractFileExt(FileName))='.XLS') or
     (UpperCase(ExtractFileExt(FileName))='.XLT')) then begin
    //Excel...
    Programa:= CreateOleObject('Excel.Application');
    Programa.Application.EnableEvents:=false;
    Programa.displayAlerts:=false;
    if ProgLoaded then Tipoo:= ttcExcel;
  end;
  // Another filetype? Let's go with OpenOffice...
  if ((UpperCase(ExtractFileExt(FileName))='.ODS') or
     (UpperCase(ExtractFileExt(FileName))='.OTS')) then begin
    //OpenOffice.calc...
    Programa:= CreateOleObject('com.sun.star.ServiceManager');
    if ProgLoaded then Tipoo:= ttcOpenOffice;
  end;
  //Still no program loaded?
  if not ProgLoaded then begin
    Tipoo:= ttcError;
    raise Exception.create('TopofCalc.create failed, may be no Office is installed?');
  end;
end;

//провед€ все необходимые проверки, мы можем создать электронную таблицу

procedure TopofCalc.NewDoc;
var ooParams: variant;
begin
  if not ProgLoaded
     then raise exception.create('No program loaded for the new document.');
  if DocLoaded then CloseDoc;
  DeskTop:= Unassigned;
  if IsExcel then begin
    Programa.WorkBooks.Add();
    Programa.Visible:= Visible;
    Document:= Programa.ActiveWorkBook;
    ActiveSheet:= Document.ActiveSheet;
  end;
  if IsOpenOffice then begin
    Desktop:=  Programa.CreateInstance('com.sun.star.frame.Desktop');
    ooParams:=    VarArrayCreate([0, 0], varVariant);
    ooParams[0]:= ooCreateValue('Hidden', not Visible);
    Document:= Desktop.LoadComponentFromURL('private:factory/scalc', '_blank', 0, ooParams);
    ActivateSheetByIndex(1);
  end;
end;

//а теперь закрыть таблицу

procedure TopofCalc.CloseDoc;
begin
  if DocLoaded then begin
    try
      if IsOpenOffice then Document.Dispose;
      if IsExcel      then Document.close;
    finally
      //Clean up both "pointer"...
      Document:= Null;
      ActiveSheet:= Null;
    end;
  end;
end;

//и само приложение

procedure TopofCalc.CloseProg;
begin
  if DocLoaded then CloseDoc;
  if ProgLoaded then begin
    try
      if IsExcel then Programa.Quit;
      Programa:= Unassigned;
    finally end;
  end;
  Tipoo:= ttcNone;
end;

//вынесем последовательности команд создани€ таблицы в отдельную процедуру конструктора

constructor TopofCalc.CreateTable(MyTipoo: TTipooCalc; MakeVisible: boolean);
var
  i: integer;
  IsFirstTry: boolean;
begin
  //Close all opened things first...
  if DocLoaded  then CloseDoc;
  if ProgLoaded then CloseProg;
  IsFirstTry:= true;
  for i:= 1 to 2 do begin
    //Try to open OpenOffice...
    if (MyTipoo = ttcOpenOffice) or (MyTipoo = ttcNone)then begin
      Programa:= CreateOleObject('com.sun.star.ServiceManager');
      if ProgLoaded then begin
        Tipoo:= ttcOpenOffice;
        break;
      end else begin
        if IsFirstTry then begin
          //Try Excel as my second choice
          MyTipoo:= ttcExcel;
          IsFirstTry:= false;
        end else begin
          //Both failed!
          break;
        end;
      end;
    end;
    //Try to open Excel...
    if (MyTipoo = ttcExcel) or (MyTipoo = ttcNone) then begin
      Programa:= CreateOleObject('Excel.Application');
      if ProgLoaded then begin
        Tipoo:= ttcExcel;
        break;
      end else begin
        if IsFirstTry then begin
          //Try OpenOffice as my second choice
          MyTipoo:= ttcOpenOffice;
          IsFirstTry:= false;
        end else begin
          //Both failed!
          break;
        end;
      end;
    end;
  end;
  //Was it able to open any of them?
  if Tipoo = ttcNone then begin
    Tipoo:= ttcError;
    raise exception.create('TopofCalc.create failed, may be no OpenOffice is installed?');
  end;
  //Add a blank document...
  fVisible:= MakeVisible;
  NewDoc;
end;

//это Ц создание таблицы Ђс нул€ї. откроем существующую

procedure TopofCalc.LoadDoc;
var ooParams: variant;
begin
  if FileName='' then exit;
  if not ProgLoaded then LoadProg;
  if DocLoaded then CloseDoc;
  DeskTop:= Unassigned;
  if IsExcel then begin
    Document:=Programa.WorkBooks.Add(FileName);
    Document.visible:=visible;
    Document:= Programa.ActiveWorkBook;
    ActiveSheet:= Document.ActiveSheet;
  end;
  if IsOpenOffice then begin
    Desktop:=  Programa.CreateInstance('com.sun.star.frame.Desktop');
    ooParams:=    VarArrayCreate([0, 0], varVariant);
    ooParams[0]:= ooCreateValue('Hidden', not Visible);
    Document:= Desktop.LoadComponentFromURL(FileNameToURL(FileName), '_blank', 0, ooParams);
      ActivateSheetByIndex(1);
  end;
  if Tipoo=ttcNone then
    raise exception.create('File "'+FileName+'" is not loaded. Are you install OpenOffice?');
end;

//опишем еще один конструктор дл€ открыти€ существующей таблицы

constructor TopofCalc.OpenTable(Name: string; MakeVisible: boolean);
begin
  //Store values...
  FileName:= Name;
  fVisible:=  MakeVisible;
  //Open program and document...
  LoadProg;
  LoadDoc;
end;

//кроме того, опишем уничтожение объекта

destructor TopofCalc.Destroy;
begin
  CloseDoc;
  CloseProg;
  inherited;
end;

//по аналогии, опишем сохранение

function TopofCalc.SaveDoc: boolean;
begin
  result:= false;
  if DocLoaded then begin
    if IsExcel then begin
      Document.Save;
      result:= true;
    end;
    if IsOpenOffice then begin
      Document.Store;
      result:= true;
    end;
  end;
end;

//печать

function TopofCalc.PrintDoc: boolean;
var ooParams: variant;
begin
  result:= false;
  if DocLoaded then begin
    if IsExcel then begin
      Document.PrintOut;
      result:= true;
    end;
    if IsOpenOffice then begin
      //NOTE: OpenOffice will print all sheets with Printable areas, but if no
      //printable areas are defined in the doc, it will print all entire sheets.
      //Optional parameters (wait until fully sent to printer)...
      ooParams:=  VarArrayCreate([0, 0], varVariant);
      ooParams[0]:= ooCreateValue('Wait', true);
      Document.Print(ooParams);
      result:= true;
    end;
  end;
end;

//и режим предварительного просмотра

procedure TopofCalc.ShowPrintPreview;
begin
  if DocLoaded then begin
    Visible:= true;
    if IsExcel then
      Document.PrintOut(,,,true);
    if IsOpenOffice then
      ooDispatch('.uno:PrintPreview', Unassigned);
  end;
end;

//нам также пригодитс€ скрытие/отображение на экране

procedure TopofCalc.SetVisible(v: boolean);
begin
  if DocLoaded and (v<>fVisible) then begin
    if IsExcel then
      Programa.Visible:= v;
    if IsOpenOffice then
      Document.getCurrentController.getFrame.getContainerWindow.setVisible(v);
    fVisible:= v;
  end;
end;

//теперь, мы можем получить информацию о таблице.
//Ќачнем с количества листов

function TopofCalc.GetCountSheets: integer;
begin
  result:= 0;
  if DocLoaded then begin
    if IsExcel      then result:= Document.Sheets.count;
    if IsOpenOffice then result:= Document.getSheets.GetCount;
  end;
end;

//и сделаем один из листов активным.

function TopofCalc.ActivateSheetByIndex(nIndex: integer): boolean;
begin
  result:= false;
  if DocLoaded then begin
    if IsExcel then begin
      Document.Sheets[nIndex].activate;
      ActiveSheet:= Document.ActiveSheet;
      result:= true;
    end;
//Index is 1 based in Excel, but OpenOffice uses it 0-based
    if IsOpenOffice then begin
      ActiveSheet:= Document.getSheets.getByIndex(nIndex-1);
      result:= true;
    end;
    sleep(100); //Asyncronus, so better give it time to make the change
  end;
end;

//активным лист можно сделать не только по его индексу, но и по названию

function TopofCalc.ActivateSheetByName(SheetName: string; CaseSensitive: boolean): boolean;
var
  OldActiveSheet: variant;
  i: integer;
begin
  result:= false;
  if DocLoaded then begin
    if CaseSensitive then begin
      //Find the EXACT name...
      if IsExcel then begin
        Document.Sheets[SheetName].Select;
        ActiveSheet:= Document.ActiveSheet;
        result:= true;
      end;
      if IsOpenOffice then begin
        ActiveSheet:= Document.getSheets.getByName(SheetName);
        result:= true;
      end;
    end else begin
      //Find the Sheet regardless of the case...
      OldActiveSheet:= ActiveSheet;
      for i:= 1 to GetCountSheets do begin
        ActivateSheetByIndex(i);
        if UpperCase(ActiveSheetName)=UpperCase(SheetName) then begin
          result:= true;
          Exit;
        end;
      end;
      //If not found, let the old active sheet active...
      ActiveSheet:= OldActiveSheet;
    end;
  end;
end;

//getByName(string) имеет свойства дл€ чтени€ и записи

function TopofCalc.GetActiveSheetName: string;
begin
  if DocLoaded then begin
    if IsExcel then
      result:= ActiveSheet.Name;
    if IsOpenOffice then
      result:= ActiveSheet.GetName;
  end;
end;

procedure TopofCalc.SetActiveSheetName(NewName: string);
var ooParams:variant;
begin
  if DocLoaded then begin
    if IsExcel then
      Programa.ActiveSheet.Name:= NewName;
    if IsOpenOffice then begin
      ActiveSheet.setName(NewName);
      //This code always changes the name of "visible" sheet, not active one!
      ooParams:= VarArrayCreate([0, 0], varVariant);
      ooParams[0]:= ooCreateValue('Name', NewName);
      ooDispatch('.uno:RenameTable', ooParams);
    end;
  end;
end;

//пригодитс€ проверка на защиту листа от записи

function TopofCalc.IsActiveSheetProtected: boolean;
begin
  result:= false;
  if DocLoaded then begin
    if IsExcel then
      result:= ActiveSheet.ProtectContents;
    if IsOpenOffice then
      result:= ActiveSheet.IsProtected;
  end;
end;

//добваление листа

procedure TopofCalc.AddNewSheet(NewName: string);
var
  ooSheets: variant;
begin
  if DocLoaded then begin
    if IsExcel then begin
      Document.WorkSheets.Add;
      Document.ActiveSheet.Name:= NewName;
      //Active sheet has move to this new one, so I need to update the var
      ActiveSheet:= Document.ActiveSheet;
    end;
    if IsOpenOffice then begin
      ooSheets:= Document.getSheets;
      ooSheets.insertNewByName(NewName, 1);
      //Redefine active sheet to this new one
      ActiveSheet:= ooSheets.getByName(NewName);
    end;
  end;
end;

//перейдем от листов к €чейкам
//получить значение €чейки

//OpenOffice start at cell (0,0) while Excel at (1,1)
function TopofCalc.GetCellText(row, col: integer): string;
begin
  if DocLoaded then begin
    if IsExcel then      result:= ActiveSheet.Cells[row, col].Formula; //.Text;
    if IsOpenOffice then result:= ActiveSheet.getCellByPosition(col-1, row-1).getFormula;
  end;
end;

function TopofCalc.GetCellColor(row, col: integer): longint;
begin
  result:= 0;
  if DocLoaded then begin
    if IsExcel then      result:= ActiveSheet.Cells[row, col].Interior.ColorIndex;
    if IsOpenOffice then result:= ActiveSheet.getCellByPosition(col-1, row-1).CellBackColor;
  end;
end;

//установить значение

procedure  TopofCalc.SetCellText(row, col: integer; Txt: string);
begin
  if DocLoaded then begin
    if IsExcel then      ActiveSheet.Cells[row, col].Formula:= Txt;
    if IsOpenOffice then ActiveSheet.getCellByPosition(col-1, row-1).setFormula(Txt);
  end;
end;

//то же самое, но по имени €чейки.

//ќб€зательно указание номера листа

function TopofCalc.GetCellTextByName(Range: string): string;
var OldActiveSheet: variant;
begin
  if DocLoaded then begin
    if IsExcel then begin
      result:=  Programa.Range[Range].Text; //Set 'Formula' but Get 'Text';
    end;
    if IsOpenOffice then begin
      OldActiveSheet:= ActiveSheet;
      //If range is in the form 'NewSheet!A1' then first change sheet to 'NewSheet'
      if pos('!', Range) > 0 then begin
        //Activate the proper sheet...
        if not ActivateSheetByName(Copy(Range, 1, pos('!', Range)-1), false) then
          raise exception.create('Sheet "'+Copy(Range, 1, pos('!', Range)-1)+
                                 '" not present in the document.');
        Range:= Copy(Range, pos('!', Range)+1, 999);
      end;
      result:= ActiveSheet.getCellRangeByName(Range).getCellByPosition(0,0).getFormula;
      ActiveSheet:= OldActiveSheet;
    end;
  end;
end;

procedure  TopofCalc.SetCellTextByName(Range: string; Txt: string);
var OldActiveSheet: variant;
begin
  if DocLoaded then begin
    if IsExcel then begin
      Programa.Range[Range].formula:= Txt;
    end;
    if IsOpenOffice then begin
      OldActiveSheet:= ActiveSheet;
      //If range is in the form 'NewSheet!A1' then first change sheet to 'NewSheet'
      if pos('!', Range) > 0 then begin
        //Activate the proper sheet...
        if not ActivateSheetByName(Copy(Range, 1, pos('!', Range)-1), false) then
          raise exception.create('Sheet "'+Copy(Range, 1, pos('!', Range)-1)+
                                 '" not present in the document.');
        Range:= Copy(Range, pos('!', Range)+1, 999);
      end;
      ActiveSheet.getCellRangeByName(Range).getCellByPosition(0,0).SetFormula(Txt);
      ActiveSheet:= OldActiveSheet;
    end;
  end;
end;

//а так же Ц размера шрифта. ћожно установить его в шаблоне, а можно пр€мо в ходе работы программы.

procedure TopofCalc.FontSize(row,col:integer;oosize:integer);
begin
  if DocLoaded then begin
    if IsExcel then begin
      Programa.ActiveSheet.Cells[row,col].Font.Size:=oosize;
    end;
    if IsOpenOffice then begin
      ActiveSheet.getCellByPosition(col-1, row-1).getText.createTextCursor.CharHeight:= oosize;
    end;
  end;
end;

//сделать шрифт жирным

procedure TopofCalc.Bold(row,col: integer);
const ooBold: integer = 150; //150 = com.sun.star.awt.FontWeight.BOLD
begin
  if DocLoaded then begin
    if IsExcel then begin
      Programa.ActiveSheet.Cells[row,col].Font.Bold;
    end;
    if IsOpenOffice then begin
      ActiveSheet.getCellByPosition(col-1, row-1).getText.createTextCursor.CharWeight:= ooBold;
    end;
  end;
end;

//изменить ширину столбца

procedure TopofCalc.ColumnWidth(col,  width: integer); //Width in 1/100 of mm.
begin
  if DocLoaded then begin
    if IsExcel then begin
      //Excel use the width of '0' as the unit, we do an aproximation: Width '0' = 2 mm.
      Programa.ActiveSheet.Cells[col, 1].ColumnWidth:= width/100/3;
    end;
    if IsOpenOffice then begin
      ActiveSheet.getCellByPosition(col-1, 0).getColumns.getByIndex(0).Width:= width;
    end;
  end;
end;

//в заключение, предлагаю функции, предназначенные именно дл€ OpenOffice

//преобразование имени

//Change 'C:\File.txt' into 'file:///c:/File.txt' (for OpenOffice OpenURL)
function TopofCalc.FileNameToURL(FileName: string): string;
begin
  result:= '';
  if LowerCase(copy(FileName,1,8))<>'file:///' then
    result:= 'file:///';
  result:= result + StringReplace(FileName, '\', '/', [rfReplaceAll, rfIgnoreCase]);
end;

//создание объекта

function TopofCalc.ooCreateValue(ooName: string; ooData: variant): variant;
var
  ooReflection: variant;
begin
  if IsOpenOffice then begin
    ooReflection:= Programa.createInstance('com.sun.star.reflection.CoreReflection');
    ooReflection.forName('com.sun.star.beans.PropertyValue').createObject(result);
    result.Name := ooName;
    result.Value:= ooData;
  end else begin
    raise exception.create('ooValue imposible to create, load OpenOffice first!');
  end;
end;

//запуск диспатчера

procedure TopofCalc.ooDispatch(ooCommand: string; ooParams: variant);
var
  ooDispatcher, ooFrame: variant;
begin
  if DocLoaded and IsOpenOffice then begin
    if (VarIsEmpty(ooParams) or VarIsNull(ooParams)) then
      ooParams:= VarArrayCreate([0, -1], varVariant);
    ooFrame:= Document.getCurrentController.getFrame;
    ooDispatcher:= Programa.createInstance('com.sun.star.frame.DispatchHelper');
    ooDispatcher.executeDispatch(ooFrame, ooCommand, '', 0, ooParams);
  end else begin
    raise exception.create('Dispatch imposible, load a OpenOffice doc first!');
  end;
end;

end.

