# Duck Days

An iPhone app and home screen widget that counts down the days until something,
fronted by a pixel-art rubber duck floating on a pond.

## Layout

| Path | What it is |
| --- | --- |
| `DuckDays/` | The app target — edit the title and date, preview the widget |
| `DuckWidget/` | The WidgetKit extension |
| `Shared/` | Code compiled into both targets |
| `DuckDays.xcodeproj` | Hand-written project file (no XcodeGen/Tuist needed) |

## The ducks

Twenty-two of them, each a character rather than a colourway: a sprite with its own
accessory, a body and background palette, an ink colour, a font design, uppercase or
not, and a day or night sky. Pick one in the app; the widget follows.

| | | | |
| --- | --- | --- | --- |
| Ducky — cowlick | Ribbon — bow | Daisy — flower | Frosty — bobble hat |
| Cozy — scarf | Dapper — top hat | Royal — crown | Birthday — party hat |
| Angel — halo | Sprout — sprout | Sporty — visor | Pirate — bandana |
| Chef — chef hat | Wizard — wizard hat | Scuba — snorkel | Cowboy — cowboy hat |
| Artist — beret | Mischief — horns | Alien — antennae | Floaty — inner tube |
| Whirly — propeller | Laurel — laurel | | |

Names are display only — `styleID` is the stable key, so renaming a duck never breaks
a saved countdown. Removing one is safe too: `DuckStyle.named` falls back to Ducky.

### Changing the art

The sprites are **generated**, not hand-drawn. `tools/duck_forge.py` composes the
silhouette from three ellipses (head, float, tail), derives the 1px outline from that
silhouette, bands the shading off each region's own centre so the head and belly read
as rounded volumes, and stamps an accessory on top. That is why the curves are smooth
and all of them share one exact body. `Shared/DuckStyles+Generated.swift` is its
output and should never be edited by hand.

```bash
python3 tools/duck_forge.py preview ducks.png   # contact sheet, review your change
python3 tools/duck_forge.py small ducks.png     # same, at widget scale
python3 tools/duck_forge.py blink ducks.png     # the blink frame
python3 tools/duck_forge.py scene decor.png     # cloud, sun, moon, star, wave
python3 tools/duck_forge.py swift               # rewrite the Swift table
python3 tools/duck_forge.py icon                # rewrite the app icon
```

Adding a style means adding one accessory function and one row to `STYLES`, then
re-running `swift`. Changing the body shape means editing `HEAD`, `BELLY`, and `TAIL`,
which updates every duck at once. Accessories are placed relative to `HX`, the column
the head is centred on, so they travel with the duck if it ever moves again.

## The scene

`Shared/DuckScene.swift` draws the pond that fills the widget: sky gradient, a sun or
a moon (night styles get the moon plus a star field), drifting clouds, a scalloped
waterline built by tiling a wave sprite, ripples, and the duck floating with part of
its hull below the surface.

**One pixel grid.** `DuckPond` derives a `unit` — the size of a single sprite pixel in
points — from the duck's width, then sizes every sprite as a whole number of those
units and snaps positions to them. That is what keeps the 1px outlines at matching
visual weight: the duck's outline, the clouds', and the moon's are all literally the
same thickness.

The overlay closure receives a `PondMetrics` (unit, waterline, size), so callers can
keep their type clear of the water. That is what stops the medium caption landing on
the waterline when it wraps to two lines.

`ScenePlacement` holds the per-size furniture positions. The countdown number sits
somewhere different in each size and the scenery has to dodge it, so placement is
explicit rather than computed. Small drops clouds entirely — at 158pt there is not
room for the duck, the counter and weather without everything competing.

Two details worth keeping: star positions are **clustered**, not spread evenly, because
an even spread reads as a repeating pattern rather than a sky; and there are three
genuinely different cloud sprites rather than one stretched to three widths.

## Widget chrome

The widget is deliberately **edge to edge**. iOS 17 insets widget content by default,
and the `containerBackground` showing through that inset reads as a thick rounded
frame around the artwork — so `.contentMarginsDisabled()` is on the configuration, and
the only chrome is a 2pt stroke in the same near-black the sprites are outlined with.

The corner radius itself is owned by the system and cannot be reduced; `ContainerRelativeShape`
follows whatever iOS applies. Filling to the edge is what removes the mismatch.

## Widget sizes

Small, medium, large, plus lock screen rectangular and circular. All three home screen
sizes are the same design — one centred counter block above a duck on water — rather
than three separate layouts, and the number-to-caption size ratio is held at 3.3:1
across all of them.

Type is sized as a **fraction of the scene's height**, not in fixed points. The artwork
already scales with its container, so fixed type only composed correctly at exactly one
render size — it overflowed the moment the same scene was drawn as the app's hero or as
a thumbnail in the widget sheet. The coefficients are calibrated so that at true widget
dimensions the result is identical to fixed points — the shipped widget is unchanged.

Large adds the date as a third line of the same block (not a separate element floating
in the water) and gives the duck hero size; small drops the clouds.

## Animation

In the app, the duck bobs and rotates on the water, blinks on a timer (there is a
second sprite frame for the closed eye), the clouds drift, and the ripples pulse.

**On the home screen the duck moves too**, if Duck motion is on — but by a different
mechanism, because a widget has no run loop to drive a repeating animation. Instead
every timeline entry carries a `phase`, the duck's pose is a pure function of it, and
WidgetKit animates the change as one entry replaces the next.

The provider supplies 120 entries a minute apart, then reloads. That is cheap: stepping
through entries the provider already returned does **not** spend the refresh budget —
only calling `getTimeline` again does — so this costs about a dozen reloads a day,
comfortably inside what WidgetKit allows. Turning motion off drops the timeline back to
one entry plus a midnight each day.

What this is honestly worth: the duck shifts pose roughly once a minute, with a smooth
transition, and iOS decides exactly when — it can coalesce or skip updates to save
power. It is movement, not smooth animation. Nothing available to a widget gives you
smooth animation.

Two details that fall out of the granularity: the widget duck never blinks (eyes shut
for a whole minute reads as asleep, not as a blink), and the cloud drift had to be fast
enough that a minute's step moves it at least a whole pixel, or it rounds to the same
position and never budges. The small size has no clouds, so only the duck moves there.

## Running it

```bash
open DuckDays.xcodeproj
```

Pick an iPhone simulator and hit Run. From the command line:

```bash
xcodebuild -project DuckDays.xcodeproj -scheme DuckDays -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

To see the widget itself, run the app once, then long-press the home screen, tap **+**,
search for **Duck Days**, and add it.

## How the app and widget share data

The app writes a JSON-encoded `CountdownEvent` into `UserDefaults` for the App Group
`group.com.rohan.duckdays`; the widget reads it back and calls
`WidgetCenter.shared.reloadAllTimelines()` on save. If you change the bundle identifier,
change the group ID in three places: `Shared/Countdown.swift`,
`DuckDays/DuckDays.entitlements`, and `DuckWidget/DuckWidget.entitlements`.

The timeline emits one entry per midnight for the following week, so the number rolls
over on its own even when the system is slow to refresh.

## Putting it on a real iPhone

The project builds unsigned for the simulator as-is. For a device, open the project in
Xcode, select each target's **Signing & Capabilities** tab, and set your team. The App
Group needs to exist on your developer account, and free (non-paid) accounts re-sign
apps every 7 days.

## Regenerating the app icon

The icon comes from the same forge as the sprites, so the two cannot drift:

```bash
python3 tools/duck_forge.py icon
```

## The app

The main screen is the finished thing, not the editor for it. The countdown is the
hero and takes the top third; everything else is one tap away:

- **Tap the countdown** → widget sheet (size, and how to add it)
- **Tap the event card** → event sheet (title, calendar)
- **See all** → the full grid of ducks

Edits save as they happen, so the primary button is about adding the widget rather
than committing a form.

Type splits two ways: rounded sans for anything read as language, monospaced only for
data — dates, day counts, duck names. Retro personality comes from the artwork, not
from styling every label like a terminal. Outlines are reserved for selection: the
selected duck gets an inset accent border and nothing else on the screen is outlined.
The accent appears exactly twice — the selected duck and the primary button.

`DuckDays/AppChrome.swift` holds the tokens and reusable views (`Chrome`, `PixelGrid`,
`PixelField`, `DuckCard`, `PrimaryButtonStyle`, `SizePicker`); `DuckDays/Sheets.swift`
holds the three sheets.

## Not built yet

Ideas that are real features rather than styling, scoped but not implemented:

- **Milestones** — the duck earning something at 30 / 100 / 365 days. Needs persisted
  state and a notion of "since we started", which `CountdownEvent` does not have.
- **Ducks reacting to the event** — party hat for a birthday, luggage for a holiday.
  Needs either an event-type picker or inference from the title.
- **Multiple countdowns.** The store holds exactly one event today.

Counting up already works: a date in the past reads "days since" and counts up, so
both "42 days until graduation" and "219 days since I quit" are supported now.
