%% run_seasonal_Tmax.m
clear; clc; close all;

% --- Configuration ---
Tmax_list = 70:5:100;      % Sweep Tmax
ex_list = [0.1 0.2 0.5 1 2 3 5 7 10]; % Exceedance levels (%)
% Define seasons exactly as they appear in your weather_10yr.xlsx
seasons = {'Winter', 'Summer', 'Spring/Fall'}; 

% Results structure to store tables for each season
seasonal_data = struct();

for s = 1:numel(seasons)
    target_season = seasons{s};
    fprintf("\n=== Processing Season: %s ===\n", target_season);
    
    % Temporary storage for this season's sweep
    season_results = nan(numel(Tmax_list), numel(ex_list));
    I_ref = [];
    Pexc_mat = [];
    
    for a = 1:numel(Tmax_list)
        Tmax_fixed = Tmax_list(a);
        
        % This calls build_exceedance_rating_curve with target_season set
        build_exceedance_rating_curve; 
        
        load("rating_curve_Tmax.mat", "I_list", "Pexc_I");
        
        if isempty(I_ref)
            I_ref = I_list;
            Pexc_mat = nan(numel(I_ref), numel(Tmax_list));
        end
        Pexc_mat(:,a) = Pexc_I;
        
        for b = 1:numel(ex_list)
            season_results(a,b) = rating_from_exceedance(I_list, Pexc_I, ex_list(b));
        end
        fprintf("Tmax=%d°C -> 5%% PLR = %.1f A\n", Tmax_fixed, season_results(a,7));
    end
    
    % Format Table for this season
    T = array2table(season_results, "VariableNames", "PLR_" + string(ex_list) + "pct");
    T.Tmax_C = Tmax_list(:);
    T = movevars(T, "Tmax_C", "Before", 1);
    
    % Store in structure and export individual Excel sheets
    seasonal_data.(genvarname(target_season)).Table = T;
    seasonal_data.(genvarname(target_season)).Pexc_mat = Pexc_mat;
    
    writetable(T, "PLR_Results_Seasonal.xlsx", "Sheet", target_season);
end

% Save everything for the Sequential Monte Carlo script
save("Seasonal_PLR_Dataset.mat", "Tmax_list", "I_ref", "seasonal_data", "seasons");
disp("Saved: Seasonal_PLR_Dataset.mat and PLR_Results_Seasonal.xlsx");