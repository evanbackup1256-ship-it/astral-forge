// Shared presentation and input rules; authorization remains exclusively server-side.
interface Definition {
	World?: unknown;
	Moderation?: unknown;
	Option?: unknown;
	Category?: unknown;
}
interface Rule {
	Mode: string;
	UsesAmount: boolean;
	Minimum: number;
	Maximum: number;
	Integer: boolean;
	Summary: string;
}

const fractional: Record<string, boolean> = { GrantFlux: true, GrantCores: true, GrantStardust: true };
const isSet = (value: unknown) => value !== undefined && value !== false;

function describe(command: string, definition: Definition): Rule {
	let mode = isSet(definition.World)
		? "duration"
		: command.sub(1, 5) === "Grant"
			? "add"
			: command.sub(1, 3) === "Set"
				? "set"
				: "action";
	if (isSet(definition.Moderation)) {
		mode = command === "ServerBan" || command === "GlobalBan" ? "moderation" : "action";
	}
	return {
		Mode: mode,
		UsesAmount: mode !== "action",
		Minimum: mode === "duration" ? 3 : mode === "set" || mode === "moderation" ? 0 : 1,
		Maximum: mode === "duration" ? 20 : command === "GrantRelic" ? 10 : 9e15,
		Integer: !fractional[command],
		Summary:
			mode === "set"
				? "Replaces the selected value; zero is allowed."
				: mode === "add"
					? "Adds the amount to this player's profile."
					: mode === "duration"
						? "Temporary client effect. Duration is in seconds."
						: isSet(definition.Moderation)
							? "Applies the selected moderation action to one player."
							: definition.Category === "Resets"
								? "Changes saved progression. Review the target before confirming."
								: "Runs this action once on the selected player.",
	};
}

function canonical(raw: unknown, commands: Record<string, unknown>): string | undefined {
	if (!typeIs(raw, "string")) {
		return undefined;
	}
	const normalized = raw.gsub("^%s*(.-)%s*$", "%1")[0].lower();
	for (const [id] of pairs(commands)) {
		if (id.lower() === normalized) {
			return id;
		}
	}
	return undefined;
}

function validate(
	command: string,
	definition: Definition,
	raw: unknown,
	option: unknown,
): LuaTuple<[number | undefined, string?]> {
	const rule = describe(command, definition);
	if (isSet(definition.Option) && (!typeIs(option, "string") || option === "")) {
		return $tuple(undefined, "Choose the required option.");
	}
	if (!rule.UsesAmount) {
		return $tuple(1);
	}
	const amount = tonumber(raw);
	if (amount === undefined || amount !== amount || amount === math.huge || amount === -math.huge) {
		return $tuple(undefined, "Amount must be a finite number.");
	}
	if (amount < rule.Minimum || amount > rule.Maximum) {
		return $tuple(undefined, `Amount must be between ${rule.Minimum} and ${rule.Maximum}.`);
	}
	if (rule.Integer && amount !== math.floor(amount)) {
		return $tuple(undefined, "This command requires a whole number.");
	}
	return $tuple(amount);
}

export = { describe, canonical, validate };
