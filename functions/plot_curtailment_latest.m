%% --- plot_curtailment_clean.m ---
clear; clc; close all;

% 1. EXACT FILE PATHS
file_1_wind = 'Results_300MW_Wind/Partial_Results_1_Wind.xlsx'; 
file_2_wind = 'Results_2x150MW_Wind/Final_Results_2x150MW_Wind.xlsx'; 

% 2. LOAD SYSTEM TOTALS
T_1 = readtable(file_1_wind, 'Sheet', 'System_Totals');
T_2 = readtable(file_2_wind, 'Sheet', 'System_Totals');

% 3. EXTRACT CURTAILMENT DATA
curt_1_slr = T_1.Curtailment_SLR_MWh;
curt_1_plr = T_1.Curtailment_PLR_MWh;
curt_2_slr = T_2.Curtailment_SLR_MWh;
curt_2_plr = T_2.Curtailment_PLR_MWh;

% 4. CALCULATE MEAN & STD
mu_1s = mean(curt_1_slr); sig_1s = std(curt_1_slr) + 1e-6; 
mu_1p = mean(curt_1_plr); sig_1p = std(curt_1_plr) + 1e-6;
mu_2s = mean(curt_2_slr); sig_2s = std(curt_2_slr) + 1e-6;
mu_2p = mean(curt_2_plr); sig_2p = std(curt_2_plr) + 1e-6;

% 5. CREATE X-AXIS
min_x = 0; % Curtailment can't be negative
max_x = max([mu_1s+3*sig_1s, mu_1p+3*sig_1p, mu_2s+3*sig_2s]);
x = linspace(min_x, max_x, 1000); 

% 6. CALCULATE PDFs
pdf_1s = (1 ./ (sig_1s * sqrt(2*pi))) .* exp(-0.5 * ((x - mu_1s) ./ sig_1s).^2);
pdf_1p = (1 ./ (sig_1p * sqrt(2*pi))) .* exp(-0.5 * ((x - mu_1p) ./ sig_1p).^2);
pdf_2s = (1 ./ (sig_2s * sqrt(2*pi))) .* exp(-0.5 * ((x - mu_2s) ./ sig_2s).^2);
pdf_2p = (1 ./ (sig_2p * sqrt(2*pi))) .* exp(-0.5 * ((x - mu_2p) ./ sig_2p).^2);

% 7. PLOT WITH SHADING
figure('Color', 'w', 'Position', [100, 100, 900, 500]);
hold on; grid on;

% Define professional colors
c_1s = [0.8500 0.3250 0.0980]; % Orange/Red
c_1p = [0.0000 0.4470 0.7410]; % Blue
c_2  = [0.4660 0.6740 0.1880]; % Green (using one green for 2-Farm since they overlap)

% Plot lines
plot(x, pdf_1s, 'Color', c_1s, 'LineWidth', 3, 'DisplayName', '1-Farm (300MW) - SLR');
plot(x, pdf_1p, 'Color', c_1p, 'LineWidth', 3, 'DisplayName', '1-Farm (300MW) - PLR');
plot(x, pdf_2s, '--', 'Color', c_2, 'LineWidth', 3, 'DisplayName', '2-Farm (150MW) - SLR/PLR');

% Add filled shading under the baseline to make it pop
area(x, pdf_1s, 'FaceColor', c_1s, 'FaceAlpha', 0.1, 'HandleVisibility', 'off');
area(x, pdf_1p, 'FaceColor', c_1p, 'FaceAlpha', 0.1, 'HandleVisibility', 'off');
area(x, pdf_2s, 'FaceColor', c_2,  'FaceAlpha', 0.1, 'HandleVisibility', 'off');

% 8. FORMATTING & THE MAGIC Y-LIMIT CAP
title('System Wind Curtailment Distribution', 'FontSize', 16, 'FontWeight', 'bold');
xlabel('Total Curtailment (MWh)', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Probability Density', 'FontSize', 14, 'FontWeight', 'bold');
legend('FontSize', 12, 'Location', 'northeast');
set(gca, 'FontSize', 12); 

% THE MAGIC CAP: This ensures the 90k curve is perfectly visible!
ylim([0, max(pdf_1s) * 1.5]); 
ax = gca; ax.YAxis.Exponent = -5;

fprintf('\n✅ Clean Curtailment PDF generated! The Y-axis has been optimized.\n');