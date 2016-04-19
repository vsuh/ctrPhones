// *** Загрузка РС:КонтактнаяИнформация в mysql таблицу
//
// OK!todo: завести таблицу dateDone в которую писать дату начала и завершения загрузки [procedure setDateStamp]
// OK!todo: сделать форрмирование файла auth.me при его отсутствии со значениями по-умолчанию
// OK!todo: сделать создание ком объектов в попытке с выходом с разными rc при неудаче
// OK!todo: открытие\соединение сделать в попытке с разными rc при неудаче
// OK!todo: сделать парсер ошибок выполнения в tasks.json
// OK!todo: сделать загрузку в таблицу по несколько записей за операцию
#use json
var gSet;
var ver;
var myCMD;
var tbeg;
var packetSize;

procedure getSettings()
	var setFile;
	setFile = new File("auth.me");

	jsonObj = new ПарсерJSON;
	gSet = new Structure("com1cModel, server1c, ib1c, user1c, passwd1c, myHost, myUser, myPwd, myBase, myDriver, myCharset",
	"V83.ComConnector", "srv-1", "base1C_upp", "админ", "пароль", "192.168.1.1", "MYUSER", "MYPWD", "MYBASE", "{MySQL ODBC 3.51 Driver}", "utf8");
	if Not setFile.Exists() then
		try
			strJSN = jsonObj.ЗаписатьJSON(gSet);
			txtCft = new TextWriter(setFile.FullName);
			txtCft.Записать(strJSN);
			txtCft.Закрыть();
			Message("Не найден конфигурационный файл. Создан пустой новый "+setFile.FullName);
			exit(1);
		except
	        err = ErrorInfo();
    		Message(getErrorFullDescription(err));
			exit(2);
		endtry;
	else
		ОбъектДж = jsonObj.ПрочитатьJSON(new TextReader("auth.me").Read());
		For each kk in gSet do
			gSet[kk.Key] = ОбъектДж[kk.Key];
		EndDo;
	endIf;
endprocedure

function run()
    var cut_tbl;
    cut_tbl = true;
    iq = 0;
    tbeg = CurrentDate();
    packetSize = 100;
    getSettings();
	queryText = "ВЫБРАТЬ
	|	ПредставлениеСсылки(ки.Объект) КАК ОбъектКИ,
	|	ВЫБОР
	|		КОГДА ТИПЗНАЧЕНИЯ(ки.Объект) = ТИП(Справочник.Контрагенты)
	|			ТОГДА ПредставлениеСсылки(ки.Объект)
	|		КОГДА ТИПЗНАЧЕНИЯ(ки.Объект) = ТИП(Справочник.КонтактныеЛицаКонтрагентов)
	|			ТОГДА ПредставлениеСсылки(ки.Объект.Владелец)
	|		КОГДА ТИПЗНАЧЕНИЯ(ки.Объект) = ТИП(Справочник.ФизическиеЛица)
	|			ТОГДА ПредставлениеСсылки(ки.Объект)
	|		КОГДА ТИПЗНАЧЕНИЯ(ки.Объект) = ТИП(Справочник.Организации)
	|			ТОГДА ки.Объект.НаименованиеСокращенное
	|		ИНАЧЕ ""---""
	|	КОНЕЦ КАК Контрагент,
	|	ПредставлениеСсылки(ки.Вид) КАК ВидКИ,
	|	ки.Представление КАК Телефон
	|ИЗ
	|	РегистрСведений.КонтактнаяИнформация КАК ки
	|ГДЕ
	|	ки.Тип = Значение(Перечисление.ТипыКонтактнойИнформации.Телефон) И ки.Объект <> НЕОПРЕДЕЛЕНО
	|
	|";

	Message("- create mysql object "+gSet["myDriver"]);
	getMyConnection();
	setDateStamp(cut_tbl, false);

	Message("- create comconnector");
	com = New ComObject(gSet["com1cModel"]);
	Message("- authorize against IB "+gSet["ib1c"]);
	connStr = "Srvr="""+gSet["server1c"]+""";Ref="""+gSet["ib1c"]+""";Usr="""+gSet["user1c"]+""";Pwd="""+gSet["passwd1c"]+""";";

	try
		conn = com.Connect(connStr);
	except
		Message("Не удалось соединиться с ИБ "+gSet["server1c"]+"\"+gSet["ib1c"]+""+Символы.ПС+ОписаниеОшибки());
   		err = ErrorInfo();
		Message(getErrorFullDescription(err));
		exit(3);
	endtry;
	Message("- querying data from IB "+gSet["ib1c"]);

	q = conn.newObject("Запрос");
	q.text = queryText;
	res = q.Execute().Выбрать();


	myCMD.CommandText = "truncate table `phoneList`;";
	try
		myCMD.Execute();
	except
		Message(myCMD.CommandText);
		err = ErrorInfo();
		Message(getErrorFullDescription(err));
		exit(4);
	endtry;

	Message("- data processing ("+res.Count()+" recs.)");
    while true do
    	q = "INSERT INTO `phoneList` (`phone`, `type`, `cntr`, `face`) VALUES ";
        d = "";
        for i = 1 to packetSize do
            if res.Next() then
                d = d + "
                | ('" + res.Телефон + "', '" +res.ВидКИ+"', '"+triml(res.Контрагент)+"', '"+res.ОбъектКИ+"'),";
            endif;
        enddo;
        if IsBlankString(d) then break; endif;
        d = Left(d, StrLen(d) - 1);
        iq = iq + 1;

   		myCMD.CommandText = q+d;
			try
				myCMD.Execute();
			except
				Message(q);
				err = ErrorInfo();
				Message(getErrorFullDescription(err));
				exit(5);
			endtry;
    enddo;
	setDateStamp(cut_tbl, true);

endfunction

procedure setDateStamp(cut = true, reg = false)
	getMyConnection();
    if cut and not reg then
    q = "TRUNCATE table `loads_time`";
        myCMD.CommandText = q;
        try
            myCMD.Execute();
        except
			Message("ERROR:: "+myCMD.CommandText);
			err = ErrorInfo();
			Message(getErrorFullDescription(err));
			exit(6);
        endtry;
    endif;
    if reg then
			duration = Round(CurrentDate() - tbeg, 3);
					q = "insert into `loads_time` (`exec_time`, `duration`, `success`
					|  ) VALUES (
					|  '" + Format(ТекущаяДата(), "ДФ='yyyy-MM-dd HH:mm:ss'") + "', " + duration + ", " + packetSize + ");";
									myCMD.CommandText = q;
			try
				myCMD.Execute();
			except
				Message("ERROR:: "+q);
				err = ErrorInfo();
				Message(getErrorFullDescription(err));
				exit(7);
			endtry;

    else
    endif;
endprocedure

function getErrorFullDescription(Err)
	ErrorText="";
	while Err <> undefined do
		if Err.Cause <> undefined then
			ErrorText = ErrorText +"{#"+Err.ModuleName+" ["+Err.LineNumber+"] "+" / "+ Err.Cause.Description +"#}"+Err.SourceLine;
		endif;
		Err = Err.Cause;
	enddo;
	return ErrorText;
endfunction

procedure getMyConnection()
	if myCMD <> undefined then
		return;
	endif;

	myObj 	= new ComObject("ADODB.Connection");

	Message("- connect to mysql ("+gSet["myBase"]+"\"+gSet["myHost"]+")");
	myConnStr = "DRIVER="+gSet["myDriver"]+";Server="+gSet["myHost"]+";Database="
            + gSet["myBase"]+";UID="+gSet["myUser"]+";PWD="+gSet["myPwd"]
            + ";OPTION=3;charset="+gSet["myCharset"]+";";
	try
		myObj.Open(myConnStr);
	except
		Message("conn str: " + myConnStr);
		err = ErrorInfo();
		Message(getErrorFullDescription(err));
		exit(8);
	endtry;
	myCMD = new ComObject("ADODB.Command");
	myCMD.ActiveConnection = myObj;
endprocedure
//--------------------------------------------------------------
ver = "1.1.6 2015@VSCraft";

Message("*** Start : "+CurrentDate());
run();
Message("*** Finish: "+CurrentDate());




