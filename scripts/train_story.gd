class_name TrainStory
extends RefCounted
## Stable checkpoint IDs: append/migrate explicitly if this sequence changes later.
const THOUGHTS := [
	"Ещё месяц назад утро начиналось с часов над проходной. Они всегда спешили. Или это мне всегда не хватало пяти минут?",
	"Теперь можно просто смотреть в окно. Непривычное занятие. Кажется, получается.",
	"Газета понадобилась из-за дождя — прикрыть голову по дороге домой. Объявление нашлось между продажей дров и пропавшим зонтом.",
	"«Небольшая деревенская лавка. Жилое помещение наверху». Цена была такая, что пришлось поискать продолжение мелким шрифтом.",
	"Продолжения не было. Зато была фотография: кривоватая вывеска и дерево у окна. Почему-то запомнилось именно дерево.",
	"Всю неделю на полях служебных бумаг появлялись цифры. Сколько там накопилось за все эти годы? На лавку хватило почти впритык.",
	"Сбережения на чёрный день теперь называются недвижимостью. А сам чёрный день, видимо, придётся попросить прийти попозже.",
	"Покупать магазин, ни разу в нём не побывав… Хорошо, что чемодан не умеет давать советы. Ему наверняка есть что сказать.",
	"В нём оказалось удивительно мало вещей. Самое тяжёлое всё равно едет без багажа.",
	"За окном уже третий дом с яблоней. Не знаю, получится ли из меня лавочник. Но впервые за долгое время хочется узнать, что будет завтра."
]
const ARRIVAL := "Уважаемые пассажиры, поезд прибывает. Пожалуйста, не забудьте свои вещи."
const LAST_LINE := 10

static func fresh() -> Dictionary:
	return {"train_line": 0, "train_complete": false}

static func completed() -> Dictionary:
	return {"train_line": LAST_LINE, "train_complete": true}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or not value.get("train_complete") is bool:
		return false
	var line: Variant = value.get("train_line")
	if not (line is float or line is int) or not is_finite(float(line)):
		return false
	return line >= 0 and line <= LAST_LINE and line == floor(float(line)) and (not value.train_complete or line == LAST_LINE)
