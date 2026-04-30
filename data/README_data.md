# Data Files

The MATLAB simulations require the following input data files.

## Required `.mat` Files

### Grid_Study_Data.mat

Contains the main grid study variables used by the simulation, including hourly load and seasonal information.

Expected variables include:

- `load_10yr_MW`
- `Ttbl`

### All_Seasons_PLR_Dataset.mat

Contains the seasonal probabilistic line rating dataset.

Expected variables include:

- `compiled_results`
- `Tmax_list`

The `compiled_results` structure is used to obtain PLR ratings for different seasons and exceedance levels.

### Custom_Wind_Profile.mat

Contains the 10-year wind generation profile used to calculate hourly available wind generation.

Expected variable:

- `P_Farm_300MW_10yr`

The script scales this 300 MW wind farm profile according to the installed wind capacity in each scenario.

## MATPOWER Case File

### case24_ieee_rts.m

This file contains the IEEE RTS-96 24-bus MATPOWER case used as the base network model.

## Notes

Large `.mat` files may not be included in this repository due to file size. If they are not included, they must be placed in the MATLAB working directory before running the scenario scripts.
