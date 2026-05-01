%% plot_exceedance_from_dataset.m
clear; clc; close all;

load("PLR_dataset.mat", "Tmax_list", "I_ref", "Pexc_mat");

figure; hold on; grid on;

for a = 1:numel(Tmax_list)
    plot(I_ref, 100*Pexc_mat(:,a), 'LineWidth', 1.6, ...
        'DisplayName', sprintf("Tmax = %d°C", Tmax_list(a)));
end

xlabel("Current I (A)");
ylabel("Exceedance Probability (%)");
title("Exceedance vs Current for Multiple Design Temperatures");
legend("Location","best");
