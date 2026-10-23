// Crewmates in the world: a nameplate (title-font name plus a rebirths · world chip) above each
// crewmate's head so you can find them.
// 100% React declarative component driven by CrewStore.
import React from "@rbxts/react";
import ReactRoblox from "@rbxts/react-roblox";
import CrewStore = require("./CrewStore");
import { named } from "./lua";
import { Palette } from "./CoreKit/theme";
import { BODY_BOLD, TITLE_FACE } from "./UiCore/mockKit";

const Players = game.GetService("Players");

interface CrewMember {
	UserId: number;
}
interface CrewShape {
	crew?: { Members?: CrewMember[] };
}

// rebirths come from leaderstats, the world from the CurrentZone attribute; both replicate live
function useProgress(player: Player | undefined): [number, number] {
	const read = (): [number, number] => {
		const stats = player && player.FindFirstChild("leaderstats");
		const rebirths = stats && stats.FindFirstChild("Rebirths");
		const zone = player && player.GetAttribute("CurrentZone");
		return [
			rebirths && rebirths.IsA("NumberValue") ? math.floor(rebirths.Value) : 0,
			typeIs(zone, "number") ? math.max(1, math.floor(zone)) : 1,
		];
	};
	const [value, setValue] = React.useState(read);
	React.useEffect(() => {
		if (player === undefined) {
			return undefined;
		}
		const conns: RBXScriptConnection[] = [];
		let statConn: RBXScriptConnection | undefined;
		const update = () => setValue(read());
		const watchStat = () => {
			statConn?.Disconnect();
			const stats = player.FindFirstChild("leaderstats");
			const rebirths = stats && stats.FindFirstChild("Rebirths");
			if (rebirths && rebirths.IsA("NumberValue")) {
				statConn = rebirths.Changed.Connect(update);
			}
			update();
		};
		watchStat();
		conns.push(player.GetAttributeChangedSignal("CurrentZone").Connect(update));
		conns.push(player.ChildAdded.Connect(watchStat));
		conns.push(player.DescendantAdded.Connect((child) => child.Name === "Rebirths" && watchStat()));
		return () => {
			statConn?.Disconnect();
			for (const c of conns) {
				c.Disconnect();
			}
		};
	}, [player]);
	return value;
}

function CrewTag(props: { head: BasePart; name: string; player?: Player }) {
	const [rebirths, zone] = useProgress(props.player);
	// design/28-world: ".chip" with rebirths and world (no world-name lookup on the client, so the number stands in)
	const chipText = `R${rebirths} · World ${zone}`;
	return (
		<billboardgui
			{...named("AF_CrewTag")}
			Adornee={props.head}
			AlwaysOnTop={false}
			LightInfluence={0}
			MaxDistance={60}
			Size={UDim2.fromOffset(200, 58)}
			StudsOffsetWorldSpace={new Vector3(0, 5.4, 0)}
			ResetOnSpawn={false}
		>
			<textlabel
				key="NameDrop"
				Size={new UDim2(1, 0, 0, 24)}
				Position={UDim2.fromOffset(0, 2)}
				BackgroundTransparency={1}
				TextColor3={new Color3(0, 0, 0)}
				FontFace={TITLE_FACE}
				TextSize={18}
				TextTruncate={Enum.TextTruncate.AtEnd}
				Text={props.name}
				ZIndex={1}
			/>
			<textlabel
				key="Name"
				Size={new UDim2(1, 0, 0, 24)}
				BackgroundTransparency={1}
				TextColor3={Palette.cream}
				FontFace={TITLE_FACE}
				TextSize={18}
				TextTruncate={Enum.TextTruncate.AtEnd}
				Text={props.name}
				ZIndex={2}
			/>
			<frame
				key="Chip"
				AnchorPoint={new Vector2(0.5, 0)}
				Position={new UDim2(0.5, 0, 0, 28)}
				Size={UDim2.fromOffset(0, 28)}
				AutomaticSize={Enum.AutomaticSize.X}
				BackgroundColor3={new Color3(1, 1, 1)}
				BackgroundTransparency={0.95}
				ZIndex={2}
			>
				<uicorner key="Corner" CornerRadius={new UDim(0, 8)} />
				<uistroke key="Stroke" Color={new Color3(1, 1, 1)} Transparency={0.9} Thickness={1} />
				<uipadding key="Pad" PaddingLeft={new UDim(0, 10)} PaddingRight={new UDim(0, 10)} />
				<textlabel
					key="Text"
					Size={UDim2.fromScale(0, 1)}
					AutomaticSize={Enum.AutomaticSize.X}
					BackgroundTransparency={1}
					TextColor3={Palette.creamSoft}
					FontFace={BODY_BOLD}
					TextSize={12}
					Text={chipText}
					ZIndex={3}
				/>
			</frame>
		</billboardgui>
	);
}

function CrewPresenceTree() {
	const [crewState, setCrewState] = React.useState(() => CrewStore.get());
	const [heads, setHeads] = React.useState<Map<number, { head: BasePart; name: string; player?: Player }>>(new Map());

	React.useEffect(() => {
		return CrewStore.subscribe((nextState) => {
			setCrewState(nextState);
		});
	}, []);

	React.useEffect(() => {
		let alive = true;
		const updateHeads = () => {
			if (!alive) {
				return;
			}
			const shaped = crewState as CrewShape | undefined;
			const members = (shaped && shaped.crew && shaped.crew.Members) || [];
			const nextMap = new Map<number, { head: BasePart; name: string; player?: Player }>();
			for (const member of members) {
				const uid = member.UserId;
				if (uid !== Players.LocalPlayer.UserId) {
					const player = Players.GetPlayerByUserId(uid);
					const char = player && player.Character;
					const head = char && char.FindFirstChild("Head");
					if (head && head.IsA("BasePart")) {
						nextMap.set(uid, { head, name: player!.DisplayName, player: player! });
					}
				}
			}
			setHeads(nextMap);
		};

		updateHeads();
		const conns: RBXScriptConnection[] = [];
		for (const player of Players.GetPlayers()) {
			if (player !== Players.LocalPlayer) {
				conns.push(
					player.CharacterAdded.Connect(() => {
						task.wait(0.5);
						updateHeads();
					}),
				);
			}
		}
		conns.push(
			Players.PlayerAdded.Connect((player) => {
				conns.push(
					player.CharacterAdded.Connect(() => {
						task.wait(0.5);
						updateHeads();
					}),
				);
			}),
		);

		// a member leaving the server takes their tag with them
		conns.push(
			Players.PlayerRemoving.Connect((leaving) => {
				task.defer(() => {
					if (!alive) {
						return;
					}
					setHeads((current) => {
						if (!current.has(leaving.UserId)) {
							return current;
						}
						const kept = new Map<number, { head: BasePart; name: string; player?: Player }>();
						for (const [uid, data] of current) {
							if (uid !== leaving.UserId) {
								kept.set(uid, data);
							}
						}
						return kept;
					});
				});
			}),
		);

		return () => {
			alive = false;
			for (const c of conns) {
				c.Disconnect();
			}
		};
	}, [crewState]);

	const elements: Record<string, React.Element> = {};
	for (const [uid, data] of heads) {
		elements["CrewTag_" + tostring(uid)] = <CrewTag head={data.head} name={data.name} player={data.player} />;
	}
	return <>{elements}</>;
}

const CrewPresence = {
	attach(this: void): () => void {
		// BillboardGuis only render from PlayerGui (or the world), never nested inside a ScreenGui,
		// so the tags get their own folder rather than mounting into the app's screen
		const playerGui = Players.LocalPlayer.WaitForChild("PlayerGui");
		const host = new Instance("Folder");
		host.Name = "AF_CrewTags";
		host.Parent = playerGui;
		const root = ReactRoblox.createRoot(host);
		root.render(<CrewPresenceTree />);
		return () => {
			root.unmount();
			host.Destroy();
		};
	},
	Component: CrewPresenceTree,
};

export = CrewPresence;
