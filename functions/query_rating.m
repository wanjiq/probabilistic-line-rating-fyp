%% query_rating.m
clear; clc;

load("PLR_dataset.mat", "Tmax_list", "I_ref", "Pexc_mat");

fprintf("\n=== Rating Query Tool (Multi-Tmax) ===\n");
fprintf("Available Tmax values: %s °C\n", strjoin(string(Tmax_list), ", "));

while true
    Tmax = input("\nEnter Tmax (e.g., 70, 75, 80). Type -1 to quit: ");
    if isempty(Tmax), continue; end
    if Tmax == -1
        fprintf("Bye.\n");
        break;
    end

    idx = find(Tmax_list == Tmax, 1);
    if isempty(idx)
        fprintf("Tmax=%g°C not found. Choose one of: %s\n", Tmax, strjoin(string(Tmax_list), ", "));
        continue;
    end

    p = input("Enter exceedance percentage (e.g., 1, 2, 5, 7): ");
    if isempty(p), continue; end
    if p <= 0 || p >= 100
        fprintf("Please enter a value between 0 and 100.\n");
        continue;
    end

    Pexc_I = Pexc_mat(:, idx);                 % curve for chosen Tmax
    I_rating = rating_from_exceedance(I_ref, Pexc_I, p);

    if isnan(I_rating)
        fprintf("Result: NaN (outside computed range). Extend I_list.\n");
    else
        fprintf("Tmax=%.0f°C, exceedance=%.2f%% -> rating ≈ %.1f A\n", Tmax, p, I_rating);
    end
end
