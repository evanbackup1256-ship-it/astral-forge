function deepFreeze<T>(object: T): T {
	if (!typeIs(object, "table")) {
		return object;
	}

	if (getmetatable(object) !== undefined) {
		return object;
	}

	if (table.isfrozen(object)) {
		return object;
	}

	table.freeze(object);

	for (const [, value] of pairs(object)) {
		deepFreeze(value);
	}

	return object;
}

export = deepFreeze;
