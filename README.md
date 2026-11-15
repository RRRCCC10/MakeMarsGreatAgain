# Make Mars Great Again
**NASA Space Apps Challenge 2026 — Challenge 3: Build a Junior Astronaut Mission Trainer**

## Overview
**Make Mars Great Again** is an interactive Martian outpost simulation and educational game designed to train the next generation of space explorers. This project bridges the gap between theoretical aerospace concepts and hands-on decision-making, challenging players to manage a human settlement on the Red Planet under realistic environmental constraints.

## Gameplay
In **Make Mars Great Again**, players assume the role of an astronaut responsible for the short- and long-term survival operations of a Martian habitat. The gameplay centers on real-time resource management, strategic planning, and crisis response:
- **Resource Allocation:** Players must continuously monitor and balance vital life-support metrics, including electrical power, oxygen generation, water reclamation, and food production.
- **Engineering Trade-Offs:** Every action requires careful resource expenditure, forcing players to carefully weigh their decisions.

## Educational Objective
Traditional STEM and space science education often relies on passive learning methods that fail to convey the complexity of interplanetary missions. **Make Mars Great Again** transforms students from passive observers into active problem-solvers:
- **Systems Thinking:** Learners gain a practical understanding of how closed-loop life-support systems operate and how failure in a single subsystem can trigger cascading consequences across an entire mission.
- **Applied STEM Concepts:** Through intuitive mechanics, players engage with fundamental principles of physics, environmental science, and resource optimization without being overwhelmed by dense technical manuals.
- **Critical Decision-Making:** By simulating authentic mission pressures, the game fosters analytical thinking, risk assessment, and resilience.

## NASA DONKI Integration & Event Modeling
To ensure high scientific fidelity without compromising gameplay pacing, **Make Mars Great Again** integrates historical space weather data from **NASA's DONKI (Space Weather Database Of Notifications, Knowledge, Information)**. 

Because a full Martian sol (day) in the simulation is compressed into an **8-minute gameplay loop**, streaming live real-time telemetry would not align with the player's experience. Instead, the game processes archival datasets from DONKI—specifically analyzing historical records of Coronal Mass Ejections (CMEs), solar flares, and geomagnetic/interplanetary shocks—to calculate the real-world statistical frequency and intensity of space weather hazards. 

These historical probabilities are fed directly into the game's dynamic event engine. As a result, environmental crises such as severe radiation spikes and dust storms occur at scientifically grounded intervals, challenging players to anticipate and prepare for hazards based on authentic NASA space weather patterns.

## Getting Started
1. Clone the repository:
   ```bash
   git clone [https://github.com/RRRCCC10/TheMartian.git](https://github.com/RRRCCC10/TheMartian.git)
