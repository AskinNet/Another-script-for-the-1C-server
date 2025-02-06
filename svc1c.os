// askin(c)
//
// Параметры скрипта:
// Первый параметр - наименования файла настроек
// Второй - команда.
//
// Команды:
// без команды  - ничего
// testparam
// или debug				- только тестирование параметров
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
Перем ПроцессRAS;
Перем МассивОбслуживаемыхБаз;

#КонецОбласти

#Область ПрограммныйИнтерфейс

Функция ИнициализацияОкружения()
	
	// значение по умолчанию
	ФайлНастроек = "IPIITC213-00020.yml";
	КомандаСкрипта = "";
	
	Лог = Логирование.ПолучитьЛог("oscript.app.serv");
	Лог.УстановитьРаскладку(ЭтотОбъект);
	
	ЛогВыводВФайл = Новый ВыводЛогаВФайл; //аппендер обычного лога
	ЛогВыводВФайл.ОткрытьФайл("log_serv.log");
	Лог.ДобавитьСпособВывода(ЛогВыводВФайл, УровниЛога.Информация);
	Лог.Информация("Инициализация скрипта");
	
	// ЛогПровайдера = Логирование.ПолучитьЛог("oscript.lib.configor.yaml");
	// ЛогПровайдера.УстановитьУровень(УровниЛога.Отладка);
	// Лог2ВыводВФайл = Новый ВыводЛогаВФайл;
	// Лог2ВыводВФайл.ОткрытьФайл("log_serv2.log");
	// ЛогПровайдера.ДобавитьСпособВывода(Лог2ВыводВФайл, УровниЛога.Отладка);	

	Если АргументыКоманднойСтроки.Количество() > 0 Тогда
		ФайлНастроек = ОбъединитьПути(ТекущийКаталог(), АргументыКоманднойСтроки[0]);
		Если АргументыКоманднойСтроки.Количество() > 1 Тогда
			КомандаСкрипта = АргументыКоманднойСтроки[1];
		КонецЕсли;
	КонецЕсли;
	
	Если ФайлНастроек = "" Тогда
		Лог.Ошибка("Не найден файл параметров");
		ЗавершитьРаботуСкрипта(1);
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
		Лог.Ошибка("Не удалось прочитать настройки!");
		ЗавершитьРаботуСкрипта(1);
	КонецЕсли;
	
	Возврат КомандаСкрипта;
	
КонецФункции

Функция ПодключениеККластеру(База)
	
	Лог.Информация("Подключение к кластеру серверов");
	АдминистраторКластера1С = МенеджерПараметров.Параметр("server1c." + База + ".user");
	ПарольКластера1С = МенеджерПараметров.Параметр("server1c." + База + ".password");
	Админ = Новый Структура("Администратор, Пароль", АдминистраторКластера1С, ПарольКластера1С);

	Если НуженЗапускRAS() Тогда
		ЗапуститьRAS();
	КонецЕсли;

	Если ЗапущенRAS() Тогда
		Управление = Новый УправлениеКластером1С("8.3", "localhost:" + МенеджерПараметров.Параметр("serverRAS.mportRAS"), Админ);		
	Иначе
		Управление = Новый УправлениеКластером1С("8.3", МенеджерПараметров.Параметр("serverRAS.servernameRAS") + ":"
		+ МенеджерПараметров.Параметр("serverRAS.portRAS"), Админ);
	КонецЕсли;

	Кластер = Управление.Кластеры().Список()[0];
	Возврат Кластер;
	
КонецФункции

Процедура БлокировкаНаБазы(Знач СписокБаз, Установить = Ложь)
	
	Лог.Информация("Установка блокировки на базы");
	
	Если Установить Тогда
		ПереключательСостояния = Перечисления.СостоянияВыключателя.Включено;
	Иначе
		ПереключательСостояния = Перечисления.СостоянияВыключателя.Выключено;
	КонецЕсли;

	Для Каждого ИмяТекущейБазы Из СписокБаз Цикл

		ТекущийКластер = ПодключениеККластеру(ИмяТекущейБазы);

		ИнформационнаяБаза = ТекущийКластер.ИнформационныеБазы().Получить(ИмяТекущейБазы);
		АдминистраторПользовательИБ = МенеджерПараметров.Параметр("server1c." + ИмяТекущейБазы + ".user");
		ПарольАдминистратораИБ = МенеджерПараметров.Параметр("server1c." + ИмяТекущейБазы + ".password");
		ИнформационнаяБаза.УстановитьАдминистратора(АдминистраторПользовательИБ, ПарольАдминистратораИБ);
		
		ПараметрыИБ = Новый Структура();
		ПараметрыИБ.Вставить("НачалоБлокировкиСеансов", ТекущаяДата());
		ПараметрыИБ.Вставить("ОкончаниеБлокировкиСеансов", ТекущаяДата() + МенеджерПараметров.Параметр("server1c.lockTime"));
		ПараметрыИБ.Вставить("СообщениеБлокировкиСеансов", "Технические работы");
		ПараметрыИБ.Вставить("КодРазрешения", МенеджерПараметров.Параметр("server1c." + ИмяТекущейБазы + ".allowKey"));
		ПараметрыИБ.Вставить("БлокировкаСеансовВключена", ПереключательСостояния);
		ПараметрыИБ.Вставить("БлокировкаРегламентныхЗаданийВключена", ПереключательСостояния);
		ИнформационнаяБаза.Изменить(ПараметрыИБ);
		
		Если Установить Тогда
			Лог.Информация("Заблокирована база:" + ИмяТекущейБазы);
		Иначе
			Лог.Информация("Разблокированна база:" + ИмяТекущейБазы);
		КонецЕсли;
		
	КонецЦикла;
	
КонецПроцедуры

Процедура УдалитьСеансыСКонфигуратором(Знач СписокБаз)
	
	
	Для Каждого ИмяТекущейБазы Из СписокБаз Цикл

		ТекущийКластер = ПодключениеККластеру(ИмяТекущейБазы);

		ИнформационнаяБаза = ТекущийКластер.ИнформационныеБазы().Получить(ИмяТекущейБазы);
		АдминистраторПользовательИБ = МенеджерПараметров.Параметр("server1c." + ИмяТекущейБазы + ".user");
		ПарольАдминистратораИБ = МенеджерПараметров.Параметр("server1c." + ИмяТекущейБазы + ".password");
		ИнформационнаяБаза.УстановитьАдминистратора(АдминистраторПользовательИБ, ПарольАдминистратораИБ);
		ИдТекущейБазы = ИнформационнаяБаза.Получить("infobase");

		Сеансы = ТекущийКластер.Сеансы();
		Для Каждого Сеанс Из Сеансы.Список() Цикл
			Параметры = Сеанс.ПараметрыОбъекта();
			Приложение = Сеанс.Получить("Приложение");
			БазаДанныхСеанса  = Сеанс.Получить("infobase");
			Если Приложение = "Designer" И БазаДанныхСеанса = ИдТекущейБазы Тогда
				Сеанс.Завершить();
			КонецЕсли;
		КонецЦикла;
		
	КонецЦикла;
	
КонецПроцедуры

Процедура УдалитьВсеСеансы(Знач СписокБаз)
	
	
	Для Каждого ИмяТекущейБазы Из СписокБаз Цикл

		ТекущийКластер = ПодключениеККластеру(ИмяТекущейБазы);

		ИнформационнаяБаза = ТекущийКластер.ИнформационныеБазы().Получить(ИмяТекущейБазы);
		АдминистраторПользовательИБ = МенеджерПараметров.Параметр("server1c." + ИмяТекущейБазы + ".user");
		ПарольАдминистратораИБ = МенеджерПараметров.Параметр("server1c." + ИмяТекущейБазы + ".password");
		ИнформационнаяБаза.УстановитьАдминистратора(АдминистраторПользовательИБ, ПарольАдминистратораИБ);
		ИдТекущейБазы = ИнформационнаяБаза.Получить("infobase");

		Сеансы = ТекущийКластер.Сеансы();
		Для Каждого Сеанс Из Сеансы.Список() Цикл
			Сеанс.Завершить();
		КонецЦикла;
		
	КонецЦикла;
	
КонецПроцедуры

Функция ОбновитьКонфигурациюИзХранилища(База, Конфигуратор = Неопределено)
	
	
	Если Конфигуратор = Неопределено Тогда
		Лог.Информация("Установка параметров конфигуратора");
		Конфигуратор = УстановкаКонтекстаКонфигуратора(База);
	КонецЕсли;
	СтрокаХранилищ = "server1c.bases." + База + ".1cstorages";
	Для Каждого Хранилище Из МенеджерПараметров.Параметр(СтрокаХранилищ) Цикл
		ИмяХранилища = Хранилище.Ключ;
		Если ИмяХранилища = База Тогда
			Попытка
				Лог.Информация("Запуск обновления из хранилища основной базы: " + ИмяХранилища);
				Конфигуратор.ЗагрузитьКонфигурациюИзХранилища(МенеджерПараметров.Параметр(СтрокаХранилищ + "." + ИмяХранилища + ".path"),
					МенеджерПараметров.Параметр(СтрокаХранилищ + "." + ИмяХранилища + ".user"),
					МенеджерПараметров.Параметр(СтрокаХранилищ + "." + ИмяХранилища + ".pass"));
				
				Лог.Информация("Обновлена конфигурация из хранилища " + ИмяХранилища);
			Исключение
				Лог.Ошибка(СтрШаблон(НСтр("ru = 'Ошибка при получении изменений из хранилища.
							|%1'"), Конфигуратор.ВыводКоманды()));
			КонецПопытки;
			
		Иначе
			
			Попытка
				Лог.Информация("Запуск обновления из хранилища расширения: " + ИмяХранилища);
				Конфигуратор.РасширениеПолучитьИзХранилища(МенеджерПараметров.Параметр(СтрокаХранилищ + "." + ИмяХранилища + ".path"),
					МенеджерПараметров.Параметр(СтрокаХранилищ + "." + ИмяХранилища + ".user"),
					МенеджерПараметров.Параметр(СтрокаХранилищ + "." + ИмяХранилища + ".pass"),
					МенеджерПараметров.Параметр(СтрокаХранилищ + "." + ИмяХранилища + ".name",
						0));
				Лог.Информация("Обновлена конфигурация расширения " + ИмяХранилища);
			Исключение
				Лог.Ошибка(СтрШаблон(НСтр("ru = 'Ошибка при получении изменений из хранилища расширения.
							|%1'"), Конфигуратор.ВыводКоманды()));
				
			КонецПопытки;
		КонецЕсли;
		
	КонецЦикла;
	
	Конфигуратор = NULL;
	ФайлПлатформы = ОбъединитьПути(ТекущийКаталог(), "tt.txt");
	Если ФС.ФайлСуществует(ФайлПлатформы) Тогда
		ФС.УдалитьФайлы(ФайлПлатформы);
	КонецЕсли;
	ВыполнитьСборкуМусора();
	
КонецФункции

Функция ОбновитьКонфигурациюБазы(База, Конфигуратор = Неопределено)
	
	Если Конфигуратор = Неопределено Тогда
		Лог.Информация("Установка параметров конфигуратора");
		Конфигуратор = УстановкаКонтекстаКонфигуратора(База);
	КонецЕсли;

	СтрокаХранилищ = "server1c.bases." + База + ".1cstorages";
	Для Каждого Хранилище Из МенеджерПараметров.Параметр(СтрокаХранилищ) Цикл
		ИмяХранилища = Хранилище.Ключ;
		Если ИмяХранилища = База Тогда
			Лог.Информация("Запуск обновления основной конфигурации базы");
			Конфигуратор.ОбновитьКонфигурациюБазыДанных();
			Лог.Информация("Обновление основной конфигурации базы завершено");
		Иначе
			НаименованиеХранилища = МенеджерПараметров.Параметр(СтрокаХранилищ + "." + ИмяХранилища + ".name");
			Лог.Информация("Запуск обновления расширения базы: " + НаименованиеХранилища);
			Конфигуратор.ОбновитьКонфигурациюБазыДанных(,,,НаименованиеХранилища);
			Лог.Информация("Обновление расширения " + НаименованиеХранилища + " завершено");
		КонецЕсли;
	КонецЦикла;

	Конфигуратор = NULL;
	ФайлПлатформы = ОбъединитьПути(ТекущийКаталог(), "tt.txt");
	Если ФС.ФайлСуществует(ФайлПлатформы) Тогда
		ФС.УдалитьФайлы(ФайлПлатформы);
	КонецЕсли;
	ВыполнитьСборкуМусора();
	
КонецФункции

Процедура ПерезапускСервера()
	
	КомандныйФайл = Новый КомандныйФайл;
	КомандныйФайл.Создать();
	
	Лог.Информация("-----Скрипт bat-------");
	Лог.Информация("Перезапуск серверных служб:");
	
	КомандныйФайл.ДобавитьКоманду("@SC STOP """ + МенеджерПараметров.Параметр("server1c.1cDemonName") + "");
	//КомандныйФайл.ДобавитьКоманду("@SC STOP """ + МенеджерПараметров.Параметр("server1c.1cRasDemonName") + "");
	Лог.Информация("Пауза 15 секунд:");
	КомандныйФайл.ДобавитьКоманду("@start /wait timeout 15");
	Лог.Информация("Убийство неуспевших завершиться процессов:");
	КомандныйФайл.ДобавитьКоманду("@TASKKILL /F /IM RPHOST.EXE");
	КомандныйФайл.ДобавитьКоманду("@TASKKILL /F /IM RMNGR.EXE");
	КомандныйФайл.ДобавитьКоманду("@TASKKILL /F /IM RAGENT.EXE");
	КомандныйФайл.ДобавитьКоманду("@TASKKILL /F /IM RAS.EXE");
	Лог.Информация("Пауза 15 секунд:");
	КомандныйФайл.ДобавитьКоманду("@start /wait timeout 15");
	
	Лог.Информация("Очистка каталога сеансовых данных сервера 1с:");
	КомандныйФайл.ДобавитьКоманду("@DEL /Q /F /S " + МенеджерПараметров.Параметр("server1c.Path1cService") + "\SNCCNTX*");
	КомандныйФайл.ДобавитьКоманду("@DEL /Q /F /S " + МенеджерПараметров.Параметр("server1c.Path1cService") + "\STT*");
	
	Лог.Информация("Запуск служб:");
	КомандныйФайл.ДобавитьКоманду("@SC START """ + МенеджерПараметров.Параметр("server1c.1cDemonName") + "");
	//КомандныйФайл.ДобавитьКоманду("@SC START """ + МенеджерПараметров.Параметр("server1c.1cRasDemonName") + "");
	
	КодВозврата = КомандныйФайл.Исполнить();
	ЭхоБатФайла = КомандныйФайл.ПолучитьВывод();
	Лог.Информация("Код возврата " + КодВозврата);
	
	Лог.Отладка("Лог bat-файла - начало");
	Лог.Отладка(ЭхоБатФайла);
	Лог.Отладка("Лог bat-файла - окончание");
	
	Лог.Информация("Перезапуск сервера завешен");
	
КонецПроцедуры

Функция ТестированиеПараметров()
	
	ПрочитанныеПараметры = МенеджерПараметров.ПрочитанныеПараметры();
	
	// проверки наличия ключей
	Лог.Отладка("Тестирование параметра " + "server1c.server");
	Ожидаем.Что(МенеджерПараметров.Параметр("server1c.server")).Существует();
	Лог.Отладка("Тестирование параметра " + "server1c.port");
	Ожидаем.Что(МенеджерПараметров.Параметр("server1c.port")).Существует();
	Лог.Отладка("Тестирование параметра " + "server1c.servernameRAS");
	Ожидаем.Что(МенеджерПараметров.Параметр("server1c.servernameRAS")).Существует();
	Лог.Отладка("Тестирование параметра " + "server1c.portRAS");
	Ожидаем.Что(МенеджерПараметров.Параметр("server1c.portRAS")).Существует();
	Лог.Отладка("Тестирование параметра " + "server1c.version");
	Ожидаем.Что(МенеджерПараметров.Параметр("server1c.version")).Существует();
	Лог.Отладка("Тестирование параметра " + "server1c.1cDemonName");
	Ожидаем.Что(МенеджерПараметров.Параметр("server1c.1cDemonName")).Существует();
	Лог.Отладка("Тестирование параметра " + "server1c.serv1cRasDemonNameer");
	Ожидаем.Что(МенеджерПараметров.Параметр("server1c.1cRasDemonName")).Существует();
	Лог.Отладка("Тестирование параметра " + "server1c.Path1cService");
	Ожидаем.Что(МенеджерПараметров.Параметр("server1c.Path1cService")).Существует();
	Лог.Отладка("Тестирование параметра " + "server1c.lockTime");
	Ожидаем.Что(МенеджерПараметров.Параметр("server1c.lockTime")).Существует();
	
	МассивОбслуживаемыхБаз = МассивОбслуживаемыхБаз();
	
	Для Каждого База Из МассивОбслуживаемыхБаз Цикл
		Лог.Отладка("Тестирование параметра server1c.bases." + База);
		Ожидаем.Что(МенеджерПараметров.Параметр("server1c.bases." + База)).Существует();
		Лог.Отладка("Тестирование параметра server1c.bases." + База + ".user");
		Ожидаем.Что(МенеджерПараметров.Параметр("server1c.bases." + База + ".user")).Существует();
		Лог.Отладка("Тестирование параметра server1c.bases." + База + ".password");
		Ожидаем.Что(МенеджерПараметров.Параметр("server1c.bases." + База + ".password")).Существует();
		Лог.Отладка("Тестирование параметра server1c.bases." + База + ".allowKey");
		Ожидаем.Что(МенеджерПараметров.Параметр("server1c.bases." + База + ".allowKey")).Существует();
	КонецЦикла;
	
	Для Каждого База Из МассивОбслуживаемыхБаз Цикл
		НастройкиХранилищ = МенеджерПараметров.Параметр("server1c.bases." + База + ".1cstorages", Неопределено);
		Если ТипЗнч(НастройкиХранилищ) <> Неопределено Тогда
			МассивХранилищ = Новый Массив;
			Для Каждого Хранилище Из МенеджерПараметров.Параметр("server1c.bases." + База + ".1cstorages") Цикл
				МассивХранилищ.Добавить(Хранилище.Ключ);
			КонецЦикла;
		КонецЕсли;
	КонецЦикла;
	
	Лог.Информация("Тестирование подключения к кластеру");
	// проверки подключение
	АдминистраторКластера1С = МенеджерПараметров.Параметр("server1c." + МассивОбслуживаемыхБаз[0] + ".user");
	ПарольКластера1С = МенеджерПараметров.Параметр("server1c." + МассивОбслуживаемыхБаз[0] + ".password");
	Админ = Новый Структура("Администратор, Пароль", АдминистраторКластера1С, ПарольКластера1С);
	Управление = Новый УправлениеКластером1С("8.3", МенеджерПараметров.Параметр("server1c.servernameRAS") + ":"
			+ МенеджерПараметров.Параметр("server1c.portRAS"), Админ);
	Кластер = Управление.Кластеры().Список()[0];
	
	Для Каждого База Из МассивОбслуживаемыхБаз Цикл
		ИБ = Кластер.ИнформационныеБазы().Получить(База);
		АдминистраторКластера1С = МенеджерПараметров.Параметр("server1c." + МассивОбслуживаемыхБаз[0] + ".user");
		ПарольКластера1С = МенеджерПараметров.Параметр("server1c." + МассивОбслуживаемыхБаз[0] + ".password");
		ИБ.УстановитьАдминистратора(АдминистраторКластера1С, ПарольКластера1С);
	КонецЦикла;
	
	Лог.Информация("Подключение к кластеру выполнено");
	
	Лог.Информация("Тестирование подключения подключений к хранилищам");
	Если МассивХранилищ.Количество() > 0 Тогда
		Для Каждого База Из МассивОбслуживаемыхБаз Цикл
			Лог.Информация("Тестирование хранилищ базы " + База);
			Конфигуратор = УстановкаКонтекстаКонфигуратора(База);
			Для Каждого Хранилище Из МассивХранилищ Цикл
				ПользовательХранилища = МенеджерПараметров.Параметр("server1c.bases." + База + ".1cstorages." + Хранилище + ".user");
				ПарольХранилища = МенеджерПараметров.Параметр("server1c.bases." + База + ".1cstorages." + Хранилище + ".pass");
				ПутьКХранилищу = МенеджерПараметров.Параметр("server1c.bases." + База + ".1cstorages." + Хранилище + ".path");
				ЭтоРасширение = ЭтоХранилищеРасширения(База, Хранилище);
				Конфигуратор.УстановитьМеткуДляВерсииВХранилище(ПутьКХранилищу,
					ПользовательХранилища,
					ПарольХранилища,
					"0",
					"",
					0,
					?(ЭтоРасширение.Результат, ЭтоРасширение.ИмяРасширения, ""));
				Лог.Информация(Конфигуратор.ВыводКоманды());
				Лог.Информация("Тестирование подключения хранилища " + Хранилище + " к базе " + База + " завершено.");
			КонецЦикла;
		КонецЦикла;
	КонецЕсли;
	
	Лог.Информация("Тестирование параметров завершено.");
	
КонецФункции

#КонецОбласти



#Область СлужебныеПроцедурыИФункции

Функция ЭтоХранилищеРасширения(База, ИмяХранилища)
	
	СохраненноеИмяХранилища = МенеджерПараметров.Параметр("server1c.bases." + База + ".1cstorages." + ИмяХранилища + ".name");
	Возврат Новый Структура("Результат,ИмяРасширения", База <> СохраненноеИмяХранилища, СохраненноеИмяХранилища);
	
КонецФункции

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

Функция УстановкаКонтекстаКонфигуратора(База)
	
	Конфигуратор = Новый УправлениеКонфигуратором();
	Конфигуратор.ИспользоватьВерсиюПлатформы(МенеджерПараметров.Параметр("server1c.version"));
	ПараметрыСтрокиСоединения = СтрокаСоединенияКонфигуратора(База, Конфигуратор);
	Конфигуратор.УстановитьКонтекст(ПараметрыСтрокиСоединения,
		МенеджерПараметров.Параметр("server1c." + База + ".user"),
		МенеджерПараметров.Параметр("server1c." + База + ".password"));
	
	КлючРазрешенияЗапуска = МенеджерПараметров.Параметр("server1c." + База + ".allowKey");
	Конфигуратор.УстановитьКлючРазрешенияЗапуска(КлючРазрешенияЗапуска);
	
	ФайлПлатформы = ОбъединитьПути(ТекущийКаталог(), "tt.txt");
	Конфигуратор.УстановитьИмяФайлаСообщенийПлатформы(ФайлПлатформы);
	Возврат Конфигуратор;
	
КонецФункции

Процедура ОбработатьКоманду(КомандаСкрипта)

	Если КомандаСкрипта = "testparam"
		ИЛИ КомандаСкрипта = "debug" Тогда
		ТестированиеПараметров();
	ИначеЕсли КомандаСкрипта = "lock" Тогда
		БлокировкаНаБазы(МассивОбслуживаемыхБаз, Истина);
	ИначеЕсли КомандаСкрипта = "unlock" Тогда
		БлокировкаНаБазы(МассивОбслуживаемыхБаз, Ложь);
	ИначеЕсли КомандаСкрипта = "restart" Тогда
		ПерезапускСервера();
	ИначеЕсли КомандаСкрипта = "updateFromStorage" Тогда
		УдалитьСеансыСКонфигуратором(МассивОбслуживаемыхБаз);
		Для Каждого База Из МассивОбслуживаемыхБаз Цикл
			ОбновитьКонфигурациюИзХранилища(База);
		КонецЦикла;
	ИначеЕсли КомандаСкрипта = "updateDB" Тогда
		УдалитьСеансыСКонфигуратором(МассивОбслуживаемыхБаз);
		Для Каждого База Из МассивОбслуживаемыхБаз Цикл
			ОбновитьКонфигурациюБазы(База);	
		КонецЦикла;		
	КонецЕсли;

КонецПроцедуры

// Запущен
//		Проверяет запущен ли процесс сервера RAS
// Возвращаемое значение:
//   Булево - Истина - если процесс запущен, Ложь - в остальных случаях
//
Функция ЗапущенRAS() Экспорт

	Если ПроцессRAS = Неопределено Тогда
		Возврат Ложь;
	Иначе
		Возврат Не ПроцессRAS.Завершен;
	КонецЕсли;

КонецФункции

// Остановить
// 	Останавливает запущенный сервер RAS.
//
Процедура ОстановитьRAS() Экспорт

	Если Не ЗапущенRAS() Тогда
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
	RAS= ПутьК1С + "\" + МенеджерПараметров.Параметр("server1c.version") + "\bin\ras.exe";
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
	КодировкаПотоков = КодировкаТекста.UTF8;
	
	ПроцессRAS = СоздатьПроцесс(КоманднаяСтрока, ТекущийКаталог,
			ПеренаправлятьПотокВывода, ПеренаправлятьПотокВвода, КодировкаПотоков);
			ПроцессRAS.Запустить();
	Лог.Информация("RAS запущен. " + КоманднаяСтрока);
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

Функция ЗавершитьРаботуСкрипта(Код)
	
	Конфигуратор = NULL;
	ОстановитьRAS();
	ФайлПлатформы = ОбъединитьПути(ТекущийКаталог(), "tt.txt");
	Если ФС.ФайлСуществует(ФайлПлатформы) Тогда
		ФС.УдалитьФайлы(ФайлПлатформы);
	КонецЕсли;
	Лог.Закрыть();
	ВыполнитьСборкуМусора();
	ЗавершитьРаботу(Код);

КонецФункции


#КонецОбласти


//-------------------------------------------------------
//-------------------------------------------------------

КомандаСкрипта = ИнициализацияОкружения();
МассивОбслуживаемыхБаз = МассивОбслуживаемыхБаз();
РестарСервераДоОбновления = МенеджерПараметров.Параметр("server1c.restartServiceBefore");
МассивКомманд = СтрРазделить(МенеджерПараметров.Параметр("server1c.batch"),",");



Если КомандаСкрипта = "batch" Тогда
	Для Индекс = 0 По МассивКомманд.Количество() - 1 Цикл
		КомандаИзПакета = МассивКомманд.Получить(Индекс);
		//ОбработатьКоманду(КомандаИзПакета);
	КонецЦикла;
ИначеЕсли КомандаСкрипта = "test" Тогда

Иначе
	ОбработатьКоманду(КомандаСкрипта);	
КонецЕсли;


ЗавершитьРаботуСкрипта(0);




