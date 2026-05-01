%% --- plot_nodal_eens_2farm_all.m ---
clear; clc; close all;

% 1. EXACT FILE PATH (For the 2-Farm Scenario)
file_2_wind = 'Results_2x150MW_Wind/Final_Results_2x150MW_Wind.xlsx';

% 2. READ BUS SHEETS
T_slr = readtable(file_2_wind, 'Sheet', 'Bus_EENS_SLR');
T_plr = readtable(file_2_wind, 'Sheet', 'Bus_EENS_PLR');

% 3. CALCULATE AVERAGES FOR ALL 24 BUSES
num_buses = 24;
slr_vals = zeros(1, num_buses);
plr_vals = zeros(1, num_buses);
bus_labels = cell(1, num_buses);

for i = 1:num_buses
    col_name = sprintf('Bus_%d', i);
    % Safety check
    if ismember(col_name, T_slr.Properties.VariableNames)
        slr_vals(i) = mean(T_slr.(col_name));
        plr_vals(i) = mean(T_plr.(col_name));
    end
    bus_labels{i} = sprintf('%d', i); % Just the number for a clean X-axis
end

% 4. FORMAT DATA
data = [slr_vals; plr_vals]'; 

% 5. PLOT BAR CHART
figure('Color', 'w', 'Position', [100, 100, 1200, 500]); % Wide format
b = bar(data, 'FaceColor', 'flat');

% Colors: SLR = Orange, PLR = Blue
b(1).CData = [0.8500 0.3250 0.0980]; 
b(2).CData = [0.0000 0.4470 0.7410];

% Formatting
title('System-Wide Nodal EENS: SLR vs. PLR (2-Farm Scenario)', 'FontSize', 16, 'FontWeight', 'bold');
ylabel('Average Bus EENS (MWh)', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('Bus Number', 'FontSize', 14, 'FontWeight', 'bold');

% Apply the 24 labels
xticks(1:num_buses);
xticklabels(bus_labels);

legend('SLR (Static Limits)', 'PLR (Dynamic Limits)', 'FontSize', 12, 'Location', 'northeast');
grid on;

fprintf('\n✅ System-wide Nodal Bar Chart (2-Farm) generated!\n');