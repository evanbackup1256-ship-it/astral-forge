// Forge Programs (v8 #8): the rule list and rule builder under the Workshop's Auto-Forge panel.
// Shown once programs unlock (first ascension). Each rule reads as one sentence: when, then do.
import React from "@rbxts/react";
import Programs = require("../../../../Shared/AstralForge/Shared/ForgePrograms");
import { Palette, TapTarget } from "../../CoreKit/theme";
import { loadUi } from "../luauDeps";
import { MockPanel, PanelHeading } from "../../UiCore/mockKit";
import { headingBlock, MockBtn, MockRow, panelHeight, rowHeight, SEC } from "../mockRows";

const { Button, Dropdown, Text } = loadUi();

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

// 03-forge .pn with .row rules: 48px rows (44 phone), 12/8 gap
const rowH = (stack: boolean) => rowHeight(stack);
const gapOf = (stack: boolean) => (stack ? 8 : 12);

// phones: action, trigger, amount and "Add rule" each get their own row
function builderHeight(stack: boolean): number {
	return stack ? TapTarget * 4 + 24 : TapTarget;
}

// the On/Off toggle narrows on phones so the rule sentence keeps its room
function toggleWidth(stack: boolean): number {
	return stack ? 64 : 96;
}

export function programsPanelHeight(state: ProgramsState, stack: boolean): number {
	const programs = state.ForgePrograms;
	if (programs === undefined || !programs.Unlocked) return 0;
	const rows = programs.Rules.size();
	const g = gapOf(stack);
	const builder = rows < programs.Max ? builderHeight(stack) + g : 0;
	return panelHeight(stack, headingBlock(stack) + rows * (rowH(stack) + g) - (rows > 0 && builder === 0 ? g : 0) + builder);
}

function sentence(rule: Rule): string {
	const action = Programs.actionOf(rule.Do);
	const when = Programs.whenOf(rule.When);
	const arg = when?.Arg !== undefined ? ` ${rule.Arg ?? when.Arg.Default} ${when.Arg.Label}` : "";
	return `${when?.Name ?? rule.When}${arg}: ${string.lower(action?.Name ?? rule.Do)}`;
}

function RuleRow(props: { rule: Rule; index: number; dispatch: Dispatch; reducedMotion?: boolean; layoutOrder: number; stack: boolean }) {
	const on = props.rule.Enabled !== false;
	const toggleW = toggleWidth(props.stack);
	const btn = props.stack ? TapTarget : 36;
	return (
		<MockRow
			phone={props.stack}
			icon="Command"
			accent={Palette.coral}
			dim={!on}
			title={sentence(props.rule)}
			layoutOrder={props.layoutOrder}
			rightWidth={toggleW + 8 + btn}
			right={
				<>
					<frame BackgroundTransparency={1} Size={UDim2.fromOffset(toggleW, btn)} LayoutOrder={0}>
						<MockBtn text={on ? "On" : "Off"} accent={Palette.mint} sec={!on} sm={true} phone={props.stack} fill={true} onClick={() => props.dispatch("ProgramAct", { Op: "Toggle", Index: props.index })} reducedMotion={props.reducedMotion} />
					</frame>
					<frame BackgroundTransparency={1} Size={UDim2.fromOffset(btn, btn)} LayoutOrder={1}>
						<Button
							text=""
							icon="Close.7"
							onClick={() => props.dispatch("ProgramAct", { Op: "Delete", Index: props.index })}
							color={SEC}
							textColor={Palette.cream}
							size={UDim2.fromScale(1, 1)}
							reducedMotion={props.reducedMotion}
						/>
					</frame>
				</>
			}
		/>
	);
}

function Builder(props: { dispatch: Dispatch; stack: boolean; reducedMotion?: boolean; layoutOrder: number }) {
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
		<frame Size={new UDim2(1, 0, 0, builderHeight(props.stack))} LayoutOrder={props.layoutOrder} BackgroundTransparency={1} BorderSizePixel={0}>
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
						<Button text="-" onClick={() => step(-1)} color={SEC} textColor={Palette.cream} size={UDim2.fromOffset(TapTarget, TapTarget)} reducedMotion={props.reducedMotion} />
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
							color={SEC}
							textColor={Palette.cream}
							size={UDim2.fromOffset(TapTarget, TapTarget)}
							position={UDim2.fromOffset(TapTarget + 48, 0)}
							reducedMotion={props.reducedMotion}
						/>
					</>
				)}
				{!props.stack && (
					<Button
						text="Add rule"
						onClick={save}
						color={Palette.coral}
						textColor={Palette.ink}
						size={new UDim2(1, value !== undefined ? -(TapTarget * 2 + 56) : 0, 0, TapTarget)}
						position={value !== undefined ? UDim2.fromOffset(TapTarget * 2 + 56, 0) : UDim2.fromOffset(0, 0)}
						reducedMotion={props.reducedMotion}
					/>
				)}
			</frame>
			{props.stack && (
				<Button
					text="Add rule"
					onClick={save}
					color={Palette.coral}
					textColor={Palette.ink}
					size={new UDim2(1, 0, 0, TapTarget)}
					position={at(3)}
					reducedMotion={props.reducedMotion}
				/>
			)}
		</frame>
	);
}

export function ProgramsPanel(props: { state: ProgramsState; dispatch: Dispatch; stack: boolean; reducedMotion?: boolean }) {
	const programs = props.state.ForgePrograms;
	if (programs === undefined || !programs.Unlocked) return undefined;
	const rules = programs.Rules;
	return (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={props.stack} accent={Palette.coral} reducedMotion={props.reducedMotion} name="ForgePrograms">
			<PanelHeading
				icon="Command"
				title="Programs"
				note={programs.Paused === true ? "Paused for a moment" : `${rules.size()} of ${programs.Max}`}
				accent={Palette.coral}
				phone={props.stack}
				layoutOrder={0}
			/>
			{rules.map((rule, i) => (
				<RuleRow key={`${i}:${rule.Do}`} rule={rule} index={i + 1} dispatch={props.dispatch} reducedMotion={props.reducedMotion} layoutOrder={1 + i} stack={props.stack} />
			))}
			{rules.size() < programs.Max && <Builder dispatch={props.dispatch} stack={props.stack} reducedMotion={props.reducedMotion} layoutOrder={100} />}
		</MockPanel>
	);
}
