class_name ShopEconomy
extends RefCounted
## Supplier purchases and atomic one-unit basket sales; all money uses integer coins.

signal balance_changed(new_balance: int)
signal sales_changed(revenue: int, completed_sales: int)

enum PurchaseResult { SUCCESS, INVALID_PRODUCT, INVALID_QUANTITY, INSUFFICIENT_FUNDS, INSUFFICIENT_SPACE }

const STARTING_BALANCE := 100
const MAX_COINS := 9223372036854775807

var balance: int:
	get:
		return _balance

var revenue: int:
	get:
		return _revenue
var completed_sales: int:
	get:
		return _completed_sales

var _revenue: int = 0
var _completed_sales: int = 0
var _selling: bool = false
var _catalog: ItemCatalog
var _storage: Inventory
var _balance := STARTING_BALANCE

func _init(catalog: ItemCatalog, storage: Inventory) -> void:
	_catalog = catalog
	_storage = storage

func order_cost(item: ItemData, amount: int) -> int:
	if item.purchase_price < 0 or amount < 1:
		return -1
	@warning_ignore("integer_division")
	if item.purchase_price > 0 and amount > MAX_COINS / item.purchase_price:
		return -1
	return item.purchase_price * amount

func buy(item_id: StringName, amount: int) -> PurchaseResult:
	var item := _catalog.find(item_id)
	if item == null or item.purchase_price < 0:
		return PurchaseResult.INVALID_PRODUCT
	if amount < 1:
		return PurchaseResult.INVALID_QUANTITY
	var cost := order_cost(item, amount)
	if cost < 0 or cost > _balance:
		return PurchaseResult.INSUFFICIENT_FUNDS

	# Inventory.add validates storage limits and notifies observers synchronously.
	# Set the balance first so those observers see the completed purchase.
	_balance -= cost
	if not _storage.add(item_id, amount):
		_balance += cost
		return PurchaseResult.INSUFFICIENT_SPACE
	if cost > 0:
		balance_changed.emit(_balance)
	return PurchaseResult.SUCCESS

func can_sell(basket: Inventory, item_id: StringName) -> bool:
	var item := _catalog.find(item_id)
	return (not _selling and basket != null and item != null
		and basket._catalog.find(item_id) == item and basket.total_units() == 1
		and basket.can_remove(item_id, 1) and item.selling_price >= 0
		and item.selling_price <= MAX_COINS - _balance
		and item.selling_price <= MAX_COINS - _revenue
		and _completed_sales < MAX_COINS)

func sell(basket: Inventory, item_id: StringName) -> bool:
	if not can_sell(basket, item_id):
		return false
	_selling = true
	var price := _catalog.find(item_id).selling_price
	# Same commit-before-notify contract as Inventory.transfer_to(). No callbacks,
	# awaits or fallible mutations between validation and completing all four values.
	basket._set_quantity(item_id, 0)
	_balance += price
	_revenue += price
	_completed_sales += 1
	basket.changed.emit()
	if price > 0:
		balance_changed.emit(_balance)
	sales_changed.emit(_revenue, _completed_sales)
	_selling = false
	return true
