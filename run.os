#use json
var gSet;
var ver;
procedure getSettings()
	var setFile;
	setFile = new File("auth.me");
	If Not setFile.Exists() Then
		ВызватьИсключение """auth.me"" not found";
	EndIf;
	джон = Новый ПарсерJSON;
	gSet = new Structure("server1c, ib1c, user1c, passwd1c, myHost, myUser, myPwd, myBase");
	ОбъектДж = джон.ПрочитатьJSON(Новый ЧтениеТекста("auth.me").Прочитать());
	Для Каждого нн Из gSet Цикл
		gSet[нн.Ключ] = ОбъектДж[нн.Ключ];
	КонецЦикла;

//	FillPropertyValues(gSet, ОбъектДж);
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
	Message("- create comconnector");
	com = New ComObject("V83.ComConnector");
	Message("- authorize against IB mc_bnu");
	connStr = "Srvr="""+gSet["server1c"]+""";Ref="""+gSet["ib1c"]+""";Usr="""+gSet["user1c"]+""";Pwd="""+gSet["passwd1c"]+""";";

	Попытка
		conn = com.Connect(connStr);
	Исключение
		Message("Не удалось соединиться с ИБ "+gSet["server1c"]+"\"+gSet["ib1c"]+""+Символы.ПС+ОписаниеОшибки());
		exit(2);
	КонецПопытки;
	Message("- querying data from IB");

	q = conn.newObject("Запрос");
	q.text = queryText;
	res = q.Execute().Выбрать();

	Message("- create mysql object");

	myConnect 	= new ComObject("ADODB.Connection");

	Message("- connect to mysql");

	myConnect.Open("DRIVER=MySQL ODBC 5.3 ANSI Driver;Server="+gSet["myHost"]+";Database="+gSet["myBase"]+";UID="+gSet["myUser"]+";PWD="+gSet["myPwd"]+";OPTION=3");

	myCMD		= new ComObject("ADODB.Command");
	myCMD.ActiveConnection = myConnect;
	myCMD.CommandText = "DELETE from phoneList";
	myCMD.Execute();

	Message("- data processing");

	While res.Next() do
		q = "INSERT INTO `phoneList` (
			|`phone`, `type`, `cntr`, `face`
			|)VALUES (
			|'"+res.Телефон+"', '"+res.ВидКИ+"', '"+СокрЛ(res.Контрагент)+"', '"+res.ОбъектКИ+"');";
		myCMD.CommandText = q;
		Попытка
			myCMD.Execute();
		Исключение
			Message(q);
			err = ErrorInfo();
			Message(getErrorFullDescription(err));
			exit(4);
		КонецПопытки;
	EndDo;
endfunction

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

//--------------------------------------------------------------
ver = "1.0.2 2015@VSCraft";
Message("*** Start : "+CurrentDate());
run();
Message("*** Finish: "+CurrentDate());




