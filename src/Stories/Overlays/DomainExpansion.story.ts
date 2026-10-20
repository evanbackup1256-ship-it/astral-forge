import StoryKit = require("../StoryKit");

type Dict = Record<string, unknown>;
interface DomainBag {
	[key: string]: unknown;
	Rank: number;
	RequiredRebirths: number;
	RequiredCores: number;
	EssenceReward: unknown;
	StardustReward: unknown;
}

const React = StoryKit.React;
const UILabs = StoryKit.UILabs;

const chamber = (
	require(StoryKit.client.WaitForChild("UiOverlays") as ModuleScript) as (name: string) => Record<string, React.FunctionComponent<Dict>>
)("DomainChamber");

const orElse = <T>(value: unknown, fallback: T): T => (value === undefined || value === false ? fallback : (value as T));

export = StoryKit.story(
	{
		name: "Domain expansion",
		summary: "The rite (hold to expand) and the landing.",
		controls: {
			Mode: UILabs.Choose(["confirm", "result"], 1),
			Ready: true,
			Replay: 0,
		},
	},
	(controls, kit) => {
		const domain = table.clone(orElse<Record<string, unknown>>(kit.state.Domain, {})) as DomainBag;
		domain.Rank = orElse(domain.Rank, 4);
		domain.CanExpand = controls.Ready;
		domain.RequiredRebirths = orElse(domain.RequiredRebirths, 20);
		domain.RequiredCores = orElse(domain.RequiredCores, 500);
		domain.EssenceReward = orElse(domain.EssenceReward, 24);
		domain.StardustReward = orElse(domain.StardustReward, 1120);
		domain.Links = orElse(domain.Links, {});
		const ready = controls.Ready !== undefined && controls.Ready !== false;
		return React.createElement(chamber.DomainChamber, {
			key: `${controls.Mode}-${controls.Replay}`,
			mode: controls.Mode,
			domain: domain,
			rebirths: ready ? domain.RequiredRebirths : math.floor(domain.RequiredRebirths * 0.6),
			cores: ready ? domain.RequiredCores : math.floor(domain.RequiredCores * 0.3),
			result:
				controls.Mode === "result"
					? {
							rank: domain.Rank + 1,
							essence: domain.EssenceReward,
							stardust: domain.StardustReward,
							overflow: 0,
							freeSpins: 3,
							nextRebirths: domain.RequiredRebirths * 2,
							nextCores: domain.RequiredCores * 3,
						}
					: undefined,
			busy: false,
			dispatch: kit.dispatch,
			reducedMotion: kit.reducedMotion,
			onConfirm: () => {
				print("[story] domain expansion confirmed");
			},
			onMode: (mode: unknown) => {
				print("[story] mode", mode);
			},
			onClose: () => {
				print("[story] domain overlay closed");
			},
		});
	},
);
