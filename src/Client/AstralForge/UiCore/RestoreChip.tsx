import React from "@rbxts/react";
import { Palette } from "../CoreKit/theme";
import { useFlipperSpring } from "../MotionKit/motion";

const UserInputService = game.GetService("UserInputService");

const CHIP_H = 36;
const KEY_H = 22;
const IDLE_SECONDS = 2.4;
const WAKE_BAND = 160;
const LABEL_FONT = Font.fromEnum(Enum.Font.BuilderSansMedium);
const KEY_FONT = Font.fromEnum(Enum.Font.BuilderSansBold);

function keyboardGlyph(): string {
  const [ok, glyph] = pcall(() =>
    UserInputService.GetStringForKeyCode(Enum.KeyCode.Backquote),
  );
  return ok && typeIs(glyph, "string") && glyph !== "" ? glyph : "`";
}

// Hiding the interface is for a clean view, so the way back stays out of the picture: it shows for a
// moment, then fades until the pointer comes near the top edge or the player taps or presses a key.
export function RestoreChip(props: {
  hidden: boolean;
  shown: React.Binding<number>;
  topPad: number;
  input: "keyboard" | "gamepad" | "touch";
  reducedMotion?: boolean;
  onRestore: () => void;
}) {
  const [hovered, setHovered] = React.useState(false);
  const [awake, setAwake] = React.useState(true);
  const hover = useFlipperSpring(hovered ? 1 : 0, props.reducedMotion, 520, 36);
  const wake = useFlipperSpring(
    awake || hovered ? 1 : 0,
    props.reducedMotion,
    260,
    30,
  );
  React.useEffect(() => {
    if (!props.hidden) {
      setAwake(true);
      return undefined;
    }
    let job: thread | undefined;
    const nudge = () => {
      setAwake(true);
      if (job !== undefined) {
        pcall(task.cancel, job);
      }
      job = task.delay(IDLE_SECONDS, () => setAwake(false));
    };
    nudge();
    const moved = UserInputService.InputChanged.Connect((input) => {
      if (
        input.UserInputType === Enum.UserInputType.MouseMovement &&
        input.Position.Y < props.topPad + WAKE_BAND
      ) {
        nudge();
      }
    });
    const pressed = UserInputService.InputBegan.Connect((input) => {
      if (
        input.UserInputType === Enum.UserInputType.Touch ||
        input.UserInputType === Enum.UserInputType.Keyboard ||
        input.UserInputType === Enum.UserInputType.Gamepad1
      ) {
        nudge();
      }
    });
    return () => {
      moved.Disconnect();
      pressed.Disconnect();
      if (job !== undefined) {
        pcall(task.cancel, job);
      }
    };
  }, [props.hidden, props.topPad]);
  const key =
    props.input === "keyboard"
      ? keyboardGlyph()
      : props.input === "gamepad"
        ? "View"
        : undefined;
  // the chip fades as one image: fill, rim and label separately would leave a hollow outline mid-fade
  return (
    <imagebutton
      Size={UDim2.fromOffset(0, CHIP_H)}
      AutomaticSize={Enum.AutomaticSize.X}
      AnchorPoint={new Vector2(0.5, 0)}
      Position={props.shown.map(
        (amount) =>
          new UDim2(
            0.5,
            0,
            0,
            -CHIP_H - 12 + amount * (props.topPad + CHIP_H + 22),
          ),
      )}
      Visible={props.shown.map((amount) => amount > 0.01)}
      BackgroundTransparency={1}
      BorderSizePixel={0}
      AutoButtonColor={false}
      Image=""
      ZIndex={200}
      Event={{
        Activated: props.onRestore,
        MouseEnter: () => setHovered(true),
        MouseLeave: () => setHovered(false),
      }}
    >
      <canvasgroup
        Size={UDim2.fromOffset(0, CHIP_H)}
        AutomaticSize={Enum.AutomaticSize.X}
        GroupTransparency={wake.map((amount) => 1 - amount)}
        Visible={wake.map((amount) => amount > 0.005)}
        BackgroundColor3={hover.map((amount) =>
          Palette.panel.Lerp(Palette.panelRaised, amount),
        )}
        BackgroundTransparency={0.04}
        BorderSizePixel={0}
        ZIndex={200}
      >
        <uicorner CornerRadius={new UDim(0, CHIP_H / 2)} />
        <frame
          Size={new UDim2(1, -2, 1, -2)}
          Position={UDim2.fromOffset(1, 1)}
          BackgroundTransparency={1}
          BorderSizePixel={0}
          ZIndex={203}
        >
          <uicorner CornerRadius={new UDim(0, CHIP_H / 2 - 1)} />
          <uistroke
            Color={Palette.cream}
            Transparency={hover.map((amount) => 0.82 - amount * 0.34)}
            Thickness={1}
            ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
          />
        </frame>
        <frame
          Size={UDim2.fromOffset(0, CHIP_H)}
          AutomaticSize={Enum.AutomaticSize.X}
          BackgroundTransparency={1}
          BorderSizePixel={0}
          ZIndex={201}
        >
          <uipadding
            PaddingLeft={new UDim(0, 16)}
            PaddingRight={new UDim(0, key !== undefined ? 7 : 16)}
          />
          <uilistlayout
            FillDirection={Enum.FillDirection.Horizontal}
            VerticalAlignment={Enum.VerticalAlignment.Center}
            Padding={new UDim(0, 10)}
            SortOrder={Enum.SortOrder.LayoutOrder}
          />
          <textlabel
            Size={UDim2.fromOffset(0, CHIP_H)}
            AutomaticSize={Enum.AutomaticSize.X}
            BackgroundTransparency={1}
            Text="Show interface"
            FontFace={LABEL_FONT}
            TextSize={14}
            TextColor3={Palette.cream}
            TextYAlignment={Enum.TextYAlignment.Center}
            LayoutOrder={1}
            ZIndex={201}
          />
          {key !== undefined && (
            <frame
              Size={UDim2.fromOffset(KEY_H, KEY_H)}
              AutomaticSize={
                key.size() > 1 ? Enum.AutomaticSize.X : Enum.AutomaticSize.None
              }
              BackgroundColor3={Palette.panelSoft}
              BackgroundTransparency={0.1}
              BorderSizePixel={0}
              LayoutOrder={2}
              ZIndex={201}
            >
              <uicorner CornerRadius={new UDim(0, 6)} />
              <uistroke
                Color={Palette.cream}
                Transparency={0.72}
                Thickness={1}
                ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
              />
              {key.size() > 1 && (
                <uipadding
                  PaddingLeft={new UDim(0, 7)}
                  PaddingRight={new UDim(0, 7)}
                />
              )}
              {key === "`" ? (
                // a font draws the backtick as a speck at this size; the key gets a proper stroke
                <frame
                  Size={UDim2.fromOffset(2, 8)}
                  AnchorPoint={new Vector2(0.5, 0.5)}
                  Position={UDim2.fromScale(0.5, 0.5)}
                  Rotation={-32}
                  BackgroundColor3={Palette.creamSoft}
                  BorderSizePixel={0}
                  ZIndex={202}
                >
                  <uicorner CornerRadius={new UDim(1, 0)} />
                </frame>
              ) : (
                <textlabel
                  Size={
                    key.size() > 1
                      ? UDim2.fromOffset(0, KEY_H)
                      : UDim2.fromScale(1, 1)
                  }
                  AutomaticSize={
                    key.size() > 1
                      ? Enum.AutomaticSize.X
                      : Enum.AutomaticSize.None
                  }
                  BackgroundTransparency={1}
                  Text={key}
                  FontFace={KEY_FONT}
                  TextSize={key.size() > 1 ? 12 : 14}
                  TextColor3={Palette.creamSoft}
                  ZIndex={202}
                />
              )}
            </frame>
          )}
        </frame>
      </canvasgroup>
    </imagebutton>
  );
}
