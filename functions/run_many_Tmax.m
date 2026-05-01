%% run_many_Tmax.m
clear; clc; close all;

Tmax_list = 70:5:100;      % sweep Tmax
ex_list = [0.1 0.2 0.5 1 2 3 5 7 10];      % exceedance levels (%)

results = nan(numel(Tmax_list), numel(ex_list));

% store all curves (same I_list assumed for all runs)
I_ref = [];
Pexc_mat = [];             % size: [num_I  x  num_Tmax]

for a = 1:numel(Tmax_list)
    Tmax_fixed = Tmax_list(a);

    build_exceedance_rating_curve
    load("rating_curve_Tmax.mat", "I_list", "Pexc_I");

    if isempty(I_ref)
        I_ref = I_list;
        Pexc_mat = nan(numel(I_ref), numel(Tmax_list));
    end
    Pexc_mat(:,a) = Pexc_I;

    for b = 1:numel(ex_list)
        results(a,b) = rating_from_exceedance(I_list, Pexc_I, ex_list(b));
    end

    fprintf("Tmax=%d°C -> PLR 1%%=%.1f A, 2%%=%.1f A, 5%%=%.1f A\n", ...
        Tmax_fixed, results(a,1), results(a,2), results(a,3));
end

% Save PLR table
T = array2table(results, "VariableNames", "PLR_" + string(ex_list) + "pct");
T.Tmax_C = Tmax_list(:);
T = movevars(T, "Tmax_C", "Before", 1);
writetable(T, "PLR_vs_Tmax.xlsx");
disp("Saved: PLR_vs_Tmax.xlsx");

% Save all curves to ONE mat file for querying
save("PLR_dataset.mat", "Tmax_list", "I_ref", "Pexc_mat");
disp("Saved: PLR_dataset.mat");

%% Also export the same dataset to Excel (for supervisor/plots)
PLR_table = array2table(Pexc_mat);
PLR_table.Properties.VariableNames = "Pexc_T" + string(Tmax_list);

PLR_table.Current_A = I_ref(:);
PLR_table = movevars(PLR_table, "Current_A", "Before", 1);

writetable(PLR_table, "PLR_dataset.xlsx", "Sheet", "PLR_Curves");
disp("Saved: PLR_dataset.xlsx");