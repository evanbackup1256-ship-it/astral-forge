import Retry = require("./Retry");
import Types = require("./Types");

type DataStoreInterface = Types.DataStoreInterface;

const DataStoreService = game.GetService("DataStoreService");

const RETRY = {
	ATTEMPTS: 5,
	INITIAL_WAIT: 1,
};

// 5 attempts back off 1+2+4+8 = 15 s, longer than a whole shutdown save budget. Once the server
// is closing, every store call gets 2 quick attempts so the BindToClose window covers all saves.
function useShutdownRetries() {
	RETRY.ATTEMPTS = 2;
	RETRY.INITIAL_WAIT = 0.5;
}

function retryPolicy() {
	return { Attempts: RETRY.ATTEMPTS, InitialWait: RETRY.INITIAL_WAIT };
}

function assertStorable(data: unknown, fieldName?: string): void {
	let indexDataType: string | undefined;

	if (fieldName === undefined) {
		fieldName = "Data";
	}

	assert(data === data, `NaN is not storable. Field: ${fieldName}`);

	const dataType = type(data);

	assert(dataType !== "userdata", `Userdata is not storable in DataStores. Field: ${fieldName}`);

	assert(dataType !== "thread", `Threads are not storable in DataStores. Field: ${fieldName}`);

	assert(dataType !== "function", `Functions are not storable in DataStores. Field: ${fieldName}`);

	if (dataType === "string") {
		const [len] = utf8.len(data as string);
		// `assert(len)` is lowered to `len ~= 0`, which rejects "" (utf8.len("") == 0).
		// Only a non-number (nil/false) means the bytes are not valid UTF-8.
		assert(
			typeIs(len, "number"),
			`Strings with invalid UTF-8 codepoints are not storable in Datastores. Field: ${fieldName}`,
		);
	}

	if (dataType === "table") {
		assert(
			getmetatable(data as object) === undefined,
			`Metatables are not storable in DataStores. Field: ${fieldName}`,
		);

		// `last` is never assigned in the original, so the sequential check never fires.
		const last: number | undefined = undefined;
		for (const [i, v] of pairs(data as object)) {
			if (indexDataType === undefined) {
				indexDataType = type(i);

				if (!(indexDataType === "string" || indexDataType === "number")) {
					error(`Table indexes must be strings or numbers to be storable. Field: ${fieldName}`);
				}
			}

			if (indexDataType !== undefined && type(i) !== indexDataType) {
				error(`Tables must only have on type of index to be storable. Field: ${fieldName}`);
			}

			if (typeIs(i, "number") && last !== undefined) {
				if (i - (last as number) !== 1) {
					error(`Tables with number indexes must be sequential. Field: ${fieldName}`);
				}
			}

			if (v === data) {
				error(`Tables cannot be cyclic. Field: ${fieldName}`);
			}

			assertStorable(v, `${fieldName}.${tostring(i)}`);
		}
	}
}

function getUpdateBudget() {
	return DataStoreService.GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync);
}

function getSetBudget() {
	return game.GetService("DataStoreService").GetRequestBudgetForRequestType(Enum.DataStoreRequestType.SetIncrementAsync);
}

function getGetBudget() {
	return game.GetService("DataStoreService").GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetAsync);
}

function uuid(): string {
	const template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx";

	const [result] = string.gsub(template, "[xy]", (match: string) => {
		const v = match === "x" ? math.random(0, 0xf) : math.random(8, 0xb);

		return string.format("%x", v);
	});

	return result;
}

type AbortAttempt = (err: string) => void;

function updateAsync(
	transform: (abortAttempt: AbortAttempt, data: unknown, keyInfo: DataStoreKeyInfo) => unknown,
	dataStore: DataStoreInterface,
	key: string,
): LuaTuple<[boolean, unknown, DataStoreKeyInfo]> {
	const result = Retry(RETRY.ATTEMPTS, RETRY.INITIAL_WAIT, () => {
		let shouldAbort = false;
		let abortError = "";
		const abortAttempt = (err: string) => {
			shouldAbort = true;
			abortError = err;
		};

		assert(SaveUtil.getUpdateBudget() > 0, "Ran out of budget");

		const [resultData, resultKeyInfo] = dataStore.UpdateAsync(key, (data: unknown, keyInfo: DataStoreKeyInfo) => {
			const transformResult = transform(abortAttempt, data, keyInfo);

			if (shouldAbort) {
				return data;
			} else {
				return transformResult;
			}
		});

		if (shouldAbort) {
			error(abortError);
		}

		return $tuple(resultData, resultKeyInfo);
	});

	return $tuple(result.success, result.returnValues[0], result.returnValues[1] as DataStoreKeyInfo);
}

function getAsync(dataStore: DataStoreInterface, key: string): LuaTuple<[boolean, unknown, DataStoreKeyInfo]> {
	const result = Retry(RETRY.ATTEMPTS, RETRY.INITIAL_WAIT, () => {
		const options = new Instance("DataStoreGetOptions");
		options.UseCache = false;

		assert(SaveUtil.getGetBudget() > 0, "Ran out of budget");

		const [resultData, resultKeyInfo] = dataStore.GetAsync(key, options);

		return $tuple(resultData, resultKeyInfo);
	});

	return $tuple(result.success, result.returnValues[0], result.returnValues[1] as DataStoreKeyInfo);
}

function removeAsync(dataStore: DataStoreInterface, key: string): boolean {
	const result = Retry(RETRY.ATTEMPTS, RETRY.INITIAL_WAIT, () => {
		assert(SaveUtil.getSetBudget() > 0, "Ran out of budget");

		return dataStore.RemoveAsync(key);
	});

	return result.success;
}

const SaveUtil = {
	assertStorable,
	getUpdateBudget,
	getSetBudget,
	getGetBudget,
	uuid,
	updateAsync,
	getAsync,
	removeAsync,
	useShutdownRetries,
	retryPolicy,
};

export = SaveUtil;
