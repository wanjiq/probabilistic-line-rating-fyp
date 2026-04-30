# Probabilistic Line Rating Reliability Study (IEEE RTS-96)

## Introduction

This repository contains the MATLAB code developed for my Year 3 Individual Project in Electrical and Electronic Engineering at the University of Manchester. The project evaluates the impact of Static Line Rating (SLR) and Probabilistic Line Rating (PLR) on power system reliability and renewable energy integration.

The study is conducted using the IEEE RTS-96 24-bus test system with Sequential Monte Carlo Simulation and DC Optimal Power Flow (DC OPF) through MATPOWER.

The key outputs of the simulation include:

- Expected Energy Not Supplied (EENS)
- Load shedding distribution by bus
- Line overload severity by branch
- Wind curtailment by wind farm
- Comparison of SLR and PLR across multiple renewable integration scenarios

---

## Project Context

Transmission networks are often operated using Static Line Ratings, which are normally based on conservative weather assumptions. This can underestimate the actual thermal capacity of overhead lines and may lead to unnecessary renewable energy curtailment.

This project investigates Probabilistic Line Rating as an alternative approach. Instead of using one fixed conservative rating, PLR uses the statistical behaviour of weather-dependent line ratings to define operating limits at different exceedance levels.

The simulation framework compares SLR and PLR under different renewable generation scenarios to evaluate their effects on:

- System reliability
- Energy not supplied
- Network congestion
- Renewable energy curtailment

---

## Repository Structure

```text
FYP-PLR-Reliability-Code/
│
├── README.md
├── .gitignore
│
├── run_Scenario1_Baseline_BNM.m
├── run_Scenario2_DER_Heavy_BNM.m
├── run_Scenario3_Bulk_Integrated_BNM.m
├── run_Scenario4_Bulk_Extreme_BNM.m
├── run_Scenario5_Modern_Grid_BNM.m
├── run_Scenario6_Bulk_Collapse_BNM.m
│
├── functions/
│   ├── rating_from_exceedance.m
│   ├── load2disp.m
│   └── other supporting functions
│
├── data/
│   └── README_data.md
│
├── results/
│   └── README_results.md
│
└── docs/
    └── supporting diagrams or figures
```

---

## Scenario-Based Simulation Framework

The project is structured around six standalone MATLAB scenario scripts:

```text
run_Scenario1_Baseline_BNM.m
run_Scenario2_DER_Heavy_BNM.m
run_Scenario3_Bulk_Integrated_BNM.m
run_Scenario4_Bulk_Extreme_BNM.m
run_Scenario5_Modern_Grid_BNM.m
run_Scenario6_Bulk_Collapse_BNM.m
```

Each script represents a different renewable integration and network stress condition.

| Scenario | Script | Description |
|---|---|---|
| Scenario 1 | `run_Scenario1_Baseline_BNM.m` | Baseline system with lower renewable penetration |
| Scenario 2 | `run_Scenario2_DER_Heavy_BNM.m` | DER-heavy case with large wind capacity connected at distribution-level buses |
| Scenario 3 | `run_Scenario3_Bulk_Integrated_BNM.m` | Bulk-integrated renewable case with moderate transmission-level integration |
| Scenario 4 | `run_Scenario4_Bulk_Extreme_BNM.m` | Extreme bulk renewable penetration case |
| Scenario 5 | `run_Scenario5_Modern_Grid_BNM.m` | Modern-grid case with more balanced renewable integration |
| Scenario 6 | `run_Scenario6_Bulk_Collapse_BNM.m` | Highly stressed bulk system case approaching severe network constraints |

---

## Main Example Scenario

One example scenario is:

```matlab
run_Scenario2_DER_Heavy_BNM.m
```

This represents a DER-heavy case with wind generation placed at:

```text
Bus 7  = 400 MW
Bus 13 = 75 MW
Bus 21 = 75 MW
```

In the script, this is defined as:

```matlab
current_wind_caps = [400, 75, 75];
wind_buses = [7, 13, 21];
```

---

## Required Software

The code requires:

- MATLAB
- MATPOWER 8.1
- Microsoft Excel or compatible spreadsheet software to view exported results

MATPOWER is not included in this repository and must be installed separately.

Before running the scripts, MATPOWER must be added to the MATLAB path. For example:

```matlab
addpath('C:\Users\User\Documents\FYP\matpower8.1');
addpath('C:\Users\User\Documents\FYP\matpower8.1\lib');
addpath('C:\Users\User\Documents\FYP\matpower8.1\data');
```

The file path should be changed depending on where MATPOWER is installed on your computer.

---

## Required Input Files

The following files are required to run the simulations:

```text
Grid_Study_Data.mat
All_Seasons_PLR_Dataset.mat
Custom_Wind_Profile.mat
case24_ieee_rts.m
```

These files provide the system data, seasonal PLR dataset, load profile, wind profile, and IEEE RTS-96 test case used in the simulations.

The files should be placed in the MATLAB working directory or in a folder added to the MATLAB path.

---

## How to Run

1. Open MATLAB.

2. Add MATPOWER to the MATLAB path.

3. Add this repository and its subfolders to the MATLAB path:

```matlab
addpath(genpath('FYP-PLR-Reliability-Code'));
```

4. Make sure the required input files are available:

```text
Grid_Study_Data.mat
All_Seasons_PLR_Dataset.mat
Custom_Wind_Profile.mat
case24_ieee_rts.m
```

5. Run one of the scenario scripts. For example:

```matlab
run('run_Scenario2_DER_Heavy_BNM.m')
```

Each scenario script runs independently and creates its own output folder.

---

## Simulation Overview

Each scenario performs the following process:

1. Load the IEEE RTS-96 grid data.
2. Load the PLR dataset and wind profile.
3. Define the selected renewable generation scenario.
4. Add wind generators to selected buses.
5. Calculate SLR and seasonal PLR line limits.
6. Run hourly DC OPF simulations over 8760 hours.
7. Randomly sample conventional generator outages using Forced Outage Rates.
8. Repeat the yearly simulation for 200 Monte Carlo iterations.
9. Track reliability, curtailment, and line overload metrics.
10. Export results to Excel.

---

## Rating Cases Compared

The simulation compares four transmission line rating cases:

```text
SLR
PLR 5%
PLR 10%
PLR 15%
```

These cases are used to assess how different rating assumptions affect system reliability and renewable energy utilisation.

---

## Key Simulation Parameters

The main simulation parameters are defined near the top of each scenario script.

Example:

```matlab
MAX_ITERATIONS = 200;
lambda         = 1.20;
VOLL           = 1000;
LINE_PENALTY   = 5000;
chosen_tmax    = 75;
EXCEEDANCE_SLR = 0.01;
```

Where:

- `MAX_ITERATIONS` defines the number of Monte Carlo yearly simulations.
- `lambda` scales the system load level.
- `VOLL` represents the Value of Lost Load used for load shedding.
- `LINE_PENALTY` is the penalty cost applied to line overloads.
- `chosen_tmax` is the selected maximum conductor temperature.
- `EXCEEDANCE_SLR` defines the exceedance level used for the SLR benchmark.

---

## Output Files

Each scenario automatically creates a results folder in the following format:

```text
Results_Combined_<Scenario_Name>/
```

For example:

```text
Results_Combined_Scenario2_DER_Heavy_BNM/
```

The final Excel output file is saved as:

```text
Final_Results_<Scenario_Name>.xlsx
```

For example:

```text
Final_Results_Scenario2_DER_Heavy_BNM.xlsx
```

---

## Excel Output Sheets

The Excel output file contains the following sheets:

```text
System_Totals
Bus_Shed_SLR
Bus_Shed_P5
Bus_Shed_P10
Bus_Shed_P15
Line_Over_SLR
Line_Over_P5
Line_Over_P10
Line_Over_P15
Farm_Curt_SLR
Farm_Curt_P5
Farm_Curt_P10
Farm_Curt_P15
```

These sheets contain:

- Total EENS and curtailment for each Monte Carlo iteration
- Bus-level load shedding
- Line-level overload severity
- Wind curtailment by wind farm
- Comparison between SLR and PLR cases

---

## Checkpointing

Each scenario includes a checkpoint system.

The checkpoint file is saved as:

```text
Checkpoint_FULL.mat
```

This allows the simulation to resume from the latest completed Monte Carlo iteration if the run is interrupted before completion.

---

## Key Modelling Features

The model includes:

- IEEE RTS-96 24-bus test system
- Sequential Monte Carlo Simulation
- Hourly DC Optimal Power Flow
- Conventional generator outage modelling using Forced Outage Rates
- Wind generation profile based on 10-year wind data
- Load scaling using annual hourly load data
- Static Line Rating benchmark
- Seasonal Probabilistic Line Rating cases
- Load shedding using dispatchable load representation
- Line overload tracking using soft constraints
- Wind curtailment tracking by wind farm
- Bus-level and branch-level reliability tracking

---

## Technical Notes

The simulation uses MATPOWER’s DC OPF solver to evaluate system operation at each hour.

Load shedding is represented through dispatchable load with a Value of Lost Load cost. Wind generators are added to the MATPOWER case at selected buses, with hourly available capacity determined from the wind profile.

Line ratings are applied to the `RATE_A` field of the MATPOWER branch matrix. For each hour, the simulation records:

- Load shedding
- Line overload
- Wind curtailment
- Bus-level EENS contribution
- Branch-level overload contribution
- Wind-farm-level curtailment contribution

---

## Third-Party Software and Code

This project uses MATPOWER for power system modelling and DC Optimal Power Flow.

MATPOWER is third-party software and is not included in this repository. It must be downloaded and installed separately.

Any reused, imported, or third-party code should be clearly identified and referenced in the project report and relevant script comments.

---

## Known Issues and Limitations

- The full simulation can take a long time because each scenario uses 200 yearly Monte Carlo iterations.
- Each yearly simulation contains 8760 hourly OPF evaluations.
- Large result files are not stored directly in the repository.
- The required `.mat` input files must be available before running the simulations.
- File paths may need to be updated depending on the local computer setup.
- Scenario scripts are currently standalone and require manual selection.
- The current implementation is designed for offline simulation rather than real-time operation.

---

## Future Improvements

Potential improvements include:

- A master script to run all scenarios automatically.
- A configuration file to define scenario parameters without editing the main scripts.
- Automated plotting scripts for EENS, curtailment, and probability distributions.
- Percentile-based post-processing for reliability and curtailment results.
- A reduced test dataset for quick validation.
- Parallel computing implementation to reduce simulation time.
- Improved error handling for missing input files.
- More modular separation between data loading, OPF execution, and result export.

---

## Author

Wan Muhammad Haziq Wan Adlin  
MEng Electrical and Electronic Engineering  
The University of Manchester

---

## Project Information

Individual 3rd Year Project  
Department of Electrical and Electronic Engineering  
School of Engineering  
The University of Manchester
