# Data Directory

This folder is intended to hold the required input files for the simulation.

---

## Required Input Files

The following files must be present before running any scenario script:

```text
Grid_Study_Data.mat
Custom_Wind_Profile.mat
All_Seasons_PLR_Dataset.mat
```

---

## How to Generate These Files

These files are not included in the repository and must be generated locally by running the data preparation scripts in the following order:

### Step 1 — `Data_Prep.m`

Generates the 10-year IEEE RTS-96 hourly load profile.

**Output:** `Grid_Study_Data.mat`

No external data required. The load profile is built entirely from the published IEEE RTS-96 standard multiplier tables.

---

### Step 2 — `Build_Wind_Profile.m`

Converts 10 years of hourly wind speed data into a 300 MW wind farm power output profile using the Vestas V117-3.45 MW power curve and hub height extrapolation.

**Output:** `Custom_Wind_Profile.mat`

**Requires:** `weather_10yr.xlsx`

---

### Step 3 — `calculate_seasonal_PLR_OneGo.m`

Computes seasonal probabilistic line ratings by solving the conductor thermal model across the full 10-year weather dataset for a range of temperature limits and exceedance levels.

**Output:** `All_Seasons_PLR_Dataset.mat`

**Requires:** `weather_10yr.xlsx`

---

## Weather Data (`weather_10yr.xlsx`)

> ⚠️ This file is **not included** in the repository due to file size constraints.

The raw wind speed data was obtained from **NASA POWER** (Prediction Of Worldwide Energy Resources):

**Source:** [https://power.larc.nasa.gov/data-access-viewer/](https://power.larc.nasa.gov/data-access-viewer/)

To download the data:

1. Go to the NASA POWER Data Access Viewer
2. Select **Renewable Energy** as the application type
3. Choose **Hourly** temporal resolution
4. Select the parameter **Wind Speed at 10 m (WS10M)**
5. Set the date range to cover 10 years (e.g. 2011–2020)
6. Enter the coordinates for the study location
7. Download and save as `weather_10yr.xlsx` with a sheet named `Data` and a column named `wind_speed`

Place the file in the MATLAB working directory before running Steps 2 and 3 above.

---

## MATPOWER Case File

The IEEE RTS-96 test case file:

```text
case24_ieee_rts.m
```

is included with MATPOWER and does not need to be placed in this folder separately. It is loaded automatically when MATPOWER is on the MATLAB path.
