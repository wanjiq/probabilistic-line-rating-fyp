%% --- Generate_Load_Wind_Profile_Dual_Plot.m ---
clear; clc; close all;

% 1. Load your raw grid data
load('Grid_Study_Data.mat'); 

% 2. Define your simulation parameters
lambda = 1.35; 

% 3. Extract the first year (8760 hours) and apply the stress factor
Load_profile = load_10yr_MW(1:8760) * lambda; 
Wind_profile = P_wind_10yr(1:8760);
full_year_hours = 1:8760;

% 4. Define the Winter Peak snapshot (Week 51: Hours 8401 to 8568)
start_hr = 8401; 
end_hr   = 8568; 
week_51_vector = start_hr:end_hr;

% 5. Generate the Dual-Panel Plot
figure('Color', 'w', 'Name', 'Annual and Peak Profiles', 'Position', [150, 100, 1000, 700]);

% ==========================================
% TOP PANEL: The Full 8760-Hour Year
% ==========================================
subplot(2,1,1);
yyaxis left
plot(full_year_hours, Load_profile, '-', 'LineWidth', 0.5, 'Color', [0.85 0.325 0.098 0.7]); % Added transparency
ylabel('Stressed System Load (MW)', 'FontWeight', 'bold');
set(gca, 'ycolor', [0.85 0.325 0.098]);
ylim([min(Load_profile)*0.9, max(Load_profile)*1.05]);

yyaxis right
plot(full_year_hours, Wind_profile, '-', 'LineWidth', 0.5, 'Color', [0 0.447 0.741 0.7]);
ylabel('Available Wind Power (MW)', 'FontWeight', 'bold');
set(gca, 'ycolor', [0 0.447 0.741]);
ylim([0, max(Wind_profile)*1.1]);

title('Macro View: Full Annual Chronological Profile (8760 Hours)', 'FontSize', 13, 'FontWeight', 'bold');
xlabel('Hour of the Year', 'FontWeight', 'bold');
xlim([1 8760]);
set(gca, 'FontSize', 11, 'TickDir', 'out', 'LineWidth', 1); 
box off; grid on;

% ==========================================
% BOTTOM PANEL: The Week 51 Zoom-In
% ==========================================
subplot(2,1,2);
yyaxis left
plot(week_51_vector, Load_profile(start_hr:end_hr), '-', 'LineWidth', 2, 'Color', [0.85 0.325 0.098]);
ylabel('Stressed System Load (MW)', 'FontWeight', 'bold');
set(gca, 'ycolor', [0.85 0.325 0.098]);
ylim([min(Load_profile(start_hr:end_hr))*0.9, max(Load_profile(start_hr:end_hr))*1.05]);

yyaxis right
plot(week_51_vector, Wind_profile(start_hr:end_hr), '-', 'LineWidth', 1.5, 'Color', [0 0.447 0.741]);
ylabel('Available Wind Power (MW)', 'FontWeight', 'bold');
set(gca, 'ycolor', [0 0.447 0.741]);
ylim([0, max(Wind_profile(start_hr:end_hr))*1.1]);

title('Micro View: Winter Peak Snapshot (Week 51)', 'FontSize', 13, 'FontWeight', 'bold');
xlabel('Hour of the Year (Week 51)', 'FontWeight', 'bold');
xlim([start_hr end_hr]);
set(gca, 'FontSize', 11, 'TickDir', 'out', 'LineWidth', 1); 
box off; grid on;

% Save for other scripts
save('Profile_Snapshot_Data.mat', 'Load_profile', 'Wind_profile');
fprintf('Dual-panel profile plot generated successfully!\n');