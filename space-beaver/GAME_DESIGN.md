# Space Beaver — Game Design Reference

**Document status:** reference for the current playable version. It describes both
design intent and implemented rules. Values may change during balancing; values
listed here are the current ones.

## 1. Game premise

*Space Beaver* is a Mars survival and infrastructure game. The player does not
“conquer” Mars with one building; they gradually assemble a chain of survival:
explore, collect samples, obtain water, produce oxygen, generate electricity,
build pressurized shelter, grow food, and finance research sent to Earth.

The central design idea is legible physical systems. Water moves through pipes,
oxygen is produced and delivered, power has production and storage limits, domes
can deplete their atmosphere, and the greenhouse stops growing without water.
Structures are not decorative menus: they define the player's options.

### Design pillars

1. **Physical readability.** Every resource has a visible source, path, and use.
2. **Survival before expansion.** Life support failures matter before prestige.
3. **Linked progression.** Water → electricity → life support → habitat → food
   → research → funding.
4. **Exploration with risk.** Remote biomes offer valuable samples but require
   better suits, planning, shelter, and rovers.
5. **Functional pixel art.** Powered states, working animations, doors, night
   lighting, plant growth, and network indicators communicate state.

## 2. Win and failure conditions

The mission fails when the astronaut dies. Critical systems are thirst, hunger,
oxygen, internal temperature, and radiation dose.

The final mission succeeds only after the return rocket launches with:
- one sealed sample of every geological rock type;
- the alien-life sample;
- a qualified Sabatier reactor;
- 400 kg of methane loaded into the rocket.

A successful launch plays the existing rocket sprite animation and concludes the
mission. A restart is a new mission: supplies, economy, structures, orders,
progress, and objectives reset.

## 3. Core player loop

1. Read survival, weather, and power information.
2. Collect surface samples and explore new terrain.
3. Claim objectives and use funds to acquire infrastructure.
4. Build an electrical grid and extract water.
5. Use water for the electrolyzer, greenhouse, and bottle refill.
6. Build pressurized habitat and maintain oxygen.
7. Study samples, sign reports, and transmit them to Earth.
8. Upgrade equipment, reach remote regions, and prepare the return rocket.

## 4. World, map, and time

The world is a 2,000 × 2,000-tile authored Mars map. Tiles are 16 × 16 pixels.
Terrain is streamed in chunks so exploration remains fluid. Rocks and structures
collide and cannot overlap during placement. The player cannot leave world bounds.

The minimap follows the astronaut closely and is highly zoomed. Press “M” to open
the larger topographic map. It displays explored terrain, player position,
delivery capsules, and structure markers. The full map supports wheel zoom and
middle-button dragging.

Time is shown as local Martian solar time (LMST) and a Sol counter. One Sol lasts
eight real minutes. The game uses these lighting phases:

| Phase | LMST | Solar behavior |
|---|---:|---|
| Dawn | 05:00–06:00 | Solar output increases. |
| Day | 06:00–17:00 | Full light is available. |
| Dusk | 17:00–18:00 | Solar output decreases. |
| Night | 18:00–05:00 | Solar output is zero. |

## 5. Survival systems

### Oxygen

- Standard suits hold 100 O₂ units; advanced suits increase capacity.
- Outside, suit oxygen decreases over time.
- Inside a pressurized, breathable structure, suit oxygen recharges up to the
  equipped suit's maximum.
- Domes and greenhouses have finite O₂ reserves and consume oxygen while
  occupied.

### Water and hunger

- Thirst and hunger decrease continuously.
- A selected water bottle can be refilled at a water drill with available water,
  even when the drill is not powered at that moment.
- Food rations restore hunger.
- The mission starts with five rations.
- A greenhouse harvest yields either four or five potato rations with equal
  probability.

### Temperature and radiation

The astronaut normally targets 37 °C. Cold, suit thermal tolerance, wind chill,
and dome heating affect internal temperature. A pressurized shelter helps;
powered domes help much more.

Cosmic background radiation is always present. Solar activity can create events
and warnings. Suits and habitats reduce solar and cosmic exposure differently.
Radiation dose decays over time in the model, but severe accumulated dose is
fatal. Radiation effects progressively reduce movement before mission failure.

## 6. Weather and sandstorms

Sandstorms alternate between calm, warning, and active phases. During a storm,
outdoor EVA can suffer distinct debuff profiles such as cutting gusts, dust
clouds, or Martian whiteout. Movement slows, oxygen/thirst/hunger consumption
increases, and wind chill increases.

Sand may accumulate in one or two levels during a normal storm. A third level is
rare. A single held “E” cleaning action removes every accumulated level from a
machine. Solar tarps can protect panels; a destroyed panel must be removed and
replaced. Weather alerts reposition below other relevant HUD panels instead of
covering machine or survival information.

## 7. Inventory and controls

The inventory has five hotbar slots and twenty backpack slots. Clicking an item
in the backpack moves or swaps it with the hotbar. The selected item can be used,
placed, or consumed contextually.

| Control | Action |
|---|---|
| Tab | Open inventory |
| B | Open shop |
| J | Open mission graph |
| L | Open electrical distribution center |
| M | Open or close map |
| E | Context action |
| Hold E | Clean sand or perform a hold action when indicated |
| P | Take camera photo |
| O | Transmit oldest unsent photo |
| U | Upgrade nearby research machine |
| V | Toggle a nearby machine's grid connection |
| T | Change pipe type or manage nearby solar tarp |
| R | Rotate placement or confirm report action where prompted |
| F | Rover solar panels or report signature where prompted |
| RMB | Inspect, recover, or demolish according to context |
| Esc | Close the active panel or modal |

Context actions use distance and priority. “E” must not collect a distant rock or
steal input from a nearer door, rover, drill, or airlock.

## 8. Construction and demolition

Placement validates map bounds, terrain, rocks, buildings, the player, and
occupied cells. The same rules apply to preview and final placement. Capsule
landing also checks occupied footprints and cannot land inside a dome.

Right-click can inspect a machine or begin demolition. Removing a placed pipe
returns the full $100 MN construction value; other recoveries return the physical
item rather than a cash refund. Demolishing a dome preserves any docked rover at
its world location and returns the dome item to inventory.

## 9. Electrical grid

The grid uses automatic orthogonal A* cable routes over 16 × 16 cells. Cables
avoid rocks and structures, may run beneath pipes, and have unlimited routing
range. If every valid route is blocked, the game stops routing cleanly and gives
a placement error instead of lagging or emitting repeated errors.

A transformer establishes a grid. Multiple transformers can be purchased, making
separate far-away grids possible. Devices expose clear names rather than engine
node names. The electrical distribution screen lists only readable generation,
storage, conversion, and consumption entries with clickable controls.

| Device | Key rule |
|---|---|
| Solar panel | Up to 100 kW in daylight. |
| Transformer | Creates or feeds an independent power grid. |
| Battery | Stores up to 500 kWh independently. |
| Consumer | Can be manually connected or disconnected with V. |

When batteries exist, power travels from panels through the transformer to
batteries and then consumers. Without batteries, consumers receive direct solar
power only when current production covers demand.

## 10. Pipes, water, gas, and machines

Pipes use orthogonal connections and cannot cross invalid placement cells. They
carry water, hydrogen, or oxygen according to the connected source. A visible
pipe is not enough: a consumer needs a connected source that is actually
providing the resource.

### Water drill

The water drill extracts water when powered. Its reservoir holds at most 500 L.
The drill should produce enough water to sustain a greenhouse and electrolyzer
with a small surplus. A selected bottle can be refilled from stored water,
including water held while the drill is temporarily disconnected.

### Electrolyzer

The electrolyzer consumes water and electricity to supply hydrogen and oxygen as
continuous flows. It is not an invisible gas store. Its outputs must be routed
to a valid consumer; disconnected output is not accumulated.

### Sabatier reactor

The Sabatier reactor accepts hydrogen and electricity at its defined launch-pad
location. It produces methane for the return rocket. The rocket tank accepts up
to 400 kg of methane. A qualifying production event is required before the
rocket can launch.

### Rock drill

The rock drill is a powered machine with internal geological-sample storage.
Press E nearby to open its storage, choose a particular stack, transfer it to
the backpack, take all, or discard storage. Its sprite sheet uses 32 × 64-pixel
frames.

## 11. Domes, airlocks, rover dock, and greenhouse

Domes are pressurized habitats available in three sizes. Exterior and interior
rendering preserve a readable astronaut and floor. While inside a dome, outside
actions such as boarding a rover are blocked; only appropriate airlock actions
remain available.

Domes begin with a finite oxygen reserve. A connected oxygen pipe with an active
source must actually replenish it. Powered dome heating provides a strong thermal
bonus. A medium or large dome can host a physical rover dock. The dock draws
power and recharges a parked rover.

The greenhouse is a pressurized agricultural dome with its own airlock:
- it requires a real water source to grow;
- electrical connection is manually controlled;
- powered operation increases growth speed;
- mature plants contribute limited oxygen;
- press E inside to plant seeds or collect a ready crop;
- genetic potato seeds unlock through missions and can be upgraded in the shop
  from level 0 to 5 for yield and speed;
- already planted crops retain their original seed levels; a better selected seed
  offers replacement rather than retroactive strengthening.

## 12. Rovers and Perseverance

The exploration rover has an independent battery, boarding/exit behavior, solar
panels, sand states, and a dock interaction. Short E presses preserve boarding
or contextual actions; holding E near a dusty rover cleans it instead.

Perseverance first fails after 72–96 in-game hours, then again every 7–10 Sols.
It appears within 500 tiles of the center. A direction arrow points to it until
the astronaut is within 15 tiles. Recovery is a short chain:
1. photograph the damaged rover and transmit the photo;
2. hold E to study damage;
3. sign and send the damage report;
4. complete the displayed repair key sequence.

After repair, Perseverance disappears only after leaving the player's distant
view and returns when the next failure occurs. Missions reward the full recovery
chain without forcing repeated rover failures.

## 13. Camera and research

The scientific camera is earned through objectives. Its dedicated HUD appears
only while the camera is equipped, never during landing. The camera roll does
not impose a maximum capacity; photos may continue to be taken and transmitted.

Photos can advance exploration contracts. Recognized subjects include terrain,
rocks, domes, greenhouse, laboratories, Perseverance, ice, and relevant
conditions. A photo pays only when sent to Earth.

Research machines (XRD, Raman, and ICP-MS) consume one selected sample and large
amounts of power during analysis. Multiple backpack rock stacks open a picker
with thumbnails; Esc closes it. A finished report must first be signed and then
sent to Earth. Base rewards include an additional $100 MN relative to former
values.

## 14. Mission graph, economy, and shop

The J objective board is a visual graph rather than a linear list. Objectives
can show progress before prerequisite rewards are claimed. Click a reached,
available node to claim its reward. Categories cover field collection,
exploration, photography, water and survival, habitat and food, industrial
research, polar biology, genetic potatoes, suit upgrades, rover recovery, and
return preparation.

The shop is organized by clear categories. Funds are displayed compactly. Every
funds change shows a small green rising number for income or a red falling number
for spending. Pipe price appears above the hotbar only while the pipe hammer is
equipped, rather than cluttering the money panel.

## 15. Return mission

The rocket manifest is a scrollable list. It names every required geological
sample, its source biome, its rarity, and whether it has been sealed aboard.
It separately shows the alien-life sample, Sabatier qualification, and methane
tank fill. Buttons load available samples, and launch remains unavailable until
all requirements are complete.

Required return steps:
1. find alien life and secure its sample;
2. acquire one sample of every rock type;
3. install and connect the Sabatier reactor;
4. produce and load 400 kg methane;
5. load every required sample;
6. launch the return rocket.

## 16. Implementation principles

- Keep a single source of truth for water, gas, power, and resource flow.
- Never hide unmodeled reserves behind a machine described as continuous-flow.
- Use readable names for every player-visible system and device.
- Keep UI panels responsive at different window sizes and do not let alerts cover
  survival bars or machine information.
- Preserve deterministic placement, pathfinding, and cleanup behavior.
- Treat all science-fiction values as gameplay unless explicitly supported by a
  cited scientific source.

## 17. Quality checklist

A release should verify:
- no placement overlaps player, rock, or structure;
- grids route around obstacles or fail gracefully;
- oxygen reaches a dome only through a connected active source;
- modals close with Esc and block conflicting world input;
- inventory items remain clickable and movable between backpack and hotbar;
- camera HUD appears only when equipped;
- objective notifications can be dismissed by clicking;
- long lists, especially the return manifest, provide usable scrolling;
- all player-facing, source, test, and documentation text is English.

