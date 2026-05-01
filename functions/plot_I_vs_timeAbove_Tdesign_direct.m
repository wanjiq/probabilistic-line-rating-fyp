%% plot_I_vs_timeAbove_Tdesign_direct.m
% DIRECT METHOD:
% For each current I, solve Tc(t;I) hourly, then compute aggregate time above each Tdesign.
% Plot: y = current, x = aggregate time above Tdesign (%) for the WHOLE YEAR (no seasonal filter).
% Linear x-axis (NOT log).

clear; clc; close all;

%% ---- File ----
file  = "weather_10yr.xlsx";
sheet = "Data";

%% ---- Conductor constants (match Excel) ----
D0    = 0.02814;      % m
eps   = 0.8;
alpha = 0.8;
R25   = 7.283e-05;    % ohm/m
R75   = 8.688e-05;    % ohm/m
Z1    = 90;           % deg line azimuth

%% ---- Currents to sweep (y-axis) ----
I_list = (700:50:2000)';   % A (edit step if you want smoother)

%% ---- Design temperatures (curves) ----
Tdesign_list = (50:5:110); % °C (edit)

%% ---- Tc solver settings ----
TolA = 0.5;          % tolerance in A
MaxIter = 50;

Tlow_min = -50;
Thigh0   = 120;
ThighMax = 400;
dThigh   = 40;

sgn = @(x) (x>=0)*2-1;   % avoids sign(0)=0 issues

%% ---- Read weather (WHOLE YEAR) ----
Ttbl = readtable(file, "Sheet", sheet);

t   = datetime(Ttbl.ob_time);
Ta  = Ttbl.air_temperature;
Wd  = mod(Ttbl.wind_direction, 360);
Vw  = max(Ttbl.wind_speed, 0);
Qse = Ttbl.Qse_Wm2;

% If wind is in knots, uncomment:
% Vw = Vw * 0.514444;

n = numel(t);
fprintf("Using full year: %d samples\n", n);

%% ---- Output: exceedance fraction matrix Pexc(I, Tdesign) ----
Pexc = nan(numel(I_list), numel(Tdesign_list));  % fraction of time Tc>=Tdesign

%% ---- Main sweep over currents (DIRECT Tc solving) ----
for j = 1:numel(I_list)
    I_test = I_list(j);

    % Solve Tc(t; I_test)
    Tc = nan(n,1);

    for i = 1:n
        Tlow  = max(Ta(i), Tlow_min);
        Thigh = max(Thigh0, Tlow + 5);

        f_low = Icalc(Tlow,  Ta(i), Wd(i), Vw(i), Qse(i), D0, eps, alpha, R25, R75, Z1) - I_test;

        if abs(f_low) < TolA
            Tc(i) = Tlow;
            continue;
        end

        f_high = Icalc(Thigh, Ta(i), Wd(i), Vw(i), Qse(i), D0, eps, alpha, R25, R75, Z1) - I_test;

        % Expand upper bound if needed
        while sgn(f_low) == sgn(f_high) && Thigh < ThighMax
            Thigh = Thigh + dThigh;
            f_high = Icalc(Thigh, Ta(i), Wd(i), Vw(i), Qse(i), D0, eps, alpha, R25, R75, Z1) - I_test;

            if abs(f_high) < TolA
                Tc(i) = Thigh;
                break;
            end
        end

        if ~isnan(Tc(i))
            continue;
        end

        % If still no bracket, Tc required is beyond ThighMax (or impossible)
        if sgn(f_low) == sgn(f_high)
            Tc(i) = NaN;
            continue;
        end

        % Bisection
        for k = 1:MaxIter
            Tmid  = 0.5*(Tlow + Thigh);
            f_mid = Icalc(Tmid, Ta(i), Wd(i), Vw(i), Qse(i), D0, eps, alpha, R25, R75, Z1) - I_test;

            Tc(i) = Tmid;

            if abs(f_mid) < TolA
                break;
            end

            if sgn(f_low) ~= sgn(f_mid)
                Thigh = Tmid;
                f_high = f_mid;
            else
                Tlow = Tmid;
                f_low = f_mid;
            end
        end
    end

    % Compute exceedance fractions for each design temperature
    valid = ~isnan(Tc);
    Tc_valid = Tc(valid);

    for k = 1:numel(Tdesign_list)
        Td = Tdesign_list(k);
        Pexc(j,k) = mean(Tc_valid >= Td); % fraction of time above Td
    end

    fprintf("I=%4d A done. valid=%d/%d\n", I_test, sum(valid), n);
end

%% ---- Plot: y=current, x=aggregate time above Td (LINEAR axis) ----
figure; hold on;

for k = 1:numel(Tdesign_list)
    x = 100 * Pexc(:,k);  % %
    y = I_list;           % A
    plot(x, y, 'LineWidth', 1.6);
end

grid on;
xlabel("Aggregate time above design temperature (%)");
ylabel("Current (A)");
title("Current rating vs time above design temperature (Full year, direct Tc solve)");
xlim([0 100]);  % percentage axis

legend(string(Tdesign_list) + "°C", "Location", "eastoutside");
hold off;

%% ---- Save matrix for report ----
out = array2table(Pexc, 'VariableNames', "T_" + string(Tdesign_list));
out.I_test_A = I_list;
out = movevars(out, 'I_test_A', 'Before', 1);

writetable(out, "I_vs_timeAbove_matrix_full_year.xlsx");
disp("Saved: I_vs_timeAbove_matrix_full_year.xlsx");
