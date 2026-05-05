%% --- 1_Build_Wind_Profile.m ---
clear; clc;

% =====================================================
% 1. LOAD RAW WIND SPEED DATA FROM EXCEL
% =====================================================
fprintf('Loading raw weather data from Excel... (This might take a moment)\n');
filename = 'weather_10yr.xlsx'; 
weather_table = readtable(filename, 'Sheet', 'Data');
wind_speed_10yr = weather_table.wind_speed;

% Handle any missing/NaN values
wind_speed_10yr(isnan(wind_speed_10yr)) = 0; 

% =====================================================
% 2. THE POWER LAW (HUB HEIGHT EXTRAPOLATION)
% =====================================================
fprintf('Extrapolating 10m wind speeds to 80m hub height...\n');
H_hub = 80;       % Vestas V117-3.45 MW Hub Height (IEC IB)
H_ref = 10;       % NASA Power reference height
alpha = 0.143;    % Shear exponent (1/7) for neutral stability

% Calculate the actual wind speed hitting the blades
wind_speed_hub = wind_speed_10yr .* (H_hub / H_ref)^alpha;

% =====================================================
% 3. TURBINE & FARM ENGINEERING SPECS
% =====================================================
% Vestas V117-3.45 MW Parameters (From Official Brochure)
P_rated = 3.45;      % Rated power of one turbine (MW)
v_ci    = 3.0;       % Cut-in wind speed (m/s)
v_r     = 12.0;      % Rated wind speed (m/s) - Standard aerodynamic assumption
v_co    = 25.0;      % Cut-out wind speed (m/s)

% ~300 MW Farm Layout
N_turbines = 87;     % 87 turbines * 3.45 MW = 300.15 MW capacity
efficiency = 0.90;   % 90% Array Efficiency (Accounting for Wake Effect)

% =====================================================
% 4. RUN THE AERODYNAMIC POWER CURVE (VECTORIZED)
% =====================================================
fprintf('Processing aerodynamic power curve...\n');
P_single_turbine = zeros(length(wind_speed_hub), 1);

% Phase 2: Cubic Aerodynamic Region (between cut-in and rated)
idx_cubic = (wind_speed_hub >= v_ci) & (wind_speed_hub < v_r);
P_single_turbine(idx_cubic) = P_rated .* ((wind_speed_hub(idx_cubic).^3 - v_ci^3) ./ (v_r^3 - v_ci^3));

% Phase 3: Perfect wind (rated capacity)
idx_rated = (wind_speed_hub >= v_r) & (wind_speed_hub < v_co);
P_single_turbine(idx_rated) = P_rated;

% =====================================================
% 5. SCALE UP & SAVE
% =====================================================
% Multiply single turbine by 87 units and apply the efficiency penalty
P_Farm_300MW_10yr = P_single_turbine * N_turbines * efficiency;

fprintf('\n--- 300.15 MW WIND FARM SUCCESSFULLY BUILT ---\n');
fprintf('Turbine Model: Vestas V117-3.45 MW\n');
fprintf('Maximum Output: %.2f MW\n', max(P_Farm_300MW_10yr));
fprintf('Average Output: %.2f MW\n', mean(P_Farm_300MW_10yr));
fprintf('Farm Capacity Factor: %.2f%%\n', (mean(P_Farm_300MW_10yr) / (P_rated * N_turbines)) * 100);

save('Custom_Wind_Profile.mat', 'P_Farm_300MW_10yr');
fprintf('Data saved perfectly as "Custom_Wind_Profile.mat"\n');