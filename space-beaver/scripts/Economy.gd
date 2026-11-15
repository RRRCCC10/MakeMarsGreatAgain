extends Node

## Budget della missione NASA. Tutti i valori sono espressi in dollari.
signal balance_changed(current: int)
## Positivo per le entrate, negativo per le spese.
signal transaction_changed(current: int, delta: int)

const STARTING_BALANCE := 10_000_000_000

var balance := STARTING_BALANCE


func _ready() -> void:
	balance_changed.emit(balance)


func can_afford(amount: int) -> bool:
	return amount >= 0 and balance >= amount


func spend(amount: int) -> bool:
	if not can_afford(amount):
		return false
	balance -= amount
	balance_changed.emit(balance)
	if amount > 0:
		transaction_changed.emit(balance, -amount)
	return true


func add_funds(amount: int) -> void:
	if amount <= 0:
		return
	balance += amount
	balance_changed.emit(balance)
	transaction_changed.emit(balance, amount)


func format_money(amount: int = balance) -> String:
	if amount >= 1_000_000_000:
		return "$ %.1f MLD" % (float(amount) / 1_000_000_000.0)
	if amount >= 1_000_000:
		return "$ %d MLN" % roundi(float(amount) / 1_000_000.0)
	return "$ %d" % amount


func reset_for_new_mission() -> void:
	balance = STARTING_BALANCE
	balance_changed.emit(balance)
