"""The bosses' script, and a tool that writes it into SharedData.luau.

    python tools/assetgen/boss_dialogue.py

Lines carry text markup that the client's speech box acts out and the voice generator
strips before speaking:

    [shake]..[/]    trembling (rage)            [wave]..[/]    drifting, ghostly
    [glitch]..[/]   flickering, corrupted       [pulse]..[/]   swelling and fading
    [hot]..[/]      the boss's accent colour    [big]..[/]     larger, slammed in
    [whisper]..[/]  small and faint             [slow]..[/]    typed slowly, heavy
    [beat]          a held pause

Keep every line at or under 140 characters including markup.
"""

from __future__ import annotations

import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DATA = os.path.join(ROOT, "src", "Shared", "AstralForge", "Shared", "SharedData.luau")

DIALOGUE = {
    "Warden": {
        "Forming": [
            "[whisper]The seal... is [wave]thinning[/].[/]",
            "Something that was never meant to wake [glitch]is waking[/].",
        ],
        "Awake": [
            "[slow]Who opens[/] [big]the Riftmaw?[/]",
            "I have kept this door [beat] since before your stars had [hot]names[/].",
            "[shake]Turn back.[/] [beat] Or be [glitch]unmade[/].",
        ],
        "Phase2": [
            "You fight like the rift itself. [beat] [hot]Without end.[/]",
            "Then I shall stop being [slow]gentle[/].",
        ],
        "Phase3": [
            "[big][shake]ENOUGH.[/][/]",
            "The door [hot]STAYS SHUT[/]. [beat] Even if I must close it [glitch]with you inside[/].",
        ],
        "Defeat": [
            "[whisper]The seal... was never [wave]mine[/] to keep.[/]",
            "[slow]Go on, then.[/] [beat] See what waits [hot]behind it[/].",
        ],
        "Escape": [
            "The door closes. [beat] [wave]Remember what you could not finish.[/]",
        ],
        "Enrage": ["[shake]You are taking too long.[/] [beat] The door [hot]hungers[/].", "[glitch]ENOUGH GAMES.[/]"],
        "Break": ["[big]Impossible![/]", "The seal... [shake]cracks[/]?"],
        "Hit": [
            "Stay [hot]down[/].",
            "[shake]Do not rise.[/]",
            "Your light is [wave]small[/].",
            "Fall. [beat] [slow]Again.[/]",
            "[glitch]Pathetic.[/]",
        ],
        "Ultimate": {
            "VoidCollapse": ["[big]VOID COLLAPSE.[/]", "[slow]Everything folds [beat] toward nothing.[/]"],
            "Spearfall": ["[big]SPEARFALL.[/]", "[shake]A hundred lines of dark. [beat] Pick one.[/]"],
            "Oblivion": ["[big][shake]OBLIVION.[/][/]", "[glitch]Be [beat] un[beat]made.[/]"],
        },
        "Attack": {
            "Slam": ["[big]KNEEL.[/]", "Fall.", "The floor [hot]remembers[/] weight."],
            "TwinSlam": ["Two fall as [hot]one[/].", "[shake]Both of you.[/]"],
            "GravityWell": ["Come [slow]closer[/].", "The rift will [hot]have you[/].", "[wave]Everything falls inward.[/]"],
            "Lances": ["The seal's own edge. [beat] Cross it and be [hot]cut[/].", "[glitch]Lines of the door.[/]"],
            "Volley": ["The door opens [hot]where you stand[/].", "[shake]Fall through.[/]", "[wave]Rifts, rifts, rifts.[/]"],
            "Summon": ["Rise, [hot]keepers of the door[/].", "Let the dark have [glitch]hands[/].", "[whisper]Come, little shadows.[/]"],
            "Fissure": ["The floor remembers the [hot]door[/].", "[big]Split.[/]", "[slow]Follow the crack...[/]"],
            "Cage": ["Stay. [beat] The seal will [hot]close round you[/].", "[wave]No way out but through me.[/]"],
        },
    },
    "Choir": {
        "Forming": [
            "[wave]A note, held too long, begins to [hot]crack[/].[/]",
            "[whisper]Listen...[/] the hall is [pulse]humming[/].",
        ],
        "Awake": [
            "[wave]Seven voices woke.[/] [beat] One of them is singing [hot]for you[/].",
            "Listen. [beat] Between every note, there is a place to [hot]stand[/].",
            "Find it. [beat] Or we shall sing you [shake]quiet[/].",
        ],
        "Phase2": [
            "[big]Louder.[/] The hall has not heard a true [hot]chord[/] in an age.",
            "[wave]More voices... more... [/][pulse]more[/].",
        ],
        "Phase3": [
            "[shake]All voices -- together --[/] [big]NOW.[/]",
            "[glitch]Let the whole hall shatter with us![/]",
        ],
        "Defeat": [
            "[slow]The hall... falls [wave]silent[/].[/]",
            "It is so [whisper]quiet[/]. [beat] [hot]Thank you.[/]",
        ],
        "Escape": ["[wave]The song goes on without you.[/]"],
        "Enrage": ["[wave]The hall grows [hot]impatient[/].[/]", "[shake]FASTER. LOUDER.[/]"],
        "Break": ["[glitch]Out of... time...[/]", "[big]A false note![/]"],
        "Hit": [
            "[glitch]Out of tune.[/]",
            "[hot]Flat.[/]",
            "That one [wave]rang false[/].",
            "[shake]Sour.[/] Sour!",
            "Again, [slow]but listen this time[/].",
        ],
        "Ultimate": {
            "Crescendo": ["[big]CRESCENDO.[/]", "[wave]Every voice at once -- [beat] [hot]LISTEN[/].[/]"],
            "Requiem": ["[slow]This is your [hot]requiem[/].[/]", "[whisper]Hold still for the last note.[/]"],
            "Finale": ["[big][shake]FINALE.[/][/]", "[glitch]The song ends when [beat] YOU do.[/]"],
        },
        "Attack": {
            "Rings": ["[hot]Hear[/] the rhythm.", "Step between the [pulse]beats[/].", "[wave]One... two... three...[/]"],
            "Dissonance": ["Find the [hot]harmony[/].", "Only the [slow]still[/] notes are safe.", "[glitch]All discord, all at once.[/]"],
            "EchoSlam": ["[wave]Echo... echo... [/][hot]echo[/].", "Struck [pulse]three times[/]. Hear it grow?"],
            "Slam": ["A [shake]sour[/] note.", "[big]Fortissimo.[/]"],
            "Volley": ["[hot]Shatter.[/]", "[wave]Glass rain.[/]", "[glitch]Every note, a blade.[/]"],
            "Starburst": ["A chord, in [hot]every direction[/].", "[big]Bloom.[/]"],
            "Summon": ["My echoes -- [hot]sing for me[/].", "[whisper]Cold little voices... wake.[/]", "[wave]Join the chorus.[/]"],
        },
    },
    "Regent": {
        "Forming": [
            "The embers remember their [hot]king[/].",
            "[wave]Heat rises... [/][shake]as it should.[/]",
        ],
        "Awake": [
            "[big]KNEEL[/] before the last crown of [hot]Emberreach[/].",
            "You trespass on my throne [beat] and expect [slow]mercy?[/]",
            "Let the fire decide [beat] [shake]how long you last.[/]",
        ],
        "Phase2": [
            "You [shake]dare[/] make me bleed? [beat] [hot]Fine.[/]",
            "[slow]Bow to the flame.[/]",
        ],
        "Phase3": [
            "[big][shake]BURN.[/][/] Burn it all -- the throne, the sky, [hot]you[/]!",
            "[glitch]If I fall, the world falls with me![/]",
        ],
        "Defeat": [
            "A king... does not... [slow]fall[/] to...",
            "[whisper]The crown is yours.[/] [beat] It was always [hot]heavy[/].",
        ],
        "Escape": ["I retreat to my [hot]embers[/]. [beat] Not to you."],
        "Enrage": ["[big]MY PATIENCE BURNS.[/]", "[shake]The crown demands [hot]ash[/]![/]"],
        "Break": ["[shake]You... [hot]DARE[/]?[/]", "[big]Insolent embers![/]"],
        "Hit": [
            "[hot]Ash.[/]",
            "[shake]Crawl.[/]",
            "You burn [slow]so brightly[/]. How briefly.",
            "[big]INSOLENT.[/]",
            "Is that all the [hot]fire[/] you carry?",
        ],
        "Ultimate": {
            "Eruption": ["[big]ERUPTION.[/]", "[shake]The mountain remembers [hot]fire[/].[/]"],
            "Cataclysm": ["[big]CATACLYSM.[/]", "[slow]The ground was only ever a [hot]lid[/].[/]"],
            "Ragnarok": ["[big][shake]RAGNAROK.[/][/]", "[glitch]Burn. [beat] Burn. [beat] BURN.[/]"],
        },
        "Attack": {
            "Sweep": ["Run in circles, [hot]little ember[/].", "[wave]The beam turns... and turns...[/]"],
            "Volley": ["[big]Rain, fire![/]", "Every one of you is a [hot]target[/]."],
            "Slam": ["[shake]Crushed.[/]", "[big]Beneath my heel.[/]"],
            "TwinSlam": ["Two! [beat] [hot]Two at once![/]", "[shake]Neither escapes.[/]"],
            "Wall": ["The wall advances. Find the [hot]gap[/] -- or [shake]burn[/].", "[slow]Walk through fire, if you can.[/]"],
            "Meteors": ["The sky is [hot]mine[/] to throw!", "Let the heavens burn [slow]with me[/].", "[big]FALL, STARS.[/]"],
            "Summon": ["Rise, my [hot]cinders[/]!", "Guard the [shake]throne[/]!", "[wave]Ember spirits, attend me.[/]"],
            "Fissure": ["The earth [hot]splits[/] for its king.", "[slow]A river of fire... for you.[/]"],
            "Cage": ["A crown of flame -- [hot]for you[/].", "[shake]Kneel inside it.[/]"],
        },
    },
    "Seraph": {
        "Forming": [
            "The air tastes of [hot]iron[/]. [beat] Something is [pulse]gathering[/].",
            "[whisper]Do you hear the wires of the sky?[/]",
        ],
        "Awake": [
            "I am the storm that was [hot]promised[/].",
            "Every wire of the sky [wave]answers me[/].",
            "[slow]Stand still.[/] [beat] It will be over before the [big]thunder[/].",
        ],
        "Phase2": [
            "You are [hot]quick[/]. [beat] Good. [beat] I am [shake]quicker[/].",
            "[wave]The clouds are gathering their courage.[/]",
        ],
        "Phase3": [
            "[big]THE WHOLE SKY --[/] [shake]COME DOWN![/]",
            "[glitch]Let every cloud break at once![/]",
        ],
        "Defeat": [
            "The clouds... are [wave]parting[/].",
            "[slow]Let the quiet have the sky.[/]",
        ],
        "Escape": ["The storm moves on. [beat] [hot]So will its thunder.[/]"],
        "Enrage": ["[shake]The storm [hot]breaks[/] its leash![/]", "[big]NO MORE WAITING.[/]"],
        "Break": ["[glitch]Grounded...?[/]", "[shake]Impossible![/]"],
        "Hit": [
            "[hot]Too slow.[/]",
            "[shake]Feel that?[/]",
            "You are a spark. I am the [big]STORM[/].",
            "[glitch]Static.[/]",
            "Flinch. [beat] [slow]Go on.[/]",
        ],
        "Ultimate": {
            "Judgment": ["[big]JUDGMENT.[/]", "[wave]Stand in the light and be [hot]weighed[/].[/]"],
            "Tempest": ["[big]TEMPEST.[/]", "[shake]Every cloud I own -- [beat] at once.[/]"],
            "Wrath": ["[big][shake]WRATH.[/][/]", "[glitch]I am the storm that [beat] ENDS storms.[/]"],
        },
        "Attack": {
            "Volley": ["[hot]Lightning[/] finds you.", "[shake]Strike, strike, strike![/]", "[glitch]Fork and flash.[/]"],
            "Lances": ["Arcs of the sky -- [big]cut![/]", "[hot]Rails of lightning.[/]"],
            "Fissure": ["Thunder [hot]runs[/] to you.", "[slow]Follow the light to its end.[/]", "[big]CRACK.[/]"],
            "Starburst": ["[big]Burst, storm.[/]", "[wave]In all directions.[/]"],
            "Summon": ["Little sparks, [hot]take wing[/].", "[shake]Fly, my storm-children.[/]", "[wave]Come, come, come.[/]"],
            "Meteors": ["Let the sky fall in [hot]bolts[/].", "Every cloud is a [shake]hammer[/].", "[big]RAIN.[/]"],
            "Cage": ["A cage of [hot]thunder[/].", "[glitch]There is nowhere to run.[/]"],
        },
    },
    "Rime": {
        "Forming": [
            "[wave]Ice creaks.[/] [beat] Something very [slow]old[/] is turning over.",
            "[whisper]Snow falls upward here.[/]",
        ],
        "Awake": [
            "I have waited under the snow for [hot]ten thousand winters[/].",
            "You are [wave]warm[/]. [beat] Warm things do not last here.",
            "[slow]Sleep.[/] [beat] I will [hot]keep[/] you.",
        ],
        "Phase2": [
            "The cold is [hot]patient[/]. [beat] [shake]I am not.[/]",
            "[wave]Frost on your breath... on your blade...[/]",
        ],
        "Phase3": [
            "[big]FREEZE.[/] [shake]FREEZE.[/] [glitch]EVERYTHING FREEZE.[/]",
            "[slow]Let the world forget the sun.[/]",
        ],
        "Defeat": [
            "I am... [wave]cracking[/].",
            "[whisper]Spring... was so far away.[/]",
        ],
        "Escape": ["I sink back into the ice. [beat] It will [hot]keep[/]."],
        "Enrage": ["[slow]The frost... [hot]hardens[/].[/]", "[shake]WINTER WILL NOT WAIT.[/]"],
        "Break": ["[wave]A crack... in the ice...[/]", "[big]No![/]"],
        "Hit": [
            "[hot]Brittle.[/]",
            "[wave]Numb yet?[/]",
            "Your heat is [slow]leaving you[/].",
            "[shake]Slower.[/] You are slowing.",
            "[whisper]So tired...[/]",
        ],
        "Ultimate": {
            "Whiteout": ["[big]WHITEOUT.[/]", "[whisper]No sky. [beat] No ground. [beat] Only [hot]cold[/].[/]"],
            "AbsoluteZero": ["[big]ABSOLUTE ZERO.[/]", "[slow]Even motion [beat] stops.[/]"],
            "DeepWinter": ["[big][shake]DEEP WINTER.[/][/]", "[slow]Sleep. [beat] I will keep you [hot]forever[/].[/]"],
        },
        "Attack": {
            "Cage": ["Be [slow]still[/]. Be [hot]kept[/].", "[wave]Walls of winter.[/]", "[big]CLOSE.[/]"],
            "Rings": ["The frost spreads in [hot]rings[/].", "[wave]Ripples of cold.[/]"],
            "Volley": ["[hot]Icicles.[/] One for each of you.", "[shake]Needles of winter.[/]"],
            "Dissonance": ["Only the pockets of [hot]warmth[/] survive.", "[slow]Find the last fire.[/]"],
            "Starburst": ["Frost, [hot]bloom[/].", "[wave]A snowflake, grown huge.[/]"],
            "Summon": ["My frozen children -- [hot]wake[/].", "[whisper]Cold little guardians.[/]", "[wave]Rise from the snow.[/]"],
            "Meteors": ["[big]Hail.[/]", "The sky is full of [shake]knives[/].", "[slow]It all comes down.[/]"],
            "GravityWell": ["Come into the [hot]cold[/].", "[wave]Everything drifts to winter.[/]", "[slow]Settle... settle...[/]"],
        },
    },
    "Knight": {
        "Forming": [
            "[wave]Armour assembles itself out of nothing.[/]",
            "[whisper]A blade, drawn from the dark.[/]",
        ],
        "Awake": [
            "I swore an oath to the [hot]space between stars[/].",
            "No crown. [beat] No name. [beat] [slow]Only the blade.[/]",
            "[big]Draw.[/] [beat] Let us see what you are [hot]made of[/].",
        ],
        "Phase2": [
            "You have earned my [hot]full attention[/].",
            "[whisper]Few ever did.[/]",
        ],
        "Phase3": [
            "[shake]NO MORE HONOUR.[/] [beat] [big]ONLY THE DARK.[/]",
            "[glitch]I will be nothing -- and nothing cannot be cut![/]",
        ],
        "Defeat": [
            "A good... [slow]duel[/].",
            "The oath is ended. [beat] [hot]The dark is yours.[/]",
        ],
        "Escape": ["We will finish this [hot]another night[/]."],
        "Enrage": ["[hot]No more games.[/]", "[shake]I tire of this duel.[/]"],
        "Break": ["[shake]A clean cut...[/]", "[hot]Well struck.[/]"],
        "Hit": [
            "[hot]Unguarded.[/]",
            "[slow]Again.[/]",
            "[shake]Your stance is weak.[/]",
            "Sloppy. [beat] [hot]Try harder.[/]",
            "[wave]Is that your best?[/]",
        ],
        "Ultimate": {
            "Duel": ["[big]EN GARDE.[/]", "[wave]Dance well. [beat] It is your last.[/]"],
            "LastCut": ["[big]THE LAST CUT.[/]", "[slow]I only ever need [hot]one[/].[/]"],
            "Execution": ["[big][shake]EXECUTION.[/][/]", "[glitch]The sentence is [beat] passed.[/]"],
        },
        "Attack": {
            "Fissure": ["[hot]One cut.[/]", "The blade [slow]reaches[/].", "[big]FOLLOW.[/]"],
            "TwinSlam": ["[hot]Twice.[/]", "[shake]Two strokes.[/]"],
            "Sweep": ["[wave]Turn with me.[/]", "[slow]The whole arc.[/]"],
            "Summon": ["Shades, [hot]to arms[/].", "[whisper]Shadows... attend.[/]", "[wave]Rise, my lost companions.[/]"],
            "Cage": ["No [hot]retreat[/].", "[slow]Enclosed.[/]", "[glitch]The circle closes.[/]"],
            "Wall": ["A wall of night -- find the [hot]gap[/].", "[shake]Walk through the dark.[/]"],
            "Starburst": ["From the heart, [hot]outward[/].", "[big]Bloom, void.[/]"],
            "Lances": ["[hot]Lines[/] of the void.", "[glitch]Cut. Cut. Cut.[/]"],
            "Meteors": ["The dark [hot]rains[/] down.", "[slow]Let it fall.[/]", "[big]ALL OF IT.[/]"],
        },
    },
    "Astraeon": {
        "Forming": [
            "[whisper]Something vast is... [wave]remembering itself[/].[/]",
            "The air [pulse]hums[/] with an old, enormous light.",
        ],
        "Awake": [
            "[slow]A star[/] [beat] remembers what it was.",
            "I was the light that taught your sky to [hot]shine[/]. [beat] Now I am only its [shake]ending[/].",
            "[big]Come, small fires.[/] [beat] Burn with me.",
        ],
        "Phase2": [
            "You are brighter than I [hot]expected[/].",
            "Then let me show you [slow]what light does[/] when it is [shake]angry[/].",
        ],
        "Phase3": [
            "[big]THE SKY FALLS[/] [beat] when I do.",
            "[glitch]Every star I ever lit -- I take them BACK.[/]",
        ],
        "Defeat": [
            "[whisper]I was never... meant to... [wave]shine[/]...[/]",
            "[slow]Thank you. [beat] The dark is [hot]gentle[/].[/]",
        ],
        "Escape": ["The dark takes me back. [beat] [hot]For now.[/]"],
        "Enrage": ["[big]ENOUGH LIGHT.[/] [beat] [shake]LET THERE BE ENDING.[/]", "[glitch]I will not fade for [hot]you[/].[/]"],
        "Break": ["[shake]A crack... in my [hot]crown[/]?[/]", "[big]Impossible.[/] [beat] I am [hot]eternal[/]."],
        "Hit": [
            "[hot]A spark.[/]",
            "[slow]You cannot dim what burns for ages.[/]",
            "[shake]Small. So small.[/]",
            "[wave]Do you hear the sky laughing?[/]",
            "[big]Again.[/] [beat] Try again.",
        ],
        "Attack": {
            "Slam": ["[big]FALL.[/]", "[shake]Beneath a star.[/]"],
            "Volley": ["[hot]Starfire[/], falling.", "[shake]Rain, little suns.[/]"],
            "Fissure": ["The ground [hot]splits[/] for light.", "[slow]Follow the crack to its end.[/]"],
            "Cage": ["A [hot]cage[/] of dying suns.", "[glitch]No way out but through me.[/]"],
            "Starburst": ["[big]Bloom.[/]", "[wave]Every direction at once.[/]"],
            "Rings": ["[wave]Ripples of a [hot]dying[/] sun.[/]", "[slow]Mind the gaps. [beat] If you can.[/]"],
            "Lances": ["Beams of [hot]old light[/].", "[shake]Cut.[/]"],
            "Summon": ["[wave]Embers of my [hot]last[/] fire.[/]", "Rise, [hot]little suns[/]."],
            "Meteors": ["The sky is [hot]mine[/] to throw.", "[big]STARFALL.[/]"],
            "GravityWell": ["[slow]Everything falls toward the light.[/]", "[wave]Come closer.[/]"],
        },
        "Ultimate": {
            "Starfall": ["[big]STARFALL.[/] [beat] [slow]Run.[/]", "[shake]Every star I ever lit -- falls.[/]"],
            "Supernova": ["[big]SUPERNOVA.[/]", "[slow]Find the dark. [beat] Hide in the [hot]dark[/].[/]"],
            "EventHorizon": ["[big]EVENT HORIZON.[/]", "[wave]Nothing leaves. [beat] Not even light.[/]"],
            "AnnihilationBeam": ["[big]ANNIHILATION.[/]", "[shake]One line of light. [beat] Let it find you.[/]"],
            "LastLight": ["[big][shake]LAST LIGHT.[/][/]", "[glitch]If I end -- [beat] so does EVERYTHING.[/]"],
        },
    },}


try:
    from boss_script import SCRIPT
except ImportError:
    SCRIPT = {}
for _kind, _over in SCRIPT.items():
    DIALOGUE.setdefault(_kind, {}).update(_over)


def lua_string(text: str) -> str:
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def lua_list(lines: list[str], indent: str) -> str:
    return "{ " + ", ".join(lua_string(line) for line in lines) + " }"


def render(kind: str) -> str:
    script = DIALOGUE[kind]
    out = ["Dialogue = {"]
    for key in ("Forming", "Awake", "Phase2", "Phase3", "Defeat", "Escape", "Enrage", "Break", "Hit"):
        out.append(f"\t\t{key} = {lua_list(script[key], '')},")
    for key in ("Stagger", "Idle"):
        if key in script:
            out.append(f"\t\t{key} = {lua_list(script[key], '')},")
    if "Ultimate" in script:
        out.append("\t\tUltimate = {")
        for name, lines in script["Ultimate"].items():
            out.append(f"\t\t\t{name} = {lua_list(lines, '')},")
        out.append("\t\t},")
    out.append("\t\tAttack = {")
    for attack, lines in script["Attack"].items():
        out.append(f"\t\t\t{attack} = {lua_list(lines, '')},")
    out.append("\t\t},")
    out.append("\t},")
    return "\n".join(out)


def apply() -> None:
    with open(DATA, "r", encoding="utf-8", newline="") as handle:
        source = handle.read()
    crlf = "\r\n" in source
    text = source.replace("\r\n", "\n")
    result = []
    cursor = 0
    for match in re.finditer(r'Kind = "(\w+)",\s*\n(?:(?!\n\}\)|\n\}\n).)*?\tDialogue = \{', text, re.S):
        kind = match.group(1)
        if kind not in DIALOGUE:
            continue
        start = match.end() - len("Dialogue = {")
        depth, index = 1, match.end()
        while depth > 0:
            char = text[index]
            depth += (char == "{") - (char == "}")
            index += 1
        # swallow the trailing comma the block ends with
        end = index + 1 if text[index] == "," else index
        result.append(text[cursor:start])
        result.append(render(kind))
        cursor = end
    result.append(text[cursor:])
    text = "".join(result)
    if crlf:
        text = text.replace("\n", "\r\n")
    with open(DATA, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)
    print("dialogue written for", ", ".join(DIALOGUE))


if __name__ == "__main__":
    apply()
