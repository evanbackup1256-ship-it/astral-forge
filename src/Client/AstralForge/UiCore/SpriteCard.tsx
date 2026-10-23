// Purpose: rarity tint shared by the revamp sprite cards (Inventory's PortSpriteCard, the Companions page,
// the Session panel's best-drop tile). The card components themselves stay page-local.
import { Palette } from "../CoreKit/theme";
import * as ForgeTheme from "../../../Shared/AstralForge/Shared/ForgeTheme";

export function rarityColor(rarity: string): Color3 {
	return ForgeTheme.Rarity[rarity] ?? Palette.lineSoft;
}
