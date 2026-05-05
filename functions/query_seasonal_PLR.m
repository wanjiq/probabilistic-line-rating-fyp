%% query_seasonal_PLR.m
% A simple interactive tool to fetch or interpolate a specific PLR value.
clear; clc;

% 1. Load the compiled dataset
data_file = "All_Seasons_PLR_Dataset.mat";
if ~isfile(data_file)
    error("Could not find %s. Please run the One-Go calculator script first.", data_file);
end
load(data_file, "compiled_results", "Tmax_list");

% Get the list of seasons available in the dataset
available_seasons = fieldnames(compiled_results);

fprintf('======================================================\n');
fprintf('             SEASONAL PLR QUERY TOOL\n');
fprintf('======================================================\n\n');

%% --- STEP 1: What Season? ---
fprintf('Available Seasons: %s\n', strjoin(available_seasons, ', '));
chosen_season = input('1) Enter Season (exactly as typed above): ', 's');

safe_season = genvarname(chosen_season);
if ~isfield(compiled_results, safe_season)
    error("Season '%s' not found in the dataset.", chosen_season);
end

%% --- STEP 2: What Max Conductor Temp? ---
fprintf('\nAvailable Tmax values (°C): %s\n', strjoin(string(Tmax_list), ', '));
chosen_tmax = input('2) Enter Max Conductor Temp (°C): ');

if ~ismember(chosen_tmax, Tmax_list)
    error("Tmax %d°C was not simulated. Please choose from the list.", chosen_tmax);
end

%% --- STEP 3: What Exceedance Level? ---
% Now you can enter ANY number!
fprintf('\n(You can enter ANY percentage now, e.g., 0.01, 5, 12.5)\n');
chosen_ex = input('3) Enter Exceedance Level (%): ');

if chosen_ex <= 0 || chosen_ex > 100
    error("Please enter a valid percentage strictly greater than 0 and up to 100.");
end

%% --- RETRIEVE AND INTERPOLATE THE PLR ---
% 1. Find which column corresponds to your chosen Tmax
tmax_idx = find(Tmax_list == chosen_tmax);

% 2. Extract the raw exceedance curve (Pexc) and the Current list (I_list)
Pexc_curve = compiled_results.(safe_season).Pexc_mat(:, tmax_idx);
I_list = compiled_results.(safe_season).I_list;

% 3. Interpolate the exact rating using your external function
% (Make sure rating_from_exceedance.m is in your folder!)
plr_value = rating_from_exceedance(I_list, Pexc_curve, chosen_ex);

fprintf('\n======================================================\n');
fprintf('                     RESULT\n');
fprintf('======================================================\n');
fprintf(' Season      : %s\n', chosen_season);
fprintf(' Temp Limit  : %d °C\n', chosen_tmax);
fprintf(' Risk Level  : %g %%\n', chosen_ex);
fprintf('------------------------------------------------------\n');
fprintf(' RATING (PLR): %.2f Amps\n', plr_value);
fprintf('======================================================\n');