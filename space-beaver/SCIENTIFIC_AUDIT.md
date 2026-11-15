# Scientific audit of Space Beaver text

This document is prepared for scientific review. Percentages, timing, rewards,
and production capacities are gameplay parameters, not experimental data or NASA
mission specifications.

## 1. Perseverance narrative report

The game deliberately presents this alternate-history report:

> PERSEVERANCE (NASA, 2021)
>
> • Operational period: 18 February–November 2026;
> • Cause of end of operations: progressive deterioration of the wheels and
> traction motors, caused by prolonged exposure to Martian terrain and wear of
> mechanical components, compromises rover mobility and makes continued
> operations impossible.
> • Final condition: it would remain immobilized in Jezero Crater on Mars.
> Before failure it had travelled more than 45.22 km (as of 11 October 2026),
> surpassing Opportunity's record.

### Review

- The 45.22 km figure on 11 October 2026 and the surpassing of Opportunity's
  45.16 km record are consistent with the JPL release of 12 October 2026.
- The consulted JPL source describes Perseverance as operating with functioning
  mobility systems and discusses a mission extended to roughly the end of 2028.
  Therefore, the November 2026 cessation and immobilization are alternate game
  narrative, not verified NASA history.
- Wheel wear is a real technical risk: NASA has documented sharp rocks damaging
  rover wheels. The narrative must not be presented as Perseverance's factual
  historical end without a current official source.

## 2. Physical systems and machines

### Photovoltaic solar panel

> Photovoltaic cells convert solar photons into direct current through the
> photovoltaic effect in semiconductors.

Assessment: correct as a concise explanation. The 100 kW value, production
proportional to light, and zero night production are gameplay parameters. Dust
reducing available light and power is physically plausible and documented by
NASA, but storm numbers are a gameplay simplification.

### Electrical transformer

> Electromagnetic induction transfers energy between isolated windings and
> adapts voltage and current for the storage grid.

Assessment: correct for a conventional AC transformer. The statement that every
transformer creates an independent grid describes a game rule, not an automatic
physical consequence; real behavior depends on how windings and systems connect.

### Storage battery

> Electrical energy is stored as reversible chemical energy and returned to the
> grid when solar generation does not cover the load.

Assessment: correct as a general description of a rechargeable battery. The
500 kWh capacity, flows, and nighttime availability are gameplay parameters.

### Ice-extraction drill

> Game ISRU model: the drill head penetrates ice-bearing Martian regolith; the
> recovered ice is separated and melted to obtain liquid water.

Assessment: a cautious description of a hypothetical ISRU system. ISRU means
in-situ resource utilization. On Mars, water is primarily considered ice or
hydrated minerals; extraction, purification, melting, equipment, and energy
budgets would be considerably more complex than the game simulates. The 80 L/h,
60 kW, and 500 L reservoir are gameplay values.

### Water electrolyzer

> Electrolysis uses energy to split water into H₂ and O₂ and provides them as
> continuous flows on separate lines, without internal storage.

Reaction to display or review:

> 2 H₂O → 2 H₂ + O₂

Assessment: correct for water electrolysis. The reaction requires energy and
produces twice as many moles of hydrogen as oxygen. Direct, unstored output is a
simulation choice. A realistic system would require sufficiently pure or treated
water; the game does not simulate purification.

### Sabatier reactor

> The Sabatier reaction combines atmospheric CO₂ and hydrogen to synthesize
> methane and water: CO₂ + 4 H₂ → CH₄ + 2 H₂O. In the game model methane moves
> directly to the rocket.

Assessment: the reaction is correct. It requires CO₂, H₂, catalyst, temperature
control, and thermal management. The game assumes atmospheric CO₂ is available
and does not simulate those subsystems. In an ISRU chain, produced water can be
recycled into electrolysis. Direct rocket transfer is a game rule.

## 3. Scientific instruments

### X-ray diffractometer (XRD)

> X-ray diffraction identifies crystalline phases in a sample from the geometry
> of its atomic lattice.

Assessment: correct. Peak positions and intensities depend on crystal structure
and can identify mineral phases. XRD alone is not a life detector and does not
prove a biosignature.

### Raman spectrometer

> Raman laser scattering reveals molecular bonds and mineralogical composition
> without destroying the sample.

Assessment: substantially correct. Raman spectra arise from vibrational modes
and can characterize minerals and some molecules. “Non-destructive” means that,
under appropriate conditions, analysis need not consume the sample; laser power,
preparation, and material can still cause changes in extreme cases.

### ICP-MS spectrometer

> Inductively coupled plasma ionizes the sample; mass spectrometry measures
> elements and their abundances.

Assessment: correct as a summary. In practice, a sample must be prepared and
introduced into the instrument. ICP-MS measures elemental concentrations and can
measure isotope ratios with appropriate configuration and calibration. It is not
an independent proof of life and does not specifically detect organic matter
without complementary methods.

### Biosignature-compatible signal

In the game, XRD, Raman, and ICP-MS have 20%, 35%, and 55% chances respectively
of yielding a positive result from deep ice. These values are explicitly marked
as a game model, not real sensitivities, accuracies, or published probabilities.
A positive result must be called “a signal compatible with a possible
biosignature,” not “proof of life.” A real biosignature would require multiple
evidence lines, contamination controls, geological context, and independent
analysis.

## 4. Drill samples and terminology

“Core” is the correct technical term for a cylindrical rock sample produced by
coring, but it is neither a mission name nor the name of the drill. The game
therefore uses:

- GEOLOGICAL SAMPLING: first installation of the mining drill;
- POLAR SAMPLING: installation in the polar biome;
- geological sample: material retained by the drill;
- rock core: allowed only when an actual coring cylinder is meant.

The mineralogical names used by the game—basalt, andesite, olivine, hematite,
goethite, sulfates, breccia, and impactite—are plausible categories or names,
but exact biome associations, rarities, and economic multipliers are narrative
construction. Olivine shoshonite, primordial deep ice, and an ice biosignature
are fictional game elements and must remain marked as such.

## 5. Martian environment and survival

### Atmosphere and life support

The game correctly assumes that Mars's atmosphere is very thin, CO₂-rich, and
not breathable. Dome O₂ reserves, consumption, pressure, losses, and the
equivalence between kilograms and abstract units are numerical abstractions, not
certified engineering values.

### Radiation

The game distinguishes cosmic background and solar spikes and uses mSv for dose.
The physical distinction is correct; suits and habitats can reduce exposure, but
real protection depends on mass, composition, geometry, duration, and radiation
spectrum. The 4,000 mSv threshold, 24-hour halving, and shielding bonuses are
game rules, not universal clinical limits.

### Dust storms

Dust can reduce panel illumination and contaminate or damage mechanisms and
electronics. Martian wind, however, exerts far less pressure than many cinematic
portrayals imply. Debuffs, increased EVA consumption, and sand levels are game
balancing.

### Greenhouse and potatoes

A pressurized greenhouse, growth water, and harvest fit the fantasy of a Mars
base, but four-or-five rations, growth time, production, and genetic seed
modification are game mechanics. They are not a realistic agricultural forecast
for Mars. GM levels are narrative progression, not approved varieties or
experimental yields.

## 6. Primary sources for external review

- NASA/JPL — Perseverance sets off-world distance record:
  https://www.jpl.nasa.gov/news/nasas-perseverance-sets-off-world-record-for-total-distance-driven/
- NASA — Perseverance rover components and drill:
  https://science.nasa.gov/mission/mars-2020-perseverance/rover-components/
- NASA/JPL Education — core sampling:
  https://www.jpl.nasa.gov/edu/resources/project/explore-rocks-using-core-sampling/
- NASA ARES — X-ray diffraction:
  https://ares.jsc.nasa.gov/research/laboratories/xray-diffraction.html
- NASA — Mars atmosphere:
  https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/mars-atmosphere-equation-english/
- NASA — methane and oxygen production on Mars:
  https://www.nasa.gov/directorates/stmd/space-tech-research-grants/producing-methane-and-oxygen-on-mars-using-proton-conducting-ceramics/
- NASA — dust storms and solar power:
  https://science.nasa.gov/solar-system/planets/mars/10-things-dust-in-the-wind-on-mars-and-well-beyond/
- NASA — fact and fiction of Martian dust storms:
  https://www.nasa.gov/solar-system/the-fact-and-fiction-of-martian-dust-storms/

## 7. Items requiring approval before calling them scientific

1. Decide whether the Perseverance report is a NASA historical reconstruction or
   alternate game story. The code uses the requested text, while the consulted
   JPL source does not confirm a November 2026 shutdown.
2. Decide whether primordial deep ice remains fiction or is replaced by a
   realistic geological sample that does not imply life.
3. Decide whether the game may abbreviate to “compatible signal detected” or
   should always use the scientifically cautious “compatible signal.” The code
   and missions use the latter.
4. Approve all numerical values for energy, water, gas, radiation, temperature,
   timing, and yield as game balancing rather than real habitat design data.

