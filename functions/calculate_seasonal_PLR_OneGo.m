%% calculate_seasonal_PLR_OneGo.m
% FLOW:
% 1) Load 10-year weather data.
% 2) Automatically detect all Seasons in your dataset.
% 3) For each season, solve Tc(t) for all test currents ONCE.
% 4) Sweep through Tmax limits and calculate exceedance.
% 5) Save everything to a single Excel file (separate sheets) and one MAT file.
clear; clc; close all;

%% ---- USER CHOICES ----
file  = "weather_10yr.xlsx";
sheet = "Data";
Tmax_list = 70:5:100;      % sweep Tmax
ex_list = [0.1 0.2 0.5 1 2 3 5 7 10]; % exceedance levels (%)
I_list = (700:50:2000)';   % A   <-- rating candidates

%% ---- Conductor constants ----
D0    = 0.02814;      eps   = 0.8;    alpha = 0.8;
R25   = 7.283e-05;    R75   = 8.688e-05;    Z1    = 90;

%% ---- Tc solver settings ----
TolA = 0.5; MaxIter = 50; Tlow_min = -50;
Thigh0 = 120; ThighMax = 500; dThigh = 50;
sgn = @(x) (x>=0)*2-1;

%% ---- 1. READ WEATHER ONCE ----
disp("Loading 10-year weather data... (This only happens once!)");
Ttbl = readtable(file, "Sheet", sheet);

% Automatically find all unique seasons in 'Season' column
% (Assumes column is named 'Season'. Change if necessary)
seasons_present = unique(string(Ttbl.Season));
seasons_present(seasons_present == "") = []; % Remove empty strings if any
fprintf("Found %d seasons: %s\n", numel(seasons_present), strjoin(seasons_present, ", "));

% Storage for the final consolidated MAT file
compiled_results = struct();

%% ---- 2. MAIN SEASONAL LOOP ----
for s = 1:numel(seasons_present)
    curr_season = seasons_present(s);
    fprintf('\n======================================================\n');
    fprintf('   PROCESSING SEASON: %s\n', curr_season);
    fprintf('======================================================\n');
    
    % Filter weather for THIS season
    S_tbl = Ttbl(strcmpi(string(Ttbl.Season), curr_season), :);
    Ta  = S_tbl.air_temperature;
    Wd  = mod(S_tbl.wind_direction, 360);
    Vw  = max(S_tbl.wind_speed, 0);
    Qse = S_tbl.Qse_Wm2;
    n = numel(Ta);
    fprintf("Samples for %s: %d\n", curr_season, n);
    
    % --- Step A: Solve Tc for all currents (Only solving ONCE per season) ---
    Tc_matrix = nan(n, numel(I_list)); % Store Tc for every hour, every current
    
    for j = 1:numel(I_list)
        I_test = I_list(j);
        Tc = nan(n,1);
        for i = 1:n
            Tlow  = max(Ta(i), Tlow_min);
            Thigh = max(Thigh0, Tlow + 5);
            f_low = Icalc(Tlow,  Ta(i), Wd(i), Vw(i), Qse(i), D0, eps, alpha, R25, R75, Z1) - I_test;
            if abs(f_low) < TolA
                Tc(i) = Tlow;
                continue;
            end
            f_high = Icalc(Thigh, Ta(i), Wd(i), Vw(i), Qse(i), D0, eps, alpha, R25, R75, Z1) - I_test;
            while sgn(f_low) == sgn(f_high) && Thigh < ThighMax
                Thigh = Thigh + dThigh;
                f_high = Icalc(Thigh, Ta(i), Wd(i), Vw(i), Qse(i), D0, eps, alpha, R25, R75, Z1) - I_test;
                if abs(f_high) < TolA
                    Tc(i) = Thigh;
                    break;
                end
            end
            if ~isnan(Tc(i)), continue; end
            if sgn(f_low) == sgn(f_high)
                Tc(i) = NaN;
                continue;
            end
            for k = 1:MaxIter
                Tmid  = 0.5*(Tlow + Thigh);
                f_mid = Icalc(Tmid, Ta(i), Wd(i), Vw(i), Qse(i), D0, eps, alpha, R25, R75, Z1) - I_test;
                Tc(i) = Tmid;
                if abs(f_mid) < TolA
                    break;
                end
                if sgn(f_low) ~= sgn(f_mid)
                    Thigh = Tmid; f_high = f_mid;
                else
                    Tlow = Tmid;  f_low  = f_mid;
                end
            end
        end
        Tc_matrix(:, j) = Tc; % Save all solved temperatures for this current
    end
    
    % --- Step B: Sweep Tmax and Calculate Exceedance ---
    results = nan(numel(Tmax_list), numel(ex_list));
    Pexc_mat = nan(numel(I_list), numel(Tmax_list));
    
    for a = 1:numel(Tmax_list)
        Tmax_fixed = Tmax_list(a);
        
        % Calculate Exceedance Probability (Pexc) for all currents at this Tmax
        for j = 1:numel(I_list)
            Tc_v = Tc_matrix(~isnan(Tc_matrix(:,j)), j);
            if ~isempty(Tc_v)
                Pexc_mat(j, a) = mean(Tc_v >= Tmax_fixed);
            end
        end
        
        % Look up the exact Amps for the requested Risk Levels (ex_list)
        for b = 1:numel(ex_list)
            % Calls your external function
            results(a,b) = rating_from_exceedance(I_list, Pexc_mat(:,a), ex_list(b));
        end
        
        fprintf("[%s] Tmax=%d°C -> PLR 1%% = %.1f A, 5%% = %.1f A\n", ...
            curr_season, Tmax_fixed, results(a,4), results(a,7));
    end
    
    % --- Step C: Formatting & Saving to Excel/Mat ---
    T = array2table(results, "VariableNames", "PLR_" + string(ex_list) + "pct");
    T.Tmax_C = Tmax_list(:);
    T = movevars(T, "Tmax_C", "Before", 1);
    
    % Write to ONE Excel file, putting this season on a new Sheet
    writetable(T, "Seasonal_PLR_Summary.xlsx", "Sheet", curr_season);
    
    % Store in compiled MATLAB structure
    compiled_results.(genvarname(curr_season)).SummaryTable = T;
    compiled_results.(genvarname(curr_season)).Pexc_mat = Pexc_mat;
    compiled_results.(genvarname(curr_season)).I_list = I_list;
end

% Save the master MAT file
save("All_Seasons_PLR_Dataset.mat", "Tmax_list", "ex_list", "compiled_results");
disp("======================================================");
disp("DONE! All data saved to:");
disp(" 1) Seasonal_PLR_Summary.xlsx (Multiple Sheets)");
disp(" 2) All_Seasons_PLR_Dataset.mat");