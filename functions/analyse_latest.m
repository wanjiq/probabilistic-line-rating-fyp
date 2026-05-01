%% --- analyze_comprehensive_stats.m ---
clear; clc;

% =====================================================
% 1. SETUP & FILE PATHS
% =====================================================
scenarios = {
    '1. Base Grid (No Wind)',       'Results_NoWind/Final_Results_NoWind.xlsx';
    '2. Bulk (Bus 21 - 1000MW)',    'Results_Bus21_Unified/Final_Results_Bus21_Unified.xlsx';
    '3. DER (Bus 7 - 150MW)',       'Results_Bus7_Unified/Final_Results_Bus7_Unified.xlsx';
    '4. Small Bulk (Bus 13 - 50MW)','Results_Bus13_Unified/Final_Results_Bus13_Unified.xlsx'
};

VOLL = 1000; % $1,000 per MWh of EENS
percentiles = [50, 90, 95, 97.5, 99]; 

fprintf('\n=======================================================================================================\n');
fprintf('                                COMPREHENSIVE THESIS RISK & RELIABILITY REPORT                         \n');
fprintf('=======================================================================================================\n');

for i = 1:size(scenarios, 1)
    scen_name = scenarios{i, 1};
    file_path = scenarios{i, 2};
    
    if ~isfile(file_path)
        fprintf('\n⚠️ Skipping "%s" - File not found.\n', scen_name);
        continue;
    end
    
    % Load Data
    T = readtable(file_path, 'Sheet', 'System_Totals');
    eens_slr = T.EENS_SLR;
    eens_p5  = T.EENS_P5; 
    
    % Calculate Stats
    stats_slr = [mean(eens_slr), std(eens_slr), prctile(eens_slr, percentiles), max(eens_slr)];
    stats_p5  = [mean(eens_p5), std(eens_p5), prctile(eens_p5, percentiles), max(eens_p5)];
    
    % --- PRINT THE CONSOLE TABLE ---
    fprintf('\n>>> SCENARIO: %s <<<\n', upper(scen_name));
    fprintf('%-8s | %-8s | %-8s | %-8s | %-8s | %-8s | %-8s | %-8s | %-8s\n', ...
        'Rating', 'Mean', 'Std Dev', '50th', '90th', '95th', '97.5th', '99th', 'MAX');
    fprintf('-------------------------------------------------------------------------------------------------------\n');
    fprintf('%-8s | %8.0f | %8.0f | %8.0f | %8.0f | %8.0f | %8.0f | %8.0f | %8.0f\n', ...
        'SLR', stats_slr(1), stats_slr(2), stats_slr(3), stats_slr(4), stats_slr(5), stats_slr(6), stats_slr(7), stats_slr(8));
    fprintf('%-8s | %8.0f | %8.0f | %8.0f | %8.0f | %8.0f | %8.0f | %8.0f | %8.0f\n', ...
        'PLR 5%', stats_p5(1), stats_p5(2), stats_p5(3), stats_p5(4), stats_p5(5), stats_p5(6), stats_p5(7), stats_p5(8));
    
    % --- GENERATE THE NORMAL DISTRIBUTION GRAPH ---
    figure('Name', sprintf('Risk Distribution - %s', scen_name), 'Position', [100+(i*40), 100+(i*40), 900, 500]);
    hold on; grid on;
    
    % Create X-axis range
    min_val = min([eens_slr; eens_p5]); max_val = max([eens_slr; eens_p5]);
    x_range = linspace(min_val*0.7, max_val*1.3, 1000);
    
    % Plot SLR Bell Curve (Black)
    y_slr = normpdf(x_range, stats_slr(1), stats_slr(2));
    plot(x_range, y_slr, 'k-', 'LineWidth', 2.5, 'DisplayName', 'SLR (Strict Limits)');
    
    % Plot PLR 5% Bell Curve (Blue)
    y_p5 = normpdf(x_range, stats_p5(1), stats_p5(2));
    plot(x_range, y_p5, 'b-', 'LineWidth', 2.5, 'DisplayName', 'PLR 5% (Relaxed)');
    
    % Add Vertical Lines for Mean and 95th Percentile
    xline(stats_slr(1), 'k:', 'LineWidth', 1, 'DisplayName', 'SLR Mean');
    xline(stats_p5(1), 'b:', 'LineWidth', 1, 'DisplayName', 'PLR Mean');
    
    xline(stats_slr(5), 'k--', 'LineWidth', 1.5, 'DisplayName', 'SLR 95th (1-in-20 yr)');
    xline(stats_p5(5), 'b--', 'LineWidth', 1.5, 'DisplayName', 'PLR 95th (1-in-20 yr)');
    
    % Formatting
    title(sprintf('System EENS Normal Distribution\n%s', scen_name), 'FontSize', 14, 'FontWeight', 'bold');
    xlabel('Expected Energy Not Served (MWh)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Probability Density', 'FontSize', 12, 'FontWeight', 'bold');
    legend('Location', 'northeast');
    hold off;
end
fprintf('\n=======================================================================================================\n');