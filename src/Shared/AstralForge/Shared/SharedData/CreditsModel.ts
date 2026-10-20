type Dict = Record<string, unknown>;

interface Member {
	Name: string;
	DisplayName: string;
	UserId?: number;
	Role: string;
	Note: string;
}
interface Category {
	Id: string;
	Label: string;
	Description: string;
	Accent: string;
	Icon: string;
	EmptyText: string;
	Members: Member[];
}
interface Model {
	Title: string;
	Eyebrow: string;
	Tagline: string;
	ShowVersion: boolean;
	Accent: string;
	CategoryTabs: boolean;
	DefaultCategory: string;
	ShowCategoryCounts: boolean;
	SearchBar: boolean;
	SearchMinMembers: number;
	CardStyle: string;
	ShowAvatars: boolean;
	AvatarShape: string;
	AvatarSize: number;
	ShowUsernames: boolean;
	ShowRoles: boolean;
	ShowNotes: boolean;
	FetchNames: boolean;
	MaxColumns: number;
	CardMinWidth: number;
	CardHoverLift: boolean;
	HideEmptyCategories: boolean;
	DefaultEmptyText: string;
	EntranceStagger: boolean;
	StaggerStep: number;
	Acknowledgements: string[];
	Footer: string;
	Categories: Category[];
}

const CARD_STYLES: Record<string, boolean> = { Card: true, Compact: true };
const AVATAR_SHAPES: Record<string, boolean> = { Rounded: true, Circle: true };

function text(value: unknown, fallback: string): string {
	if (typeIs(value, "string")) {
		return value;
	}
	return fallback;
}

function flag(value: unknown, fallback: boolean): boolean {
	if (typeIs(value, "boolean")) {
		return value;
	}
	return fallback;
}

function num(value: unknown, fallback: number, low: number, high: number): number {
	if (!typeIs(value, "number") || value !== value) {
		return fallback;
	}
	return math.clamp(value, low, high);
}

function normalize(raw: unknown): Model {
	const config = (typeIs(raw, "table") ? raw : {}) as Dict;
	const model: Model = {
		Title: text(config.Title, "ASTRAL FORGE"),
		Eyebrow: text(config.Eyebrow, "CREDITS"),
		Tagline: text(config.Tagline, ""),
		ShowVersion: flag(config.ShowVersion, true),
		Accent: text(config.Accent, "violet"),
		CategoryTabs: flag(config.CategoryTabs, true),
		DefaultCategory: text(config.DefaultCategory, "All"),
		ShowCategoryCounts: flag(config.ShowCategoryCounts, true),
		SearchBar: flag(config.SearchBar, true),
		SearchMinMembers: math.floor(num(config.SearchMinMembers, 6, 0, 1000)),
		CardStyle: CARD_STYLES[config.CardStyle as string] ? (config.CardStyle as string) : "Card",
		ShowAvatars: flag(config.ShowAvatars, true),
		AvatarShape: AVATAR_SHAPES[config.AvatarShape as string] ? (config.AvatarShape as string) : "Rounded",
		AvatarSize: math.floor(num(config.AvatarSize, 64, 40, 96)),
		ShowUsernames: flag(config.ShowUsernames, true),
		ShowRoles: flag(config.ShowRoles, true),
		ShowNotes: flag(config.ShowNotes, true),
		FetchNames: flag(config.FetchNames, true),
		MaxColumns: math.floor(num(config.MaxColumns, 3, 1, 4)),
		CardMinWidth: math.floor(num(config.CardMinWidth, 220, 140, 480)),
		CardHoverLift: flag(config.CardHoverLift, true),
		HideEmptyCategories: flag(config.HideEmptyCategories, true),
		DefaultEmptyText: text(config.DefaultEmptyText, "To be announced."),
		EntranceStagger: flag(config.EntranceStagger, true),
		StaggerStep: num(config.StaggerStep, 0.035, 0, 0.1),
		Acknowledgements: [],
		Footer: text(config.Footer, ""),
		Categories: [],
	};
	if (typeIs(config.Acknowledgements, "table")) {
		for (const [, line] of pairs(config.Acknowledgements as Dict)) {
			if (typeIs(line, "string") && line !== "") {
				model.Acknowledgements.push(line);
			}
		}
	}
	const seen: Record<string, boolean> = {};
	if (typeIs(config.Categories, "table")) {
		for (const [, rawCategory] of pairs(config.Categories as Dict)) {
			const category = rawCategory as Dict;
			if (
				!typeIs(rawCategory, "table") ||
				!typeIs(category.Id, "string") ||
				category.Id === "" ||
				category.Id === "All" ||
				seen[category.Id]
			) {
				continue;
			}
			const id = category.Id as string;
			seen[id] = true;
			const members: Member[] = [];
			if (typeIs(category.Members, "table")) {
				for (const [, rawMember] of pairs(category.Members as Dict)) {
					const member = rawMember as Dict;
					if (!typeIs(rawMember, "table") || !typeIs(member.Name, "string") || member.Name === "") {
						continue;
					}
					const userId =
						typeIs(member.UserId, "number") && member.UserId > 0 ? math.floor(member.UserId) : undefined;
					members.push({
						Name: member.Name as string,
						DisplayName: text(member.DisplayName, member.Name as string),
						UserId: userId,
						Role: text(member.Role, ""),
						Note: text(member.Note, ""),
					});
				}
			}
			model.Categories.push({
				Id: id,
				Label: text(category.Label, id),
				Description: text(category.Description, ""),
				Accent: text(category.Accent, model.Accent),
				Icon: text(category.Icon, "Credits.2"),
				EmptyText: text(category.EmptyText, model.DefaultEmptyText),
				Members: members,
			});
		}
	}
	if (model.DefaultCategory !== "All" && !seen[model.DefaultCategory]) {
		model.DefaultCategory = "All";
	}
	return model;
}

function memberCount(model: Model): number {
	let total = 0;
	for (const category of model.Categories) {
		total += category.Members.size();
	}
	return total;
}

function matches(member: Member, needle: string): boolean {
	if (needle === "") {
		return true;
	}
	for (const field of [member.Name, member.DisplayName, member.Role, member.Note]) {
		if (field.lower().find(needle, 1, true)[0] !== undefined) {
			return true;
		}
	}
	return false;
}

function visible(model: Model, tab: string, query?: string) {
	const needle = (query ?? "").gsub("^%s*(.-)%s*$", "%1")[0].lower();
	const out: { category: Category; members: Member[] }[] = [];
	for (const category of model.Categories) {
		if (tab !== "All" && category.Id !== tab) {
			continue;
		}
		const members: Member[] = [];
		for (const member of category.Members) {
			if (matches(member, needle)) {
				members.push(member);
			}
		}
		if (members.size() === 0 && (needle !== "" || model.HideEmptyCategories)) {
			continue;
		}
		out.push({ category, members });
	}
	return out;
}

function tabs(model: Model) {
	const list: { id: string; label: string; count: number; accent?: string }[] = [
		{ id: "All", label: "All", count: memberCount(model) },
	];
	for (const category of model.Categories) {
		if (category.Members.size() === 0 && model.HideEmptyCategories) {
			continue;
		}
		list.push({ id: category.Id, label: category.Label, count: category.Members.size(), accent: category.Accent });
	}
	return list;
}

function columns(model: Model, width: number, gap: number): number {
	if (model.CardStyle === "Compact") {
		return 1;
	}
	const fit = math.floor((width + gap) / (model.CardMinWidth + gap));
	return math.clamp(fit, 1, model.MaxColumns);
}

function cardHeight(model: Model): number {
	if (model.CardStyle === "Compact") {
		return math.max(44, model.ShowAvatars ? math.min(model.AvatarSize, 48) + 12 : 44);
	}
	const textBlock =
		22 + (model.ShowUsernames ? 16 : 0) + (model.ShowRoles ? 18 : 0) + (model.ShowNotes ? 34 : 0);
	const avatar = model.ShowAvatars ? model.AvatarSize : 0;
	return math.max(avatar, textBlock) + 24;
}

function showSearch(model: Model): boolean {
	return model.SearchBar && memberCount(model) >= model.SearchMinMembers;
}

export = table.freeze({ normalize, memberCount, visible, tabs, columns, cardHeight, showSearch });
