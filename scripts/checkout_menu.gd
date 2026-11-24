class_name CheckoutMenu
extends VBoxContainer
## Displays one customer identity; every click is revalidated by CustomerFlow.

var _flow: CustomerFlow
var _economy: ShopEconomy
var _customer: ShopCustomer

@onready var customer_label: Label = %CustomerName
@onready var product_label: Label = %SaleProduct
@onready var icon: TextureRect = %SaleIcon
@onready var balance_label: Label = %SaleBalance
@onready var totals_label: Label = %SaleTotals
@onready var status: Label = %SaleStatus
@onready var message: Label = %SaleMessage
@onready var serve_button: Button = %Serve

func _ready() -> void:
	serve_button.pressed.connect(_serve)

func configure(flow: CustomerFlow, economy: ShopEconomy) -> void:
	_flow = flow
	_economy = economy
	_flow.queue_changed.connect(_on_queue_changed)
	_economy.balance_changed.connect(_on_balance_changed)
	_economy.sales_changed.connect(_on_sales_changed)

func open_checkout() -> void:
	message.text = "Каждому гостю — тёплый приём."
	_refresh()

func _on_queue_changed(_waiting: int) -> void:
	_refresh()

func _on_balance_changed(_coins: int) -> void:
	_refresh()

func _on_sales_changed(_revenue: int, _sales: int) -> void:
	_refresh()

func _refresh() -> void:
	if _flow == null:
		return
	_customer = _flow.first_customer()
	var item := _flow.basket_item(_customer)
	customer_label.text = "Следующий гость · В очереди %d" % _flow.waiting.size() if _customer != null else "Пока тихо"
	icon.texture = item.icon if item != null else null
	product_label.text = "%s × 1   ·   %d монет" % [item.display_name, item.selling_price] if item != null else "У кассы пока никого нет."
	balance_label.text = "Баланс: %d монет" % _economy.balance
	totals_label.text = "Выручка: %d монет   ·   Продаж: %d" % [_economy.revenue, _economy.completed_sales]
	status.text = "Гости подходят к кассе…" if _flow.checkout_busy() else "Гость заканчивает покупки…" if is_instance_valid(_flow.active_customer) else "Можно обслужить" if item != null else "Выложите товары для новых гостей."
	serve_button.disabled = not _flow.can_serve(_customer)

func _serve() -> void:
	if not is_visible_in_tree():
		return
	var item := _flow.basket_item(_customer)
	if _flow.serve_customer(_customer):
		message.text = "Продано: %s!  +%d монет · Спасибо!" % [item.display_name, item.selling_price]
		message.add_theme_color_override("font_color", Color("#546346"))
	else:
		message.text = "Подождите, пока гость подойдёт к кассе."
	_refresh()
