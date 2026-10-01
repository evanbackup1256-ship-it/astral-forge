"""The bosses' rewritten script: each one has a voice, a history, and an opinion of whoever is fighting them.

Merged over boss_dialogue.DIALOGUE (anything not listed here keeps its old lines, e.g. the ultimates).
Markup as in boss_dialogue.py. `{name}` becomes the fighter's display name (those lines are typed, not voiced).
Extra keys: Stagger (taunts when the fighter is knocked down), Idle (when it has nothing to hit).
"""

SCRIPT = {
    # ------------------------------------------------------------------------------------------------
    # THE RIFT WARDEN. A jailer who has outlived the crime. Courteous, exhausted, bound by an oath he
    # no longer believes in and cannot break. Treats the fight as the last duty of a very long watch.
    "Warden": {
        "Forming": [
            "[whisper]Four hundred winters... and the lock [wave]finally[/] gives.[/]",
            "The dark behind the door has [hot]heard you knocking[/].",
        ],
        "Awake": [
            "[slow]I am the Warden.[/] [beat] I was asked to hold one door. [beat] Just [hot]one[/].",
            "I will not hate you. [beat] Hatred is for those with [wave]time[/].",
            "Come. [beat] Let us do this [slow]properly[/].",
        ],
        "Phase2": [
            "You press the lock the way [hot]he[/] did, the last one who came.",
            "I buried him [beat] under [shake]that[/] floor. [beat] Mind your footing.",
        ],
        "Phase3": [
            "[big]Do you hear it?[/] [beat] The door is [hot]breathing[/].",
            "I [shake]cannot[/] let it open. [beat] Forgive me what I do [glitch]to prevent it[/].",
        ],
        "Defeat": [
            "[whisper]At last... [beat] the watch is [wave]relieved[/].[/]",
            "[slow]Tell whoever comes after:[/] [beat] the door was never locked [hot]against us[/]. [beat] It was locked [hot]for us[/].",
            "[whisper]Don't look back.[/]",
        ],
        "Escape": [
            "[wave]The door is shut again.[/] [beat] I am, [slow]as ever[/], [hot]sorry[/].",
            "Rest. [beat] You will need it [beat] for the [glitch]next time[/].",
        ],
        "Enrage": [
            "[shake]You are stalling the dark.[/] [beat] Every minute [hot]costs the world[/].",
            "[glitch]No more courtesy.[/]",
            "[big]THE OATH DEMANDS IT.[/]",
        ],
        "Break": [
            "[big]Ah![/] [beat] The seal [shake]flinches[/].",
            "You found the [hot]crack[/]. [beat] Clever.",
            "[shake]Not yet, not yet--[/]",
        ],
        "Hit": [
            "Stay [hot]down[/].",
            "That was [slow]not[/] a kindness.",
            "You bleed [hot]light[/]. [beat] I had forgotten.",
            "[shake]Do not rise.[/]",
            "The floor is [wave]patient[/].",
            "I have done this [slow]a thousand times[/].",
            "Smaller. [beat] [hot]Smaller[/].",
            "Fall. [beat] [slow]Again.[/]",
            "Your oath is [wave]thinner[/] than mine.",
            "[glitch]Stop making me do this.[/]",
        ],
        "Stagger": [
            "{name}. [beat] [slow]Stay down.[/] [beat] Please.",
            "I know that sound, {name}. [beat] It is the sound of [hot]trying[/].",
            "Rise if you must, {name}. [beat] I will [slow]wait[/].",
            "{name}... [beat] you remind me of [glitch]someone[/].",
            "[whisper]Easy, {name}. Easy.[/]",
        ],
        "Idle": [
            "[whisper]The door is listening.[/]",
            "[wave]Every key I buried is humming.[/]",
            "You hesitate. [beat] Good. [beat] [slow]Hesitation is wisdom.[/]",
            "[slow]Come.[/] [beat] I am only a [hot]door[/].",
        ],
        "Attack": {
            "Slam": ["[big]KNEEL.[/]", "The floor [hot]remembers[/] weight.", "[slow]Down.[/]", "Forgive the [shake]noise[/]."],
            "TwinSlam": ["Two fall as [hot]one[/].", "[shake]Both of you.[/]", "A door has [hot]two leaves[/]."],
            "GravityWell": ["Come [slow]closer[/].", "[wave]Everything falls inward, eventually.[/]", "The rift will [hot]have you[/]."],
            "Lances": ["The edge of the seal. [beat] [hot]Cross it[/] and be cut.", "[glitch]Lines of the door.[/]", "Mind the [hot]hinges[/]."],
            "Volley": ["The door opens [hot]where you stand[/].", "[shake]Fall through.[/]", "[wave]Rifts, rifts, rifts.[/]", "[slow]Step wherever you like.[/] [beat] It opens there."],
            "Summon": ["Rise, [hot]keepers of the door[/].", "Let the dark have [glitch]hands[/].", "[whisper]Come, little shadows.[/]"],
            "Fissure": ["The floor remembers the [hot]door[/].", "[big]Split.[/]", "[slow]Follow the crack...[/]"],
            "Cage": ["Stay. [beat] The seal will [hot]close round you[/].", "[wave]No way out but through me.[/]", "[slow]A cell is a kindness[/], compared to the door."],
        },
    },
    # ------------------------------------------------------------------------------------------------
    # THE HOLLOW CHOIR. A drowned congregation that sings as one and speaks in its own harmonies.
    # Grieving, eerie, oddly tender; every line is half a lullaby, half a threat.
    "Choir": {
        "Forming": [
            "[whisper]La... [wave]la[/]... [beat] la--[/]",
            "A hundred throats [hot]remember the same note[/].",
        ],
        "Awake": [
            "[wave]We were a hundred voices.[/] [beat] The sea took [hot]ninety-nine[/].",
            "We kept the song. [beat] It is all that [slow]kept us[/].",
            "Sing with us, little [hot]flame[/]. [beat] Or be [wave]the rest[/].",
        ],
        "Phase2": [
            "[hot]Oh.[/] [beat] You can hold a [slow]rhythm[/].",
            "The second verse is [shake]louder[/]. [beat] The second verse [hot]hurts[/].",
        ],
        "Phase3": [
            "[big]TUTTI.[/] [beat] All of us. [beat] [shake]ALL.[/]",
            "[glitch]We remember what the water said.[/]",
        ],
        "Defeat": [
            "[whisper]Quiet... [beat] so [wave]quiet[/]...[/]",
            "[slow]Thank you for the last note.[/] [beat] We never could [hot]finish it[/].",
            "[wave]Hold it... [beat] hold it... [beat] let go.[/]",
        ],
        "Escape": [
            "[wave]We sink, we sink, we [slow]sing[/] beneath.[/]",
            "Hum it for us. [beat] [hot]Just once[/].",
        ],
        "Enrage": [
            "[shake]You are OFF THE BEAT.[/]",
            "[glitch]Tempo. TEMPO. TEMPO.[/]",
            "[big]FORTISSIMO![/]",
        ],
        "Break": [
            "[big]A wrong note![/]",
            "[shake]The chord... [beat] fractures![/]",
            "Who taught you to [hot]strike the rest[/]?",
        ],
        "Hit": [
            "[wave]Flat.[/]",
            "That was [hot]sharp[/], little flame.",
            "[slow]Again, from the top.[/]",
            "Resolve. [beat] [hot]Resolve[/].",
            "[shake]You are off-key.[/]",
            "We have heard that [slow]ending[/] before.",
            "[wave]Diminuendo...[/]",
            "Fall in [hot]time[/].",
            "[glitch]Mi. Re. Do. [beat] Down.[/]",
            "[whisper]Sleep. Sleep. Sleep.[/]",
        ],
        "Stagger": [
            "{name}! [beat] [wave]A grace note![/]",
            "[slow]Shh, {name}.[/] [beat] The floor is a [hot]cradle[/].",
            "Oh, {name}. [beat] You [wave]fell[/] so [slow]beautifully[/].",
            "Stay for the [hot]coda[/], {name}.",
            "[whisper]{name}, {name}, {name}...[/]",
        ],
        "Idle": [
            "[whisper]Do you hear it? [beat] Under the water?[/]",
            "[wave]La... la... [beat] la.[/]",
            "We are [slow]so[/] glad you came.",
            "[glitch]Ninety-nine. [beat] Ninety-nine. [beat] Ninety-nine.[/]",
        ],
        "Attack": {
            "Rings": ["[wave]Ripples, ripples, ripples.[/]", "Hold the [hot]note[/]. [beat] Feel it widen.", "[slow]The sea has rings too.[/]"],
            "Dissonance": ["[glitch]Wrong.[/] [beat] [hot]Wrong.[/] [beat] [shake]WRONG.[/]", "Where it [hot]clashes[/], stand not.", "[wave]Hear the beating between two notes?[/]"],
            "EchoSlam": ["[wave]Echo... [beat] echo... [beat] [hot]echo[/].[/]", "The first blow is only the [slow]announcement[/]."],
            "Slam": ["[big]FORTE.[/]", "A [hot]downbeat[/]."],
            "Volley": ["[wave]Staccato.[/]", "A [hot]scale[/], falling.", "Quick, quick, [slow]slow[/]."],
            "Starburst": ["[big]Radiate.[/]", "[wave]Every voice, a [hot]ray[/].[/]"],
            "Summon": ["Join us, [hot]lost ones[/].", "[whisper]Come up, come up.[/]", "[wave]Sing the others awake.[/]"],
        },
    },
    # ------------------------------------------------------------------------------------------------
    # THE CINDER REGENT. A king of a burnt kingdom. Booming, vain, theatrical; mistakes every fight for a
    # coronation, and every mortal for a subject who forgot to kneel.
    "Regent": {
        "Forming": [
            "[big]LET THE ASH RISE.[/]",
            "[slow]A throne is[/] [hot]heating[/] beneath me.",
        ],
        "Awake": [
            "[big]BEHOLD THE REGENT[/] of nine burning cities!",
            "I wore a crown of a thousand hearths. [beat] I wear them still, [hot]as ash[/].",
            "Kneel, and I may scorch you [slow]gently[/]. [beat] Stand, and I will [shake]make an example[/].",
        ],
        "Phase2": [
            "[shake]You DARE bleed on my floor?[/]",
            "Very well. [beat] The [hot]coronation[/] begins.",
        ],
        "Phase3": [
            "[big][shake]I AM THE FIRE THAT FORGETS NOTHING![/][/]",
            "My court has [hot]fallen[/]. [beat] So the [glitch]hall burns with it[/].",
        ],
        "Defeat": [
            "[slow]Cooled... [beat] by a [hot]peasant[/].[/]",
            "[whisper]Remember me as... [beat] [wave]warm[/].[/]",
            "[slow]The throne is yours.[/] [beat] It was never [hot]comfortable[/].",
        ],
        "Escape": [
            "[big]A KING DOES NOT FLEE![/] [beat] [slow]He withdraws.[/]",
            "Polish your armour. [beat] I [hot]return[/].",
        ],
        "Enrage": [
            "[big][shake]HOW DARE YOU STILL STAND?![/][/]",
            "[shake]My patience is MOLTEN![/]",
            "[glitch]BOW. BOW. BOW.[/]",
        ],
        "Break": [
            "[big]IMPOSSIBLE![/] [beat] [shake]My CROWN![/]",
            "The [hot]royal guard[/] cracks?!",
            "[shake]Guards! GUARDS![/]",
        ],
        "Hit": [
            "[big]KNEEL![/]",
            "That is [hot]treason[/].",
            "I have burned [slow]kingdoms[/] for less.",
            "[shake]Ash![/] [beat] [hot]All of you, ash![/]",
            "A [slow]peasant's[/] blade.",
            "[wave]How quaint.[/]",
            "You amuse the court.",
            "[shake]DOWN![/]",
            "Is that all [hot]your people[/] could send?",
            "[glitch]Burn. Burn. Burn.[/]",
        ],
        "Stagger": [
            "[big]Kiss the floor, {name}![/]",
            "A subject on [hot]their knees[/]. [beat] Finally, {name}.",
            "Stay down, {name}. [beat] It [slow]suits[/] you.",
            "Ha! [beat] The court [hot]applauds[/], {name}!",
            "Oh, {name}. [beat] Did the [hot]ground[/] offend you?",
        ],
        "Idle": [
            "[slow]I am [hot]waiting[/], peasant.[/]",
            "The throne grows [shake]impatient[/].",
            "[wave]Does no one else dare approach the crown?[/]",
            "Present your [hot]grievance[/]. [beat] Or your [slow]neck[/].",
        ],
        "Attack": {
            "Sweep": ["[big]THE ROYAL SCYTHE![/]", "[slow]Bow low,[/] and the blade [hot]passes[/].", "A [hot]beam[/] of [shake]judgement[/]!"],
            "Volley": ["[shake]Salute![/]", "Fire! [beat] [hot]Fire![/]", "[big]A GUN SALUTE![/]"],
            "Slam": ["[big]THE KING'S FIST![/]", "[shake]TREMBLE.[/]"],
            "TwinSlam": ["[big]Two hands, one [hot]law[/].[/]", "[shake]BOTH FISTS.[/]"],
            "Wall": ["[big]THE WALL OF FLAME![/]", "[slow]Where do you think you are going?[/]"],
            "Meteors": ["[big]THE SKY KNEELS TO ME![/]", "Rain, [hot]stars[/]. [beat] [shake]Rain.[/]", "[glitch]Let heaven burn with my enemies.[/]"],
            "Summon": ["[big]My GUARDS![/]", "Rise, [hot]ember-legion[/]!", "[slow]Attend your king.[/]"],
            "Fissure": ["[big]THE EARTH PARTS FOR ME![/]", "[shake]Split![/]"],
            "Cage": ["A [hot]throne room[/], [slow]no exits[/].", "[big]ATTEND THE KING.[/]"],
        },
    },
    # ------------------------------------------------------------------------------------------------
    # THE STORM SERAPH. A zealot angel of weather and verdicts. Cold, precise, absolutely certain;
    # speaks in sentences and sentencing, as if every blow were already in the record.
    "Seraph": {
        "Forming": [
            "[whisper]The air [wave]clears[/]... [beat] to be [hot]read[/].[/]",
            "A verdict is being [slow]assembled[/].",
        ],
        "Awake": [
            "[slow]I am the Seraph.[/] [beat] The sky keeps a [hot]ledger[/].",
            "Your name was entered at birth. [beat] The sentence was [hot]not[/] revealed.",
            "I shall [slow]read it now[/]. [beat] [big]Aloud.[/]",
        ],
        "Phase2": [
            "[hot]Interesting.[/] [beat] The ledger [shake]shifts[/].",
            "The [slow]appeal[/] is denied. [beat] [wave]Continue.[/]",
        ],
        "Phase3": [
            "[big]THE COURT IS NOW IN SESSION.[/]",
            "[glitch]No more mercy. No more weather. [beat] Only [hot]verdict[/].[/]",
        ],
        "Defeat": [
            "[whisper]The ledger... [beat] [wave]blank[/].[/]",
            "[slow]I judged you wrongly.[/] [beat] [hot]How novel[/].",
            "[wave]Let it rain... [beat] [hot]gently[/].[/]",
        ],
        "Escape": [
            "[slow]The court is adjourned.[/] [beat] [hot]Not dismissed[/].",
            "Await the [shake]next hearing[/].",
        ],
        "Enrage": [
            "[shake]DELAY IS CONTEMPT OF COURT.[/]",
            "[glitch]THE SENTENCE IS NOT NEGOTIABLE.[/]",
            "[big]ALL RISE.[/]",
        ],
        "Break": [
            "[big]Objection![/] [beat] [shake]Sustained?![/]",
            "Procedure... [beat] [hot]violated[/].",
            "[shake]The gavel breaks![/]",
        ],
        "Hit": [
            "[slow]Guilty.[/]",
            "The record [hot]notes[/] it.",
            "[wave]Noted.[/]",
            "One count.",
            "[shake]Sustained.[/]",
            "Your [hot]sentence[/] grows.",
            "[slow]Overruled.[/]",
            "The weather has [hot]opinions[/] about you.",
            "[glitch]Strike that from the record.[/] [beat] [shake]Strike YOU.[/]",
            "[wave]You will be heard.[/] [beat] [slow]Briefly.[/]",
        ],
        "Stagger": [
            "[slow]The defendant, {name}, is down.[/]",
            "{name}: [hot]one count[/] of [shake]standing[/].",
            "Rise, {name}. [beat] [slow]The court has not finished.[/]",
            "[wave]Entered into evidence, {name}: [beat] [hot]your fall[/].[/]",
            "{name}, [beat] you are [slow]noted[/].",
        ],
        "Idle": [
            "[slow]The court awaits the accused.[/]",
            "[wave]Thunder is only a verdict... [beat] [hot]clearing its throat[/].[/]",
            "[whisper]I have your name here somewhere.[/]",
            "[slow]Approach the bench.[/]",
        ],
        "Attack": {
            "Volley": ["[hot]Evidence![/] [beat] [shake]Submitted![/]", "[wave]Each bolt, a [slow]witness[/].[/]", "[shake]Strike, strike, strike.[/]"],
            "Lances": ["[slow]The [hot]line[/] of the law.[/]", "[big]Cross it.[/] [beat] I [hot]dare[/] you."],
            "Fissure": ["[wave]Follow the lightning to its [hot]source[/].[/]", "[slow]A path... [beat] [hot]to judgement[/].[/]", "[shake]Run along the [hot]crack[/].[/]"],
            "Starburst": ["[big]THE VERDICT RADIATES.[/]", "[wave]From the centre outward.[/]"],
            "Summon": ["Attend, [hot]bailiffs[/].", "[slow]Fetch the accused.[/]", "[whisper]Come, little storms.[/]"],
            "Meteors": ["[big]THE HEAVENS SENTENCE YOU.[/]", "Hail. [beat] [hot]Hail[/]. [beat] [shake]HAIL.[/]", "[glitch]Let the sky itself testify.[/]"],
            "Cage": ["[slow]You are [hot]remanded[/].[/]", "[wave]The bars are made of [hot]weather[/].[/]"],
        },
    },
    # ------------------------------------------------------------------------------------------------
    # THE RIMEHEART. An enormous, slow, ancient glacier-mother. Speaks as to a child, quietly, with
    # terrible gentleness; the horror is how kind it sounds.
    "Rime": {
        "Forming": [
            "[whisper]Hush... [beat] [wave]hush[/]...[/]",
            "[slow]Something very old is [hot]turning over[/] in its sleep.[/]",
        ],
        "Awake": [
            "[slow]Little warm thing.[/] [beat] You have [hot]come so far[/].",
            "I have held the [wave]winter[/] for ten thousand years. [beat] It is [slow]so heavy[/].",
            "Lie down. [beat] [hot]I will take it from you[/].",
        ],
        "Phase2": [
            "You are [hot]still warm[/]. [beat] How [slow]strange[/].",
            "Do not be [wave]afraid[/]. [beat] The cold is only [hot]a kind of quiet[/].",
        ],
        "Phase3": [
            "[big]SLEEP.[/]",
            "[whisper]I am not angry.[/] [beat] [slow]I am only [hot]so tired[/] of the [shake]noise[/].[/]",
        ],
        "Defeat": [
            "[whisper]Oh... [beat] [wave]so that is what [hot]warmth[/] is.[/]",
            "[slow]I would have kept you [hot]safe[/].[/] [beat] [whisper]Forever.[/]",
            "[wave]Thaw... [beat] [slow]gently.[/][/]",
        ],
        "Escape": [
            "[slow]I will not follow.[/] [beat] [wave]Winter does not need to.[/]",
            "[whisper]It is already in your [hot]bones[/].[/]",
        ],
        "Enrage": [
            "[shake]STOP MOVING.[/]",
            "[big]Be STILL.[/]",
            "[glitch]HUSH. HUSH. HUSH.[/]",
        ],
        "Break": [
            "[shake]Crack...[/] [beat] [slow]so [hot]loud[/].[/]",
            "[big]You have... [beat] woken it.[/]",
            "[shake]Cold... [beat] [hot]spilling[/]...[/]",
        ],
        "Hit": [
            "[whisper]Shh.[/]",
            "[slow]Hold still.[/]",
            "[wave]It will not hurt for long.[/]",
            "So [hot]warm[/].",
            "[slow]Go to sleep.[/]",
            "You [hot]shiver[/]. [beat] [wave]How sweet.[/]",
            "[whisper]Easy... [beat] easy...[/]",
            "[slow]Rest.[/]",
            "[wave]Snow remembers everyone.[/]",
            "[glitch]Hush hush hush.[/]",
        ],
        "Stagger": [
            "[whisper]There, {name}. [beat] [slow]Down you go.[/][/]",
            "[slow]Lie still, {name}. [beat] I have [hot]you[/].[/]",
            "{name}, little one. [beat] [wave]Close your eyes.[/]",
            "[whisper]Such a [hot]warm[/] heart, {name}.[/]",
            "[slow]Do not get up, {name}. [beat] [hot]It is so soft here[/].[/]",
        ],
        "Idle": [
            "[whisper]Snow is falling in a place you cannot see.[/]",
            "[slow]I can hear your [hot]heartbeat[/].[/] [beat] [wave]It is so loud.[/]",
            "[whisper]Come closer. [beat] I will not bite.[/] [beat] [glitch]I will not.[/]",
            "[wave]The cold has a [hot]lullaby[/].[/]",
        ],
        "Attack": {
            "Cage": ["[whisper]There. [beat] [hot]Safe.[/][/]", "[slow]The walls will [hot]hold you[/].[/]", "[wave]A cradle of ice.[/]"],
            "Rings": ["[wave]Ripples in the [hot]frozen lake[/].[/]", "[slow]Breathe out. [beat] [hot]Feel it spread.[/][/]"],
            "Volley": ["[whisper]Icicles, [hot]falling[/].[/]", "[slow]Each one is a [hot]word[/] I could not say.[/]"],
            "Dissonance": ["[wave]Listen to the [hot]ice sing[/].[/]", "[slow]It is not [shake]safe[/] there.[/]"],
            "Starburst": ["[whisper]Frost, [hot]blooming[/].[/]", "[wave]Every flower, a little [hot]grave[/].[/]"],
            "Summon": ["[whisper]Come, little [hot]snows[/].[/]", "Wake, my [hot]children[/].", "[slow]Gather round the [wave]warm thing[/].[/]"],
            "Meteors": ["[big]THE WINTER FALLS.[/]", "[wave]Hail like [hot]tears[/].[/]", "[slow]Everything must come down eventually.[/]"],
            "GravityWell": ["[slow]Come to me.[/]", "[whisper]All things drift... [beat] [hot]toward the cold[/].[/]", "[wave]Do not struggle.[/]"],
        },
    },
    # ------------------------------------------------------------------------------------------------
    # THE UMBRAL KNIGHT. A duellist bound to a dead oath. Dry, formal, genuinely courteous; keeps score,
    # respects skill, and is at his most dangerous when he is being polite.
    "Knight": {
        "Forming": [
            "[whisper]Steel... [beat] [wave]remembers[/] its hand.[/]",
            "[slow]A salute, [hot]unseen[/].[/]",
        ],
        "Awake": [
            "[slow]An opponent.[/] [beat] [hot]At last.[/]",
            "I am sworn to [hot]one last duel[/]. [beat] I would [slow]prefer[/] it be a good one.",
            "En garde. [beat] [wave]Do try not to disappoint.[/]",
        ],
        "Phase2": [
            "[hot]Good.[/] [beat] [slow]That was good.[/]",
            "Let us see whether you can [shake]keep up[/].",
        ],
        "Phase3": [
            "[big]Now.[/] [beat] [slow]Now I am [hot]serious[/].[/]",
            "My oath [shake]demands blood[/]. [beat] [glitch]Yours, or mine.[/]",
        ],
        "Defeat": [
            "[slow]Well... [beat] [hot]struck[/].[/]",
            "[whisper]The duel is [wave]concluded[/].[/] [beat] [slow]I am [hot]released[/].[/]",
            "[slow]Take the blade.[/] [beat] [hot]It was always meant for a worthier hand.[/]",
        ],
        "Escape": [
            "[slow]The duel is [hot]suspended[/].[/] [beat] I [wave]shall return[/] for [hot]satisfaction[/].",
            "[slow]Practise.[/]",
        ],
        "Enrage": [
            "[shake]You are being [hot]tedious[/].[/]",
            "[glitch]STOP BEING A COWARD.[/]",
            "[big]FINISH ME, OR BE FINISHED.[/]",
        ],
        "Break": [
            "[big]A hit![/] [beat] [slow]Clean.[/]",
            "[shake]My guard...[/] [beat] [hot]opened[/].",
            "[slow]I yield... [beat] [hot]a point[/].[/]",
        ],
        "Hit": [
            "[slow]Touché.[/]",
            "[hot]Careless[/].",
            "[wave]Too slow.[/]",
            "One. [beat] [hot]Two.[/]",
            "Your guard is [shake]open[/].",
            "[slow]Again.[/]",
            "A [hot]fine[/] try.",
            "[wave]Predictable.[/]",
            "You [slow]fence like a [hot]butcher[/].[/]",
            "[glitch]Sloppy.[/]",
        ],
        "Stagger": [
            "[slow]Up, {name}.[/] [beat] A duel is [hot]not[/] a [shake]nap[/].",
            "[wave]Down, {name}?[/] [beat] How [hot]unsporting[/] of the floor.",
            "[slow]Take your time, {name}.[/] [beat] [hot]I will not strike a fallen man.[/] [beat] [shake]Yet.[/]",
            "{name}. [beat] [hot]Respect[/] the [slow]blade[/].",
            "That was [hot]almost[/] good, {name}.",
        ],
        "Idle": [
            "[slow]I am [hot]ready[/] when you are.[/]",
            "[wave]Do you know how long I have waited for a worthy [hot]opponent[/]?[/]",
            "[whisper]The oath weighs on me. [beat] [slow]Lend me your steel.[/][/]",
            "Come. [beat] [hot]Do not be shy.[/]",
        ],
        "Attack": {
            "Fissure": ["[slow]A [hot]line[/] of [shake]steel[/].[/]", "[wave]Follow it.[/]", "[big]Riposte.[/]"],
            "TwinSlam": ["[slow]Two [hot]cuts[/].[/]", "[big]Double strike.[/]"],
            "Sweep": ["[big]A sweeping cut![/]", "[slow]Duck.[/] [beat] [hot]Or do not.[/]"],
            "Summon": ["[slow]Seconds![/] [beat] [hot]To me.[/]", "[wave]Gentlemen... [beat] [hot]join the duel.[/][/]", "[slow]Fair is fair: [hot]a few more blades[/].[/]"],
            "Cage": ["[slow]Within the [hot]ring[/].[/]", "[wave]A duel needs a proper [hot]ring[/].[/]", "[big]The circle closes.[/]"],
            "Wall": ["[slow]A [hot]barrier[/] of [shake]blades[/].[/]", "[big]PARRY THIS.[/]"],
            "Starburst": ["[big]A thousand cuts.[/]", "[slow]Every direction is [hot]a thrust[/].[/]"],
            "Lances": ["[slow]The [hot]thrust[/].[/]", "[wave]A line... [beat] [hot]drawn[/].[/]"],
            "Meteors": ["[big]THE BLADES OF THE FALLEN![/]", "[slow]Swords rain[/] on [hot]the unworthy[/].", "[glitch]Look up.[/]"],
        },
    },
    # ------------------------------------------------------------------------------------------------
    # ASTRAEON, THE UNMADE STAR. A dying sun that remembers being a god. Vast, sorrowful, magnanimous;
    # cruelty is not in it, only the unbearable grief of a thing that has run out of sky.
    "Astraeon": {
        "Forming": [
            "[whisper]Something vast is... [wave]remembering itself[/].[/]",
            "[slow]The air [hot]hums[/] with an old, enormous light.[/]",
        ],
        "Awake": [
            "[slow]A star[/] [beat] remembers what it was.",
            "I was the light that taught your sky to [hot]shine[/]. [beat] Now I am only its [shake]ending[/].",
            "[big]Come, small fires.[/] [beat] [slow]Burn with me.[/]",
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
            "[whisper]I was never... [beat] meant to... [beat] [wave]shine[/]...[/]",
            "[slow]Thank you. [beat] The dark is [hot]gentle[/].[/]",
            "[wave]Look up tonight. [beat] [hot]One fewer[/].[/]",
        ],
        "Escape": [
            "[slow]The dawn will [hot]not[/] come for me.[/]",
            "[wave]I fade... [beat] to [slow]return[/].[/]",
        ],
        "Enrage": [
            "[shake]You are a [hot]spark[/]. [beat] Why will you [slow]not go out[/]?[/]",
            "[glitch]EVERYTHING I TOUCH BURNS.[/]",
            "[big]I CANNOT. STOP. SHINING.[/]",
        ],
        "Break": [
            "[big]My core![/] [beat] [shake]Cracks![/]",
            "[slow]So that is what [hot]pain[/] is.[/]",
            "[shake]Light... [beat] leaking...[/]",
        ],
        "Hit": [
            "[slow]Dim.[/]",
            "[wave]A [hot]spark[/] against the sun.[/]",
            "[shake]Gravity is [slow]patient[/].[/]",
            "[slow]Fall toward me.[/]",
            "I have [hot]watched empires[/] smaller than you.",
            "[wave]Be a good fire.[/] [beat] [hot]Go out.[/]",
            "[slow]I am so sorry.[/]",
            "[glitch]Fall. [beat] Fall. [beat] Fall.[/]",
            "[whisper]It is almost over.[/]",
            "[big]Shine![/] [beat] [slow]For as long as you can.[/]",
        ],
        "Stagger": [
            "[slow]Rise, little fire.[/] [beat] {name}. [beat] [hot]Rise[/].",
            "[wave]{name}... [beat] [slow]I knew a thousand like you.[/][/]",
            "[whisper]Do not be [hot]afraid[/], {name}.[/]",
            "[slow]Even {name} will dim.[/] [beat] [hot]Even I.[/]",
            "{name}. [beat] [slow]Light your own way back.[/]",
        ],
        "Idle": [
            "[whisper]Every star you have ever wished upon... [beat] is [hot]me[/].[/]",
            "[slow]Do you know [hot]how cold[/] the dark is?[/]",
            "[wave]I miss the [hot]others[/].[/]",
            "[slow]Stay. [beat] [hot]Just a little longer.[/][/]",
        ],
        "Attack": {
            "Slam": ["[big]FALL.[/]", "[slow]A star lands.[/]"],
            "Volley": ["[wave]Sparks, [hot]falling[/].[/]", "[slow]Make a wish.[/]"],
            "Fissure": ["[slow]A [hot]crack[/] in the [wave]sky[/].[/]", "[big]The ground... [beat] [hot]opens[/].[/]"],
            "Cage": ["[slow]A [hot]constellation[/] closes.[/]", "[wave]Do not step outside the stars.[/]"],
            "Starburst": ["[big]RADIATE.[/]", "[wave]Every ray, a [hot]memory[/].[/]"],
            "Rings": ["[wave]Orbits.[/]", "[slow]Everything circles [hot]something[/].[/]"],
            "Lances": ["[slow]A line of [hot]starlight[/].[/]", "[big]Stand [shake]aside[/].[/]"],
            "Summon": ["[wave]Come, my [hot]embers[/].[/]", "[slow]Little [hot]suns[/], [beat] attend.[/]"],
            "Meteors": ["[big]THE SKY FALLS![/]", "[wave]Every wish [slow]must land[/] somewhere.[/]"],
            "GravityWell": ["[slow]Everything falls toward the [hot]light[/].[/]", "[wave]Come closer.[/]"],
        },
    },
}
