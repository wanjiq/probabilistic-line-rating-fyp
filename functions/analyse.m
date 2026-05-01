%% --- analyze_results.m ---
clear; clc;

% --- Configuration ---
buses = [7, 13, 21];
VOLL = 1000; % $1,000 per MWh of Expected Energy Not Served
percentile_levels = [5, 50, 95]; % 5th (Lucky), 50th (Median), 95th (Worst-Case)
scenarios = {'SLR', 'P5', 'P10', 'P15'};

fprintf('======================================================================================\n');
fprintf('                   MONTE CARLO STATISTICAL ANALYSIS & COST REPORT                     \n');
fprintf('======================================================================================\n\n');

for b = 1:length(buses)
    current_bus = buses(b);
    file_path = sprintf('Results_Bus%d_Unified/Final_Results_Bus%d_Unified.xlsx', current_bus, current_bus);
    
    if ~isfile(file_path)
        fprintf('⚠️ Could not find data for Bus %d. Skipping...\n\n', current_bus);
        continue;
    end
    
    % Load the Data
    T = readtable(file_path, 'Sheet', 'System_Totals');
    
    % Initialize Figure for Normal Distribution Plots
    figure('Name', sprintf('EENS Distribution - Bus %d', current_bus), 'Position', [100, 100, 1000, 600]);
    sgtitle(sprintf('Monte Carlo EENS Distribution: Wind Farm at Bus %d', current_bus), 'FontSize', 14, 'FontWeight', 'bold');
    
    % Print Header for this Bus
    fprintf('>>> BUS %d WIND FARM (200 Iterations) <<<\n', current_bus);
    fprintf('%-8s | %-10s | %-10s | %-10s | %-10s | %-15s\n', 'Scenario', 'Mean (MWh)', '5th (MWh)', '50th (MWh)', '95th (MWh)', 'Mean Cost ($)');
    fprintf('--------------------------------------------------------------------------------------\n');
    
    colors = {[0.2 0.2 0.5], [0.8 0.4 0.1], [0.2 0.6 0.3], [0.7 0.2 0.2]};
    
    for s = 1:length(scenarios)
        scen_name = scenarios{s};
        col_name = sprintf('EENS_%s', scen_name);
        
        % Extract Data
        eens_data = T.(col_name);
        
        % Calculate Statistics
        eens_mean = mean(eens_data);
        eens_std  = std(eens_data);
        eens_prc  = prctile(eens_data, percentile_levels);
        
        % Calculate Cost
        mean_cost = eens_mean * VOLL;
        
        % Print Row
        fprintf('%-8s | %10.0f | %10.0f | %10.0f | %10.0f | $%12.2f\n', ...
            scen_name, eens_mean, eens_prc(1), eens_prc(2), eens_prc(3), mean_cost);
        
        % --- Plot Subplot ---
        subplot(2, 2, s);
        hold on; grid on;
        
        % Plot Histogram
        h = histogram(eens_data, 'Normalization', 'pdf', 'FaceColor', colors{s}, 'FaceAlpha', 0.6);
        
        % Plot Ideal Normal Distribution Curve overlaid on data
        x_vals = linspace(min(eens_data)*0.8, max(eens_data)*1.2, 100);
        y_vals = normpdf(x_vals, eens_mean, eens_std);
        plot(x_vals, y_vals, 'k-', 'LineWidth', 2);
        
        title(sprintf('Scenario: %s', scen_name));
        xlabel('System EENS (MWh)');
        ylabel('Probability Density');
        
        % Add text box with Mean and Std
        dim = [0.15 0.6 0.3 0.3];
        str = {sprintf('Mean: %.0f', eens_mean), sprintf('Std Dev: %.0f', eens_std)};
        annotation('textbox', gca().Position, 'String', str, 'FitBoxToText', 'on', 'BackgroundColor', 'w', 'EdgeColor', 'k');
        
        hold off;
    end
    fprintf('\n'); % Space before next bus
end
fprintf('======================================================================================\n');