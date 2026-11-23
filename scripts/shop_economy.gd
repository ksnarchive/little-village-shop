class_name ShopEconomy
extends RefCounted
## Purchases deliver directly to the existing storage inventory.

signal balance_changed(new_balance: int)

enum PurchaseResult { SUCCESS, INVALID_PRODUCT, INVALID_QUANTITY, INSUFFICIENT_FUNDS, INSUFFICIENT_SPACE }

const STARTING_BALANCE := 100
const MAX_COINS := 9223372036854775807

var balance: int:
	get:
		return _balance

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
