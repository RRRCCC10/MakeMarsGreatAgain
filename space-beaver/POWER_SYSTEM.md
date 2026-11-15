# Electrical system

## Grid flow

The grid automatically selects one of two flows:

- with at least one connected battery: `Panels -> Transformer -> Batteries -> Consumers`;
- without connected batteries: `Panels -> Transformer -> Consumers`.

The path is split into three independent grids: raw current from panels,
transformed current sent to batteries, and current leaving batteries. Cables from
different grids cannot share a cell or form a junction, even when they pass near
the same machine.

- Every panel produces up to 100 kW: it ramps from 0–100% between 06:00 and
  07:00, remains at full power until 17:00, and ramps from 100–0% by 18:00.
- Solar production is always 0 kW between 18:00 and 06:00.
- Every battery stores up to 500 kWh.
- Every battery retains independent charge; a disconnected battery neither
  charges nor discharges.
- In direct mode, consumers work only when instantaneous solar production covers
  all demand; no power is available at night.
- Excess production charges batteries.
- When production is insufficient, the grid automatically uses batteries.
- When neither production nor batteries cover demand, the entire grid blacks out.
- A panel needs two cells for its sprite and a third free cell on its right for
  the cable output.

## Device sprites

- The transformer uses four complete 32×32 frames arranged in a 2×2 grid.
- The battery uses 16×16 frames: five rows represent charge levels and each row
  contains four animation frames.
- The battery row is chosen from real charge; animation advances only across the
  four frames in that row.

## Sol cycle

- One complete Sol lasts eight real minutes: 12 daylight hours and 12 night
  hours.
- UI phases are `DAWN` from 05:00–06:00, `DAY` from 06:00–17:00, `DUSK` from
  17:00–18:00, and `NIGHT` from 18:00–05:00.
- The world changes colour without alternate textures; UI and pixel art keep
  nearest-neighbour filtering.
- Battery and transformer use LEDs and local glows consistent with power state,
  charging/discharging, and time of day.
- The global clock is separate from the electrical grid, keeping light and power
  synchronized even if temporal speed changes.

## Automatic cables

The grid uses a 16×16-pixel grid and orthogonal A* routing. Cables:

- are free and created or removed automatically;
- reuse existing segments and generate curves, crossings, and T-junctions;
- avoid rocks, devices, and buildings;
- can pass beneath pipes;
- rebuild after placement, recovery, or rock collection.

## Store and construction

- `B`: opens or closes the shop.
- Solar panel: 500 million.
- Transformer: 1 billion; multiple transformers can be purchased to create
  independent grids.
- Battery: 750 million.
- From the inventory (`Tab`), click a device to equip it in hotbar slot 2.
- Left click: places a device on the grid.
- Right click on a placed device: returns it to inventory without a refund.

## Connecting new buildings

A consumer building can register with:

```gdscript
PowerGrid.register_consumer(self, connection_cell, demand_kw, attach_direction)
```

and implement:

```gdscript
func set_powered(value: bool) -> void:
    # Starts or stops the machine's production and animations.
```

On removal it must call `PowerGrid.unregister_consumer(self)`. If at least one
battery is connected, the grid routes the consumer from the nearest reachable
battery. Otherwise it connects it directly to transformer output and applies the
appropriate powered or blackout state.
