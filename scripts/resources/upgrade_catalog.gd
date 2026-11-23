class_name UpgradeCatalog
extends Resource
## Every upgrade the General Store offers, in the order the Upgrades tab lists them.
## (A list resource rather than a folder scan, so exported builds find them all.)

@export var upgrades: Array[UpgradeData] = []
