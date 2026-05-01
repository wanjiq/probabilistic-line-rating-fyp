%% --- plot_EENS_distributions.m ---
clear; clc; close all;

% =====================================================
% 1. USER INPUTS
% =====================================================
file_no_wind = 'testing_base/Results_0_Wind.xlsx'; 
file_1_wind  = 'Results_300MW_Wind/Partial_Results_1_Wind.xlsx'; 
file_2_wind  = 'Results_2x150MW_Wind/Final_Results_2x150MW_Wind.xlsx'; 

% =====================================================
% 2. LOAD THE DATA
% =====================================================
T_no = readtable(file_no_wind, 'Sheet', 'System_Totals');
eens_no = T_no.EENS_SLR_MWh; 

T_1 = readtable(file_1_wind, 'Sheet', 'System_Totals');
eens_1 = T_1.EENS_PLR_MWh; 

T_2 = readtable(file_2_wind, 'Sheet', 'System_Totals');
eens_2 = T_2.EENS_PLR_MWh; 

% =====================================================
% 3. CALCULATE MEAN (μ) AND STANDARD DEVIATION (σ)
% =====================================================
mu_no = mean(eens_no);  sig_no = std(eens_no);
mu_1  = mean(eens_1);   sig_1  = std(eens_1);
mu_2  = mean(eens_2);   sig_2  = std(eens_2);

% =====================================================
% 4. CREATE THE X-AXIS
% =====================================================
min_x = min([mu_no - 4*sig_no, mu_1 - 4*sig_1, mu_2 - 4*sig_2]);
max_x = max([mu_no + 4*sig_no, mu_1 + 4*sig_1, mu_2 + 4*sig_2]);
x = linspace(max(0, min_x), max_x, 1000); 

% =====================================================
% 5. CALCULATE PROBABILITY DENSITY FUNCTIONS (PDF)
% =====================================================
pdf_no = (1 ./ (sig_no * sqrt(2*pi))) .* exp(-0.5 * ((x - mu_no) ./ sig_no).^2);
pdf_1  = (1 ./ (sig_1  * sqrt(2*pi))) .* exp(-0.5 * ((x - mu_1)  ./ sig_1).^2);
pdf_2  = (1 ./ (sig_2  * sqrt(2*pi))) .* exp(-0.5 * ((x - mu_2)  ./ sig_2).^2);

% =====================================================
% 6. PLOT THE BEAUTIFUL GRAPH
% =====================================================
figure('Color', 'w', 'Position', [100, 100, 900, 500]);
hold on; grid on;

% Plot curves
p_no = plot(x, pdf_no, 'r', 'LineWidth', 3, 'DisplayName', 'Baseline (No Wind)');
p_1  = plot(x, pdf_1,  'b', 'LineWidth', 3, 'DisplayName', '1-Farm (300MW @ Bus 7) + PLR');
p_2  = plot(x, pdf_2,  'g', 'LineWidth', 3, 'DisplayName', '2-Farm (150MW @ Bus 7 & 21) + PLR');

% Add vertical dashed lines for the Means
xline(mu_no, 'r--', 'LineWidth', 1.5, 'HandleVisibility', 'off');
xline(mu_1,  'b--', 'LineWidth', 1.5, 'HandleVisibility', 'off');
xline(mu_2,  'g--', 'LineWidth', 1.5, 'HandleVisibility', 'off');

% Formatting
title('System Reliability Shift: Expected Energy Not Served (EENS)', 'FontSize', 16, 'FontWeight', 'bold');
xlabel('Total System EENS (MWh)', 'FontSize', 14, 'FontWeight', 'bold');

% ---> UPDATED Y-AXIS LABEL WITH UNITS <---
ylabel('Probability Density (1 / MWh)', 'FontSize', 14, 'FontWeight', 'bold');

legend('FontSize', 12, 'Location', 'northeast');
set(gca, 'FontSize', 12);

% Force MATLAB to use scientific notation nicely on the Y-axis
ax = gca;
ax.YAxis.Exponent = -5; % Adjusts the scientific multiplier to make ticks readable

fprintf('\n✅ Graph updated! The Y-axis now has proper values and units.\n');