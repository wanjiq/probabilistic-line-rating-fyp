%% --- 01_DATA_PREP.m: Load & Wind Data Synchronization ---
clear; clc; close all;

%% 1. USER SETTINGS & CONSTANTS
Peak_Load_MW = 2850;      % IEEE RTS-96 System Peak
P_rated = 500;            % 500 MW Wind Farm
v_ci = 3; v_r = 12; v_co = 25; % Turbine parameters
weather_file = "weather_10yr.xlsx";

%% 2. GENERATE 10-YEAR IEEE RTS-96 LOAD PROFILE
% Multipliers
W_w = [0.862, 0.900, 0.878, 0.834, 0.880, 0.841, 0.832, 0.806, 0.740, 0.737, ...
       0.715, 0.727, 0.704, 0.750, 0.721, 0.800, 0.754, 0.837, 0.870, 0.880, ...
       0.856, 0.811, 0.900, 0.887, 0.896, 0.861, 0.755, 0.816, 0.801, 0.880, ...
       0.722, 0.776, 0.800, 0.729, 0.726, 0.705, 0.780, 0.695, 0.724, 0.724, ...
       0.743, 0.744, 0.800, 0.881, 0.885, 0.909, 0.940, 0.890, 0.942, 0.970, ...
       1.000, 0.952]; 
D_d = [0.93, 1.00, 0.98, 0.96, 0.94, 0.77, 0.75];
H_wkdy = [0.67, 0.63, 0.60, 0.59, 0.59, 0.60, 0.74, 0.86, 0.95, 0.96, 0.96, 0.95, ...
          0.95, 0.95, 0.93, 0.94, 0.99, 1.00, 1.00, 0.96, 0.91, 0.83, 0.73, 0.63];
H_wknd = [0.78, 0.72, 0.68, 0.66, 0.64, 0.65, 0.66, 0.70, 0.80, 0.88, 0.90, 0.91, ...
          0.90, 0.88, 0.87, 0.87, 0.91, 1.00, 0.99, 0.97, 0.94, 0.92, 0.87, 0.81];

load_year = zeros(8760, 1);
hr_idx = 1;
for wk = 1:52
    for day = 1:7
        for hr = 1:24
            if hr_idx > 8760, break; end
            if day <= 5
                load_year(hr_idx) = W_w(wk) * D_d(day) * H_wkdy(hr);
            else
                load_year(hr_idx) = W_w(wk) * D_d(day) * H_wknd(hr);
            end
            hr_idx = hr_idx + 1;
        end
    end
end
% Repeat for 10 years and scale to MW
load_10yr_MW = repmat(load_year, 10, 1) * Peak_Load_MW;

%% 3. LOAD WEATHER & CONVERT TO WIND POWER
Ttbl = readtable(weather_file, "Sheet", "Data");
Vw_10yr = max(Ttbl.wind_speed, 0); 
P_wind_10yr = zeros(height(Ttbl), 1);

for t = 1:height(Ttbl)
    v = Vw_10yr(t);
    if v >= v_ci && v < v_r
        P_wind_10yr(t) = P_rated * ((v^3 - v_ci^3) / (v_r^3 - v_ci^3));
    elseif v >= v_r && v <= v_co
        P_wind_10yr(t) = P_rated;
    else
        P_wind_10yr(t) = 0;
    end
end

%% 4. SAVE DATASET
save('Grid_Study_Data.mat', 'load_10yr_MW', 'P_wind_10yr', 'Ttbl');

%% 5. PLOT RESULTS (Directly in MATLAB)
figure('Color', 'w', 'Position', [100, 100, 1100, 700]);

% --- Plot 1: Annual Overview ---
subplot(2, 1, 1);
plot(load_10yr_MW(1:8760), 'LineWidth', 1, 'Color', [0, 0.44, 0.74]); hold on;
plot(P_wind_10yr(1:8760), 'LineWidth', 1, 'Color', [0.46, 0.67, 0.18], 'LineStyle', ':');
title('Annual Profile: Load vs. Wind Power (Year 1)', 'FontWeight', 'bold');
ylabel('Power (MW)'); xlabel('Hour of the Year');
legend('System Load', 'Wind Generation');
grid on;

% FIX: Limit X-axis to exactly one year (8760 hours)
xlim([1, 8760]); 

% --- Plot 2: Zoomed View (Winter Peak Week) ---
subplot(2, 1, 2);
h_start = 8400; h_end = h_start + 167;
t_axis = 1:168;

yyaxis left
plot(t_axis, load_10yr_MW(h_start:h_end), 'LineWidth', 2, 'Color', [0, 0.44, 0.74]);
ylabel('Load (MW)', 'FontWeight', 'bold');

yyaxis right
area(t_axis, P_wind_10yr(h_start:h_end), 'FaceColor', [0.46, 0.67, 0.18], 'FaceAlpha', 0.3);
ylabel('Wind Power (MW)', 'FontWeight', 'bold');

title('Winter Peak Week: Load & Wind Interaction (168 Hours)', 'FontWeight', 'bold');
xlabel('Hour of the Week');
grid on;

% FIX: Limit X-axis to exactly one week (168 hours)
xlim([1, 168]); 

legend('System Load (Left Axis)', 'Wind Power (Right Axis)', 'Location', 'northeast');