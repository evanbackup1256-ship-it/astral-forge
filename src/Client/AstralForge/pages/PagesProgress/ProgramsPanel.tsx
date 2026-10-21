// Forge Programs (v8 #8): the rule list and rule builder under the Workshop's Auto-Forge panel.
// Shown once programs unlock (first ascension). Each rule reads as one sentence: when, then do.
import React from "@rbxts/react";
import Programs = require("../../../../Shared/AstralForge/Shared/ForgePrograms");
import { Palette, TapTarget } from "../../CoreKit/theme";
import { loadUi } from "../luauDeps";

const { Button, Dropdown, Panel, Text } = loadUi();

type Dispatch = (action: unknown, payload: unknown, reply?: (response: unknown) => void) => unknown;

interface Rule {
	When: string;
	Do: string;
	Arg?: number;
	Enabled: boolean;
}
export interface ProgramsState {
	ForgePrograms?: { Unlocked: boolean; Rules: Rule[]; Max: number; Paused?: boolean };
}

const PAD = 14;
const ROW_H = TapTarget;
const ROW_GAP = 6;

function builderHeight(stack: boolean): number {
	return stack ? TapTarget * 3 + 16 : TapTarget;
}

export function programsPanelHeight(state: ProgramsState, stack: boolean): number {
	const programs = state.ForgePrograms;
	if (programs === undefined || !programs.Unlocked) return 0;
	const rows = programs.Rules.size();
	const builder = rows < programs.Max ? builderHeight(stack) + 10 : 0;
	return PAD * 2 + 26 + rows * (ROW_H + ROW_GAP) + builder;
}

function sentence(rule: Rule): string {
	const action = Programs.actionOf(rule.Do);
	const when = Programs.whenOf(rule.When);
	const arg = when?.Arg !== undefined ? ` ${rule.Arg ?? when.Arg.Default} ${when.Arg.Label}` : "";
	return `${when?.Name ?? rule.When}${arg}: ${string.lower(action?.Name ?? rule.Do)}`;
}

function RuleRow(props: { rule: Rule; index: number; dispatch: Dispatch; reducedMotion?: boolean; y: number }) {
	const on = props.rule.Enabled !== false;
	return (
		<frame Size={new UDim2(1, 0, 0, ROW_H)} Position={UDim2.fromOffset(0, props.y)} BackgroundTransparency={1} BorderSizePixel={0}>
			<Text
				value={sentence(props.rule)}
				size={13}
				color={on ? Palette.cream : Palette.muted}
				fit={true}
				minSize={10}
				sizeConstraint={new UDim2(1, -(96 + 8 + TapTarget + 8), 1, 0)}
			/>
			<Button
				text={on ? "On" : "Off"}
				onClick={() => props.dispatch("ProgramAct", { Op: "Toggle", Index: props.index })}
				color={on ? Palette.mint : Palette.panelSoft}
				textColor={on ? Palette.ink : Palette.cream}
				outline={!on}
				size={UDim2.fromOffset(96, TapTarget)}
				position={new UDim2(1, -(96 + 8 + TapTarget), 0, 0)}
				reducedMotion={props.reducedMotion}
			/>
			<Button
				text=""
				icon="Close.7"
				onClick={() => props.dispatch("ProgramAct", { Op: "Delete", Index: props.index })}
				color={Palette.panelSoft}
				textColor={Palette.cream}
				outline={true}
				size={UDim2.fromOffset(TapTarget, TapTarget)}
				position={new UDim2(1, -TapTarget, 0, 0)}
				reducedMotion={props.reducedMotion}
			/>
		</frame>
	);
}

function Builder(props: { dispatch: Dispatch; stack: boolean; reducedMotion?: boolean; y: number }) {
	const [doId, setDo] = React.useState(Programs.ACTIONS[0].Id);
	const action = Programs.actionOf(doId) ?? Programs.ACTIONS[0];
	const [whenId, setWhen] = React.useState(action.Whens[0]);
	const when = Programs.whenOf(action.Whens.includes(whenId) ? whenId : action.Whens[0]) ?? Programs.WHENS[0];
	const [arg, setArg] = React.useState<number | undefined>(undefined);
	const value = when.Arg !== undefined ? math.clamp(arg ?? when.Arg.Default, when.Arg.Min, when.Arg.Max) : undefined;
	const step = (delta: number) => {
		if (when.Arg === undefined || value === undefined) return;
		setArg(math.clamp(value + delta * when.Arg.Step, when.Arg.Min, when.Arg.Max));
	};
	const save = () => props.dispatch("ProgramAct", { Op: "Save", Rule: { Do: action.Id, When: when.Id, Arg: value, Enabled: true } });
	const third = props.stack ? new UDim2(1, 0, 0, TapTarget) : new UDim2(1 / 3, -8, 0, TapTarget);
	const at = (i: number) => (props.stack ? UDim2.fromOffset(0, i * (TapTarget + 8)) : new UDim2(i / 3, i * 4, 0, 0));
	return (
		<frame Size={new UDim2(1, 0, 0, builderHeight(props.stack))} Position={UDim2.fromOffset(0, props.y)} BackgroundTransparency={1} BorderSizePixel={0}>
			<Dropdown
				options={Programs.ACTIONS.map((a) => ({ id: a.Id, label: a.Name }))}
				value={action.Id}
				onChange={(id: string) => {
					setDo(id);
					setArg(undefined);
					const picked = Programs.actionOf(id);
					if (picked !== undefined) setWhen(picked.Whens[0]);
				}}
				accent={Palette.coral}
				size={third}
				position={at(0)}
				reducedMotion={props.reducedMotion}
				zIndex={46}
			/>
			<Dropdown
				options={action.Whens.map((id) => ({ id, label: Programs.whenOf(id)?.Name ?? id }))}
				value={when.Id}
				onChange={(id: string) => {
					setWhen(id);
					setArg(undefined);
				}}
				accent={Palette.coral}
				size={third}
				position={at(1)}
				reducedMotion={props.reducedMotion}
				zIndex={44}
			/>
			<frame Size={third} Position={at(2)} BackgroundTransparency={1} BorderSizePixel={0}>
				{value !== undefined && (
					<>
						<Button text="-" onClick={() => step(-1)} color={Palette.panelSoft} textColor={Palette.cream} outline={true} size={UDim2.fromOffset(TapTarget, TapTarget)} reducedMotion={props.reducedMotion} />
						<Text
							value={tostring(value)}
							size={14}
							color={Palette.cream}
							align={Enum.TextXAlignment.Center}
							position={UDim2.fromOffset(TapTarget, 0)}
							sizeConstraint={new UDim2(0, 48, 1, 0)}
						/>
						<Button
							text="+"
							onClick={() => step(1)}
							color={Palette.panelSoft}
							textColor={Palette.cream}
							outline={true}
							size={UDim2.fromOffset(TapTarget, TapTarget)}
							position={UDim2.fromOffset(TapTarget + 48, 0)}
							reducedMotion={props.reducedMotion}
						/>
					</>
				)}
				<Button
					text="Add rule"
					onClick={save}
					color={Palette.coral}
					textColor={Palette.ink}
					size={new UDim2(1, value !== undefined ? -(TapTarget * 2 + 56) : 0, 0, TapTarget)}
					position={value !== undefined ? UDim2.fromOffset(TapTarget * 2 + 56, 0) : UDim2.fromOffset(0, 0)}
					reducedMotion={props.reducedMotion}
				/>
			</frame>
		</frame>
	);
}

export function ProgramsPanel(props: { state: ProgramsState; dispatch: Dispatch; stack: boolean; reducedMotion?: boolean }) {
	const programs = props.state.ForgePrograms;
	if (programs === undefined || !programs.Unlocked) return undefined;
	const rules = programs.Rules;
	const top = 26;
	return (
		<Panel size={UDim2.fromScale(1, 1)} accent={Palette.coral} background={Palette.panelRaised} padding={PAD} reducedMotion={props.reducedMotion} clips={false}>
			<Text
				value={programs.Paused === true ? "Programs are paused for a moment" : `Programs  ${rules.size()}/${programs.Max}`}
				size={14}
				color={programs.Paused === true ? Palette.mango : Palette.cream}
				weight={Enum.FontWeight.Bold}
				sizeConstraint={new UDim2(1, 0, 0, 20)}
			/>
			{rules.map((rule, i) => (
				<RuleRow key={`${i}:${rule.Do}`} rule={rule} index={i + 1} dispatch={props.dispatch} reducedMotion={props.reducedMotion} y={top + i * (ROW_H + ROW_GAP)} />
			))}
			{rules.size() < programs.Max && (
				<Builder dispatch={props.dispatch} stack={props.stack} reducedMotion={props.reducedMotion} y={top + rules.size() * (ROW_H + ROW_GAP) + 4} />
			)}
		</Panel>
	);
}
