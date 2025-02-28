// askin(c)
//
// Параметры скрипта:
// Первый параметр - наименования файла настроек
// Второй - команда.


// Команды:
// без команды  - ничего
// lock 					- только блокировка
// unlock 					- только разблокировка
// restart      			- только перезагрузка сервера
// updateFromStorage 		- только обновление из хранилищ
// updateDB 				- обновление конфигурации базы
// batch       				- пакетный режим, команды и их очередность прописывается в файле настроек




// BSLLS-off
#Область ОписаниеПеременных

#Использовать v8runner
#Использовать configor
#Использовать irac
#Использовать 1commands
#Использовать asserts
#Использовать fs
#Использовать cmdline

Перем Лог;
Перем МенеджерПараметров;
Перем МассивОбслуживаемыхБаз;
Перем ИмяСервераRAS;
Перем ПроцессRAS;
Перем МассивОшибок;
Перем ЭтоWindows;

#КонецОбласти



#Область ПрограммныйИнтерфейс

Функция ИнициализацияОкружения()
	
	// значение по умолчанию
	ФайлНастроек = "tests.yml";
	КомандаСкрипта = "";
	МассивОшибок = Новый Массив;

	СистемнаяИнформация = Новый СистемнаяИнформация;
	ЭтоWindows = Найти(НРег(СистемнаяИнформация.ВерсияОС), "windows") > 0;

	Лог = Логирование.ПолучитьЛог("oscript.app.serv");
	Лог.УстановитьРаскладку(ЭтотОбъект);
	
	ЛогВыводВФайл = Новый ВыводЛогаВФайл; //аппендер обычного лога
	ЛогВыводВФайл.ОткрытьФайл("svc1c.log");
	Лог.ДобавитьСпособВывода(ЛогВыводВФайл, УровниЛога.Информация);
	
	Если АргументыКоманднойСтроки.Количество() > 0 Тогда
		ФайлНастроек = ОбъединитьПути(ТекущийКаталог(), АргументыКоманднойСтроки[0]);
		Если АргументыКоманднойСтроки.Количество() > 1 Тогда
			КомандаСкрипта = АргументыКоманднойСтроки[1];
		КонецЕсли;
	КонецЕсли;
	
	Если ФайлНастроек = "" Тогда
		ДобавитьОшибку("Не найден файл параметров", Истина);
	КонецЕсли;
	
	МенеджерПараметров = Новый МенеджерПараметров();
	МенеджерПараметров.АвтоНастройка(ФайлНастроек);
	МенеджерПараметров.ИспользоватьПровайдерYAML(0);
	МенеджерПараметров.УстановитьФайлПараметров(ФайлНастроек);
	МенеджерПараметров.Прочитать();
	Если НЕ МенеджерПараметров.ЧтениеВыполнено() Тогда
		Лог.Информация("Количество аргументов: " + АргументыКоманднойСтроки.Количество());
		Лог.Информация("Файл настроек: " + ФайлНастроек);
		Лог.Информация("Команда скрипта: " + КомандаСкрипта);
		ДобавитьОшибку("Не удалось прочитать настройки!", Истина);
	КонецЕсли;
	
	Если МенеджерПараметров.Параметр("debug") Тогда
		ФайлДляЛогаОтладки = Новый ВыводЛогаВФайл;
		ФайлДляЛогаОтладки.ОткрытьФайл("svc1c_debug.log");
		Лог.ДобавитьСпособВывода(ФайлДляЛогаОтладки, УровниЛога.Отладка);
		Лог.УстановитьУровень(УровниЛога.Отладка);
	КонецЕсли;

	ИмяСервераRAS = МенеджерПараметров.Параметр("serverRAS.serverRAS") + ":"
		+ МенеджерПараметров.Параметр("serverRAS.portRAS");
	
	Если НуженЗапускRAS() Тогда
		ЗапуститьRAS();
	КонецЕсли;
	
	МассивОбслуживаемыхБаз = МассивОбслуживаемыхБаз();
	
	Возврат КомандаСкрипта;
	
КонецФункции

Функция ПолучениеСоединенийСКластером(ТестированиеПодключения = Ложь)
	
	Результат = Истина;

	Попытка
		
		АдминистраторКластера1С = МенеджерПараметров.Параметр("server1c.clusterAdmin");
		ПарольКластера1С = МенеджерПараметров.Параметр("server1c.clusterAdminPassword");
		Админ = Новый Структура("Администратор, Пароль", АдминистраторКластера1С, ПарольКластера1С);

		АгентКластера = Новый УправлениеКластером1С("8.3", ИмяСервераRAS, Админ);
		АгентКластера.УстановитьИсполнительКоманд(Новый ИсполнительКоманд("8.3"));

		СписокКластеров = Новый Кластеры(АгентКластера);
		СписокКластеров.ОбновитьДанные(1);

		Кластер = СписокКластеров.Список()[0];

	Исключение

		Если НЕ ТестированиеПодключения Тогда
			Результат = НЕ ДобавитьОшибку("Ошибка подключения к кластеру: (" + ОписаниеОшибки() + ")");
		КонецЕсли;

	КонецПопытки;
	
	Возврат Новый Структура("Результат,Кластер", Результат, Кластер);
	
КонецФункции

Функция УдалениеСеансовСКонфигуратором(Знач СписокБаз)

	ЕстьОшибки = Ложь;

	РезультатПодключения = ПолучениеСоединенийСКластером();
	Если РезультатПодключения.Результат Тогда
		ТекущийКластер = РезультатПодключения.Кластер;
	Иначе
		Возврат Ложь;
	КонецЕсли;

	Для Каждого ИмяТекущейБазы Из СписокБаз Цикл

		ИнформационнаяБаза = ПараметрыСоединенияСИнформационнойБазой(ИмяТекущейБазы,ТекущийКластер);
		ИдТекущейБазы = ИнформационнаяБаза.Получить("infobase");
		Сеансы = ТекущийКластер.Сеансы();
		Для Каждого Сеанс Из Сеансы.Список() Цикл
			Параметры = Сеанс.ПараметрыОбъекта();
			Приложение = Сеанс.Получить("Приложение");
			БазаДанныхСеанса = Сеанс.Получить("infobase");
			Если Приложение = "Designer" И БазаДанныхСеанса = ИдТекущейБазы Тогда
				Попытка
					Сеанс.Завершить();
				Исключение
					ЕстьОшибки = ДобавитьОшибку(ОписаниеОшибки());		
				КонецПопытки;					
			КонецЕсли;
		КонецЦикла;
		
	КонецЦикла;
	
	Возврат НЕ ЕстьОшибки;

КонецФункции

Функция УдалениеВсехСеансов(Знач СписокБаз)
	
	ЕстьОшибки = Ложь;

	РезультатПодключения = ПолучениеСоединенийСКластером();
	Если РезультатПодключения.Результат Тогда
		ТекущийКластер = РезультатПодключения.Кластер;
	Иначе
		Возврат Ложь;
	КонецЕсли;

	Для Каждого ИмяТекущейБазы Из СписокБаз Цикл
		Сеансы = ТекущийКластер.Сеансы();
		Для Каждого Сеанс Из Сеансы.Список() Цикл
			Попытка
				Сеанс.Завершить();
			Исключение
				ЕстьОшибки = ДобавитьОшибку(ОписаниеОшибки());		
			КонецПопытки;			
		КонецЦикла;
		Лог.Информация("Разорваны сеансы с базой " + ИмяТекущейБазы);
	КонецЦикла;
	
	Возврат НЕ ЕстьОшибки;

КонецФункции

Функция БлокировкаНаБазы(Знач СписокБаз, Установить = Ложь)
	
	ЕстьОшибки = Ложь;

	Если Установить Тогда
		ПереключательСостояния = Перечисления.СостоянияВыключателя.Включено;
	Иначе
		ПереключательСостояния = Перечисления.СостоянияВыключателя.Выключено;
	КонецЕсли;
	
	РезультатПодключения = ПолучениеСоединенийСКластером();
	Если РезультатПодключения.Результат Тогда
		ТекущийКластер = РезультатПодключения.Кластер;
	Иначе
		Возврат Ложь;
	КонецЕсли;

	Для Каждого ИмяТекущейБазы Из СписокБаз Цикл
		
		ИнформационнаяБаза = ПараметрыСоединенияСИнформационнойБазой(ИмяТекущейБазы,ТекущийКластер);	
		ПараметрыИБ = Новый Структура();		
		НачалоБлокировкиСеансов = ТекущаяДата();
		ОкончаниеБлокировкиСеансов = НачалоБлокировкиСеансов + Число(МенеджерПараметров.Параметр("server1c.lockTime"));	
		ПараметрыИБ.Вставить("НачалоБлокировкиСеансов", НачалоБлокировкиСеансов);
		ПараметрыИБ.Вставить("ОкончаниеБлокировкиСеансов", ОкончаниеБлокировкиСеансов);
		ПараметрыИБ.Вставить("СообщениеБлокировкиСеансов", "Технические работы");
		ПараметрыИБ.Вставить("КодРазрешения", МенеджерПараметров.Параметр("server1c.bases." + ИмяТекущейБазы + ".allowKey"));
		ПараметрыИБ.Вставить("БлокировкаСеансовВключена", ПереключательСостояния);
		ПараметрыИБ.Вставить("БлокировкаРегламентныхЗаданийВключена", ПереключательСостояния);

		Попытка
			ИнформационнаяБаза.Изменить(ПараметрыИБ);
		Исключение
			ЕстьОшибки = ДобавитьОшибку(ОписаниеОшибки());		
		КонецПопытки;
		
		Если Установить Тогда
			Лог.Информация("Заблокирована база:" + ИмяТекущейБазы);
		Иначе
			Лог.Информация("Разблокированна база:" + ИмяТекущейБазы);
		КонецЕсли;
		
	КонецЦикла;
	
	Возврат НЕ ЕстьОшибки;

КонецФункции

Функция ОбновлениеКонфигурацииИзХранилища(База, Конфигуратор = Неопределено)
	
	ЕстьОшибки = Ложь;

	Если Конфигуратор = Неопределено Тогда
		Конфигуратор = ПараметрыКонфигуратора(База);
	КонецЕсли;

	СтрокаХранилищ = "server1c.bases." + База + ".1cstorages";
	Для Каждого Хранилище Из МенеджерПараметров.Параметр(СтрокаХранилищ) Цикл
		ИмяОбъектаХранилища = Хранилище.Ключ;
		ИмяРасширения = МенеджерПараметров.Параметр(СтрокаХранилищ + "." + ИмяОбъектаХранилища + ".name","");
		Попытка

			Если ИмяРасширения = "" Тогда
				Лог.Информация("Запуск обновления основной конфигурации из хранилища");
				
				Лог.Отладка("Путь к хранилищу: " + МенеджерПараметров.Параметр(СтрокаХранилищ + "." + ИмяОбъектаХранилища + ".path"));
				Лог.Отладка("Пользователь хранилища: " + МенеджерПараметров.Параметр(СтрокаХранилищ + "." + ИмяОбъектаХранилища + ".user"));
				Лог.Отладка("Пароль хранилища: " + МенеджерПараметров.Параметр(СтрокаХранилищ + "." + ИмяОбъектаХранилища + ".pass"));
				
				Конфигуратор.ЗагрузитьКонфигурациюИзХранилища(МенеджерПараметров.Параметр(СтрокаХранилищ + "." + ИмяОбъектаХранилища + ".path"),
					МенеджерПараметров.Параметр(СтрокаХранилищ + "." + ИмяОбъектаХранилища + ".user"),
					МенеджерПараметров.Параметр(СтрокаХранилищ + "." + ИмяОбъектаХранилища + ".pass"));
				
				Лог.Информация("Основная конфигурация обновлена из хранилища");

			Иначе
				
				Лог.Информация("Запуск обновления расширения " + ИмяРасширения + " из хранилища");
				
				Лог.Отладка("Путь к хранилищу расширения: " + МенеджерПараметров.Параметр(СтрокаХранилищ + "." + ИмяОбъектаХранилища + ".path"));
				Лог.Отладка("Пользователь хранилища расширения: " + МенеджерПараметров.Параметр(СтрокаХранилищ + "." + ИмяОбъектаХранилища + ".user"));
				Лог.Отладка("Пароль хранилища расширения: " + МенеджерПараметров.Параметр(СтрокаХранилищ + "." + ИмяОбъектаХранилища + ".pass"));
				
				Конфигуратор.РасширениеПолучитьИзХранилища(МенеджерПараметров.Параметр(СтрокаХранилищ + "." + ИмяОбъектаХранилища + ".path"),
					МенеджерПараметров.Параметр(СтрокаХранилищ + "." + ИмяОбъектаХранилища + ".user"),
					МенеджерПараметров.Параметр(СтрокаХранилищ + "." + ИмяОбъектаХранилища + ".pass"),
					ИмяРасширения, 0);
				Лог.Информация("Расширение " + ИмяРасширения + " обновлено из хранилища");

			КонецЕсли;

		Исключение

			ЕстьОшибки = ДобавитьОшибку(СтрШаблон(НСтр("ru = 'Ошибка при получении изменений из хранилища расширения
			|%1'"), Конфигуратор.ВыводКоманды()));			

		КонецПопытки;
	КонецЦикла;
	
	ОчиститьМусор();

	Возврат НЕ ЕстьОшибки;

КонецФункции

Функция ОбновлениеКонфигурации(База, Конфигуратор = Неопределено)
	
	Если Конфигуратор = Неопределено Тогда
		Конфигуратор = ПараметрыКонфигуратора(База);
	КонецЕсли;
	
	ЕстьОшибки = Истина;

	СтрокаХранилищ = "server1c.bases." + База + ".1cstorages";
	Для Каждого Хранилище Из МенеджерПараметров.Параметр(СтрокаХранилищ) Цикл
		
		ИмяРасширения = МенеджерПараметров.Параметр(СтрокаХранилищ + "." + Хранилище.Ключ + ".name","");
		Попытка
			
			Если ИмяРасширения = "" Тогда
				Лог.Информация("Запуск обновления основной конфигурации базы");
				Конфигуратор.ОбновитьКонфигурациюБазыДанных();
				Лог.Информация("Обновление основной конфигурации базы завершено");
			Иначе
				Лог.Информация("Запуск обновления расширения базы: " + ИмяРасширения);
				Конфигуратор.ОбновитьКонфигурациюБазыДанных( , , , ИмяРасширения);
				Лог.Информация("Обновление расширения " + ИмяРасширения + " завершено");
			КонецЕсли;

		Исключение
		
			ЕстьОшибки = ДобавитьОшибку(СтрШаблон(НСтр("ru = 'Ошибка при обновлении
			|%1'"), Конфигуратор.ВыводКоманды()));				
		
		КонецПопытки;
	
	КонецЦикла;
	ОчиститьМусор();

	Возврат НЕ ЕстьОшибки;

КонецФункции

Процедура ПерезапускСервера()
	
	КомандныйФайл = Новый КомандныйФайл;
	КомандныйФайл.Создать();
	
	Лог.Отладка("-----Скрипт bat-------");
	Лог.Информация("Перезапуск серверных служб 1С");
	
	КомандныйФайл.ДобавитьКоманду("@SC STOP """ + МенеджерПараметров.Параметр("server1c.1cDemonName") + "");
	Если МенеджерПараметров.Параметр("serverRAS.RestartRas") Тогда
		КомандныйФайл.ДобавитьКоманду("@SC STOP """ + МенеджерПараметров.Параметр("server1c.1cRasDemonName") + "");
	КонецЕсли;

	Лог.Отладка("Пауза 2 секунды");
	КомандныйФайл.ДобавитьКоманду("@start /wait timeout 2");
	Лог.Отладка("Убийство неуспевших завершиться процессов");
	КомандныйФайл.ДобавитьКоманду("@TASKKILL /F /IM RPHOST.EXE");
	КомандныйФайл.ДобавитьКоманду("@TASKKILL /F /IM RMNGR.EXE");
	КомандныйФайл.ДобавитьКоманду("@TASKKILL /F /IM RAGENT.EXE");
	Если МенеджерПараметров.Параметр("serverRAS.RestartRas") Тогда
		КомандныйФайл.ДобавитьКоманду("@TASKKILL /F /IM RAS.EXE");
	КонецЕсли;

	Лог.Информация("Очистка каталога сеансовых данных сервера 1с");
	КомандныйФайл.ДобавитьКоманду("@DEL /Q /F /S " + МенеджерПараметров.Параметр("server1c.Path1cService") + "\SNCCNTX*");
	КомандныйФайл.ДобавитьКоманду("@DEL /Q /F /S " + МенеджерПараметров.Параметр("server1c.Path1cService") + "\STT*");
	
	Лог.Отладка("Запуск служб");
	КомандныйФайл.ДобавитьКоманду("@SC START """ + МенеджерПараметров.Параметр("server1c.1cDemonName") + "");
	Если МенеджерПараметров.Параметр("serverRAS.RestartRas") Тогда
	  КомандныйФайл.ДобавитьКоманду("@SC START """ + МенеджерПараметров.Параметр("server1c.1cRasDemonName") + "");
	КонецЕсли;
	КомандныйФайл.ДобавитьКоманду("@start /wait timeout 5");
	
	КодВозврата = КомандныйФайл.Исполнить();
	ЭхоБатФайла = КомандныйФайл.ПолучитьВывод();
	Лог.Отладка("Код возврата " + КодВозврата);
	
	Лог.Отладка("Лог bat-файла - начало");
	Лог.Отладка(ЭхоБатФайла);
	Лог.Отладка("Лог bat-файла - окончание");
	
	Лог.Информация("Перезапуск серверных служб завешен");
	
	Приостановить(1000 * 5);
	
	Лог.Информация("Тестовое подключение к кластеру после рестарта");
	ПолучениеСоединенийСКластером(Истина);
	Лог.Информация("Тестовое подключение к кластеру после рестарта завершено");
	
КонецПроцедуры

#КонецОбласти

#Область СлужебныеПроцедурыИФункции

Функция МассивОбслуживаемыхБаз()
	
	Результат = Новый Массив;
	Для Каждого База Из МенеджерПараметров.Параметр("server1c.bases") Цикл
		Результат.Добавить(База.Ключ);
	КонецЦикла;

	Возврат Результат;

КонецФункции

Функция СтрокаСоединенияКонфигуратора(База, Конфигуратор)
	
	ПараметрыСтрокиСоединения = Конфигуратор.ПараметрыСтрокиСоединения();
	ПараметрыСтрокиСоединения.Сервер = МенеджерПараметров.Параметр("server1c.server");
	ПараметрыСтрокиСоединения.Порт = МенеджерПараметров.Параметр("server1c.port");
	ПараметрыСтрокиСоединения.ИмяБазы = База;

	Возврат ПараметрыСтрокиСоединения;
	
КонецФункции

Функция ПараметрыСоединенияСИнформационнойБазой(ИмяТекущейБазы,ТекущийКластер)

	ИнформационнаяБаза = ТекущийКластер.ИнформационныеБазы().Получить(ИмяТекущейБазы);
	АдминистраторПользовательИБ = МенеджерПараметров.Параметр("server1c.bases." + ИмяТекущейБазы + ".user");
	ПарольАдминистратораИБ = МенеджерПараметров.Параметр("server1c.bases." + ИмяТекущейБазы + ".password");
	ИнформационнаяБаза.УстановитьАдминистратора(АдминистраторПользовательИБ, ПарольАдминистратораИБ);

	Возврат ИнформационнаяБаза;
	
КонецФункции

Функция ПараметрыКонфигуратора(База)
	
	Конфигуратор = Новый УправлениеКонфигуратором();
	Конфигуратор.ИспользоватьВерсиюПлатформы(МенеджерПараметров.Параметр("server1c.version"));
	ПараметрыСтрокиСоединения = СтрокаСоединенияКонфигуратора(База, Конфигуратор);
	Конфигуратор.УстановитьКонтекст(ПараметрыСтрокиСоединения,
		МенеджерПараметров.Параметр("server1c.bases." + База + ".user"),
		МенеджерПараметров.Параметр("server1c.bases." + База + ".password"));
	
	КлючРазрешенияЗапуска = МенеджерПараметров.Параметр("server1c.bases." + База + ".allowKey");
	Конфигуратор.УстановитьКлючРазрешенияЗапуска(КлючРазрешенияЗапуска);
	
	ФайлПлатформы = ОбъединитьПути(ТекущийКаталог(), "logV8.log");
	Конфигуратор.УстановитьИмяФайлаСообщенийПлатформы(ФайлПлатформы);
	Возврат Конфигуратор;
	
КонецФункции

// Запущен
//		Проверяет запущен ли процесс сервера RAS
// Возвращаемое значение:
//   Булево - Истина - если процесс запущен, Ложь - в остальных случаях
//
Функция ЗапущенRAS() Экспорт
	
	Если ПроцессRAS = Неопределено Тогда
		Возврат Ложь;
	Иначе
		Возврат НЕ ПроцессRAS.Завершен;
	КонецЕсли;
	
КонецФункции

// Остановить
// 	Останавливает запущенный сервер RAS.
//
Процедура ОстановитьRAS() Экспорт
	
	Если НЕ ЗапущенRAS() Тогда
		Возврат;
	КонецЕсли;

	ПроцессRAS.Завершить();	
	Лог.Отладка("Процесс %1 ras завершен.", ПроцессRAS.Идентификатор);
	ПроцессRAS = Неопределено;
	
КонецПроцедуры

Функция ЗапуститьRAS()
	
	Если ЗапущенRAS() Тогда
		Возврат ПроцессRAS;
	КонецЕсли;
	
	ПутьК1С = МенеджерПараметров.Параметр("serverRAS.pathToBin1c");
	RAS = ПутьК1С + "\" + МенеджерПараметров.Параметр("server1c.version") + "\bin\ras.exe";
	Порт = "--port=" + МенеджерПараметров.Параметр("serverRAS.mportRAS")
		+ " " + МенеджерПараметров.Параметр("server1c.server")
		+ ":" + МенеджерПараметров.Параметр("server1c.portCluster1C");
	
	ПараметрыКоманды = Новый Массив;
	ПараметрыКоманды.Добавить(ОбернутьВКавычки(RAS));
	ПараметрыКоманды.Добавить("cluster");
	ПараметрыКоманды.Добавить(Порт);
	КоманднаяСтрока = СтрСоединить(ПараметрыКоманды, " ");
	
	ТекущийКаталог = ТекущийКаталог();
	ПеренаправлятьПотокВывода = Истина;
	ПеренаправлятьПотокВвода = Ложь;
	КодировкаПотоков = КодировкаТекста.Системная;
	
	Лог.Отладка("Строка запуска RAS: " + КоманднаяСтрока);
	
	ПроцессRAS = СоздатьПроцесс(КоманднаяСтрока, ТекущийКаталог,
			ПеренаправлятьПотокВывода, ПеренаправлятьПотокВвода, КодировкаПотоков);
	
	ПроцессRAS.Запустить();
	
	ИмяСервераRAS = "localhost:" + МенеджерПараметров.Параметр("serverRAS.mportRAS");
	
	Возврат ПроцессRAS;
	
КонецФункции

Функция НуженЗапускRAS()
	
	Возврат НЕ МенеджерПараметров.Параметр("serverRAS.useDemonRAS");
	
КонецФункции

Функция ОбернутьВКавычки(Строка)

	Возврат СтрШаблон("""%1""", Строка);

КонецФункции

Функция Форматировать(Знач Уровень, Знач Сообщение) Экспорт
	
	Возврат СтрШаблон("%1: %2 - %3", ТекущаяДата(), УровниЛога.НаименованиеУровня(Уровень), Сообщение);
	
КонецФункции

Функция ДобавитьОшибку(ТекстОшибки, ВыйтиИзСкрипта = Ложь)

	МассивОшибок.Добавить(ТекстОшибки); 
	Лог.Ошибка(ТекстОшибки);

	Если ВыйтиИзСкрипта Тогда
		ЗавершитьРаботуСкрипта();
	КонецЕсли;

	Возврат Истина;

КонецФункции

Процедура ОчиститьМусор()

	ФайлПлатформы = ОбъединитьПути(ТекущийКаталог(), "logV8.log");
	Если ФС.ФайлСуществует(ФайлПлатформы) Тогда
		ФС.УдалитьФайлы(ФайлПлатформы);
	КонецЕсли;
	ФайлПлатформы = ОбъединитьПути(ТекущийКаталог(), "ReportStorage.txt");
	Если ФС.ФайлСуществует(ФайлПлатформы) Тогда
		ФС.УдалитьФайлы(ФайлПлатформы);
	КонецЕсли;	
	
КонецПроцедуры

Функция ЗавершитьРаботуСкрипта()

	ОстановитьRAS();
	Лог.Закрыть();
	ОчиститьМусор();
	ВыполнитьСборкуМусора();
	Если МассивОшибок.Количество() = 0 Тогда
		ЗавершитьРаботу(0);
	Иначе
		ЗавершитьРаботу(1);
	КонецЕсли;
	
КонецФункции



Процедура ОбработкаКомандыСкрипта(КомандаСкрипта)
	
	Если КомандаСкрипта = "lock" Тогда
		БлокировкаНаБазы(МассивОбслуживаемыхБаз, Истина);
	ИначеЕсли КомандаСкрипта = "unlock" Тогда
		БлокировкаНаБазы(МассивОбслуживаемыхБаз, Ложь);
	ИначеЕсли КомандаСкрипта = "restart" Тогда
		ПерезапускСервера();
	ИначеЕсли КомандаСкрипта = "updateFromStorage" Тогда
		Результат = УдалениеСеансовСКонфигуратором(МассивОбслуживаемыхБаз);
		Если Не Результат Тогда
			Возврат;
		КонецЕсли;		
		Для Каждого База Из МассивОбслуживаемыхБаз Цикл
			ОбновлениеКонфигурацииИзХранилища(База);
		КонецЦикла;
	ИначеЕсли КомандаСкрипта = "updateDB" Тогда
		Результат = УдалениеВсехСеансов(МассивОбслуживаемыхБаз);
		Если Не Результат Тогда
			Возврат;
		КонецЕсли;
		Для Каждого База Из МассивОбслуживаемыхБаз Цикл
			ОбновлениеКонфигурации(База);
		КонецЦикла;
	ИначеЕсли КомандаСкрипта = "batch" Тогда
		МассивКоммандПакетногоРежима = СтрРазделить(МенеджерПараметров.Параметр("batchМode"), ",");
		Для Индекс = 0 По МассивКоммандПакетногоРежима.Количество() - 1 Цикл
			КомандаИзПакета = МассивКоммандПакетногоРежима.Получить(Индекс);
			ОбработкаКомандыСкрипта(КомандаИзПакета);
		КонецЦикла;
	КонецЕсли;
	
КонецПроцедуры

#КонецОбласти

КомандаСкрипта = ИнициализацияОкружения();
ОбработкаКомандыСкрипта(КомандаСкрипта);
Лог.Информация("------");
ЗавершитьРаботуСкрипта();
