// Crewmates in the world: a small "CREW" tag above each crewmate's head so you can find them.
// 100% React declarative component driven by CrewStore.
import React from "@rbxts/react";
import ReactRoblox from "@rbxts/react-roblox";
import CrewStore = require("./CrewStore");
import { named } from "./lua";

const Players = game.GetService("Players");

interface CrewMember {
	UserId: number;
}
interface CrewShape {
	crew?: { Members?: CrewMember[] };
}

function CrewTag(props: { head: BasePart; name: string }) {
	return (
		<billboardgui
			{...named("AF_CrewTag")}
			Adornee={props.head}
			AlwaysOnTop={true}
			LightInfluence={0}
			MaxDistance={120}
			Size={UDim2.fromOffset(150, 28)}
			StudsOffsetWorldSpace={new Vector3(0, 5.4, 0)}
			ResetOnSpawn={false}
		>
			<textlabel
				key="Pill"
				Size={UDim2.fromScale(1, 1)}
				BackgroundColor3={Color3.fromRGB(28, 70, 52)}
				BackgroundTransparency={0.15}
				TextColor3={Color3.fromRGB(150, 255, 200)}
				FontFace={Font.fromEnum(Enum.Font.BuilderSansBold)}
				TextSize={14}
				TextScaled={true}
				TextTruncate={Enum.TextTruncate.AtEnd}
				Text={"CREW · " + props.name}
			>
				<uitextsizeconstraint key="Fit" MaxTextSize={14} MinTextSize={9} />
				<uipadding key="Pad" PaddingLeft={new UDim(0, 10)} PaddingRight={new UDim(0, 10)} />
				<uicorner key="Corner" CornerRadius={new UDim(1, 0)} />
				<uistroke key="Stroke" Color={Color3.fromRGB(110, 240, 170)} Transparency={0.3} />
			</textlabel>
		</billboardgui>
	);
}

function CrewPresenceTree() {
	const [crewState, setCrewState] = React.useState(() => CrewStore.get());
	const [heads, setHeads] = React.useState<Map<number, { head: BasePart; name: string }>>(new Map());

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
			const nextMap = new Map<number, { head: BasePart; name: string }>();
			for (const member of members) {
				const uid = member.UserId;
				if (uid !== Players.LocalPlayer.UserId) {
					const player = Players.GetPlayerByUserId(uid);
					const char = player && player.Character;
					const head = char && char.FindFirstChild("Head");
					if (head && head.IsA("BasePart")) {
						nextMap.set(uid, { head, name: player!.DisplayName });
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
						const kept = new Map<number, { head: BasePart; name: string }>();
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
		elements["CrewTag_" + tostring(uid)] = <CrewTag head={data.head} name={data.name} />;
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
