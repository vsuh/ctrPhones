// todo: завести таблицу dateDone в которую писать дату начала и завершения загрузки
// OK!todo: сделать форрмирование файла auth.me при его отсутствии со значениями по-умолчанию
// todo: сделать создание ком объектов в попытке с выходом с разными rc при неудаче
// todo: открытие\соединение сделать в попытке с разными rc при неудаче
#use json
var gSet;
var ver;
var l_id;
var myObj;
var myCMD;

procedure getSettings()
	var setFile;
	setFile = new File("auth.me");

	jsonObj = Новый ПарсерJSON;
	gSet = new Structure("com1cModel, server1c, ib1c, user1c, passwd1c, myHost, myUser, myPwd, myBase, myDriver",
	"V83.ComConnector", "srv-1", "base1C_upp", "админ", "пароль", "192.168.1.1", "MYUSER", "MYPWD", "MYBASE", "{MySQL ODBC 3.51 Driver}");
	If Not setFile.Exists() Then
		try
			strJSN = jsonObj.ЗаписатьJSON(gSet);
			txtCft = Новый ЗаписьТекста(setFile.ПолноеИмя);
			txtCft.Записать(strJSN);
			txtCft.Закрыть();
			Message("Не найден конфигурационный файл. Создан пустой новый "+setFile.ПолноеИмя);
			exit(3);
		exception
			ТекстОшибки = ИнформацияОбОшибке().Описание;
			Message(ТекстОшибки);
			exit(5);
		endtry;
	else
		ОбъектДж = jsonObj.ПрочитатьJSON(Новый ЧтениеТекста("auth.me").Прочитать());
		Для Каждого нн Из gSet Цикл
			gSet[нн.Ключ] = ОбъектДж[нн.Ключ];
		КонецЦикла;
	endIf;

endprocedure

function run()
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
	setDateStamp(true);

	Message("- create comconnector");
	com = New ComObject(gSet["com1cModel"]);
	Message("- authorize against IB mc_bnu");
	connStr = "Srvr="""+gSet["server1c"]+""";Ref="""+gSet["ib1c"]+""";Usr="""+gSet["user1c"]+""";Pwd="""+gSet["passwd1c"]+""";";

	try
		conn = com.Connect(connStr);
	exception
		Message("Не удалось соединиться с ИБ "+gSet["server1c"]+"\"+gSet["ib1c"]+""+Символы.ПС+ОписаниеОшибки());
		exit(2);
	endtry;
	Message("- querying data from IB");

	q = conn.newObject("Запрос");
	q.text = queryText;
	res = q.Execute().Выбрать();


	myCMD.CommandText = "DELETE from phoneList";
	myCMD.Execute();

	exit(11);
	Message("- data processing");

	While res.Next() do
		q = "INSERT INTO `phoneList` (
			|`phone`, `type`, `cntr`, `face`
			|)VALUES (
			|'"+res.Телефон+"', '"+res.ВидКИ+"', '"+СокрЛ(res.Контрагент)+"', '"+res.ОбъектКИ+"');";
		myCMD.CommandText = q;
		try
			myCMD.Execute();
		except
			Message(q);
			err = ErrorInfo();
			Message(getErrorFullDescription(err));
			exit(4);
		endtry;
	EndDo;
	setDateStamp(false);

endfunction

procedure setDateStamp(beg = true)
	getMyConnection();
	q = "";
	myCMD.CommandText = q;
	rs = myCMD.Execute();
	Message(rs[0]["tm_id"]);
endprocedure

function getErrorFullDescription(Ош)
	ТекстОшибки="";
	Пока Ош <> Неопределено Цикл
		Если Ош.Причина <> Неопределено Тогда
			ТекстОшибки = ТекстОшибки +" // стр. "+Ош.ИсходнаяСтрока+" : // "+ Ош.Причина.Описание;
		КонецЕсли;
		Ош = Ош.Причина;
	КонецЦикла;
	Возврат ТекстОшибки;
endfunction

procedure getMyConnection()
	if myCMD <> undefined then
		return;
	endif;

	myObj 	= new ComObject("ADODB.Connection");

	Message("- connect to mysql");
	myConnStr = "DRIVER="+gSet["myDriver"]+";Server="+gSet["myHost"]+";Database="+gSet["myBase"]+";UID="+gSet["myUser"]+";PWD="+gSet["myPwd"]+";OPTION=3";
	try
		myObj.Open(myConnStr);
	exception
		Message("conn str: "+myConnStr);
		err = ErrorInfo();
		Message(getErrorFullDescription(err));
		exit(6);
	endtry;
	myCMD		= new ComObject("ADODB.Command");
	myCMD.ActiveConnection = myObj;

endprocedure
//--------------------------------------------------------------
ver = "1.0.3 2015@VSCraft";
Message("*** Start : "+CurrentDate());
run();
Message("*** Finish: "+CurrentDate());




