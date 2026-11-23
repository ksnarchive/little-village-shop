class_name ShopDay
extends Node
## In-memory workday clock. 1.5 game minutes/second = 6m40s plus menus/closing.

signal clock_changed
signal day_finished(report: Dictionary)
signal day_started

enum Phase { PREPARATION, OPEN, RUSH, AFTERNOON, CLOSING, SUMMARY }
const START_MINUTE := 8 * 60
const CLOSE_MINUTE := 18 * 60
const MINUTES_PER_SECOND := 1.5

var day_number: int = 1
var minute: float = START_MINUTE
var phase: Phase = Phase.PREPARATION
var paused: bool = false
var _flow: CustomerFlow
var _economy: ShopEconomy
var _report: Dictionary = {}
var _transitioning: bool = false

func configure(flow: CustomerFlow, economy: ShopEconomy) -> void:
	_flow = flow
	_economy = economy
	_apply_phase()

func _physics_process(delta: float) -> void:
	advance_time(delta)

func advance_time(seconds: float) -> void:
	if _transitioning or seconds < 0.0 or not is_finite(seconds) or _flow == null:
		return
	if not paused and phase < Phase.CLOSING:
		var target := minf(CLOSE_MINUTE, minute + seconds * MINUTES_PER_SECOND)
		# Emit every crossed boundary in order, even after a long frame.
		for boundary in [540, 720, 840, 1080]:
			if minute < boundary and target >= boundary:
				minute = boundary
				_apply_phase()
		minute = target
		clock_changed.emit()
	if phase == Phase.CLOSING and _flow.is_empty():
		_finish_day()

func _apply_phase() -> void:
	if minute < 540:
		phase = Phase.PREPARATION
	elif minute < 720:
		phase = Phase.OPEN
	elif minute < 840:
		phase = Phase.RUSH
	elif minute < CLOSE_MINUTE:
		phase = Phase.AFTERNOON
	else:
		phase = Phase.CLOSING
	_flow.set_business_hours(phase in [Phase.OPEN, Phase.RUSH, Phase.AFTERNOON], phase == Phase.RUSH)
	clock_changed.emit()

func time_text() -> String:
	var whole := int(minute)
	@warning_ignore("integer_division")
	return "%02d:%02d" % [whole / 60, whole % 60]

func phase_text() -> String:
	return ["Подготовка · открытие в 09:00", "Открыто · до 18:00", "Обеденный час · больше гостей",
		"Открыто · до 18:00", "Закрыто · ждём гостей у кассы", "Рабочий день завершён"][phase]

func report() -> Dictionary:
	return _report.duplicate(true)

func _finish_day() -> void:
	_transitioning = true
	phase = Phase.SUMMARY
	_economy.transactions_enabled = false
	_report = {"day": day_number, "customers": _economy.day_sales,
		"revenue": _economy.day_revenue, "expenses": _economy.day_expenses,
		"profit": _economy.day_revenue - _economy.day_expenses, "balance": _economy.balance}
	clock_changed.emit()
	day_finished.emit(report())
	_transitioning = false

func start_next_day() -> bool:
	if phase != Phase.SUMMARY or _transitioning or not _flow.is_empty():
		return false
	_transitioning = true
	day_number += 1
	minute = START_MINUTE
	_report.clear()
	_economy.reset_day_totals()
	_economy.transactions_enabled = true
	_flow.reset_arrival_timer()
	_apply_phase()
	day_started.emit()
	_transitioning = false
	return true
