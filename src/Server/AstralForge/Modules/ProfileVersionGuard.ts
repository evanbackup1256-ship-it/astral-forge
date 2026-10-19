// Pure server guard: validate that a stored profile's schema version is readable.

function ReadCompatible(raw: unknown, targetVersion: number): number {
	assert(typeIs(raw, "table"), "stored profile is not a table");
	assert(typeIs(targetVersion, "number") && targetVersion >= 1, "invalid target schema");
	const rawTable = raw as Record<string, unknown>;
	if (rawTable.DataVersion === undefined) {
		return 0;
	}
	const sourceVersion = tonumber(rawTable.DataVersion);
	assert(
		sourceVersion !== undefined && sourceVersion >= 0 && sourceVersion % 1 === 0,
		"stored profile has an invalid schema",
	);
	assert(sourceVersion <= targetVersion, "stored profile has a newer schema");
	return sourceVersion;
}

export = table.freeze({ ReadCompatible });
