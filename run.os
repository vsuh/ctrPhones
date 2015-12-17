function run()

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
Message("create comconnector");
	com = New ComObject("V83.ComConnector");
Message("authorize against IB mc_bnu");
	Попытка
		conn = com.Connect("Srvr=kopt-app-01;Ref=mc_bnu;Usr=admin;Pwd=kzueirf;");
	Исключение
		Message("Не удалось соединиться с ИБ ""kopt-app-01\mc_bnu"""+Символы.ПС+ОписаниеОшибки());
		exit(2);
	КонецПопытки;
Message("querying data from IB");

	q = conn.newObject("Запрос");
	q.text = queryText;
	res = q.Execute().Выбрать();

Message("create mysql object");

	myConnect 	= new ComObject("ADODB.Connection");

Message("connect to mysql");

	myConnect.Open("DRIVER=MySQL ODBC 5.3 ANSI Driver;Server=mysql;Database=cntrPhones;UID=asterix;PWD=1978Lollipop;OPTION=3");

	myCMD		= new ComObject("ADODB.Command");
	myCMD.ActiveConnection = myConnect;
	myCMD.CommandText = "DELETE from phoneList";
	myCMD.Execute();

Message("data processing");

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
Message("*** Start : "+CurrentDate());
run();
Message("*** Finish: "+CurrentDate());
