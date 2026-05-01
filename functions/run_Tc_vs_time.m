%% run_Tcvs_time.m
% Compute conductor temperature Tc(t) for a fixed test current I_test
% using Icalc(Tc, ...) inversion with robust bracketing + bisection.
%
% REQUIREMENTS (same folder):
%   - Icalc.m   (your corrected version with phi folded to 0–90 like Excel)
%   - weather_10yr.xlsx

clear; clc; close all;

%% ---- Settings ----
file  = "weather_10yr.xlsx";
sheet = "Data";

I_test = 2000;    % A  <<< TEST CURRENT SET TO 2000 A

% Conductor constants (match Excel)
D0    = 0.02814;      % m
eps   = 0.8;
alpha = 0.8;
R25   = 7.283e-05;    % ohm/m
R75   = 8.688e-05;    % ohm/m
Z1    = 90;           % deg line azimuth

%% ---- Read table ----
Ttbl = readtable(file, "Sheet", sheet);

% Time axis
t = datetime(Ttbl.ob_time);

% Weather inputs
Ta  = Ttbl.air_temperature;   % °C
Wd  = Ttbl.wind_direction;    % deg
Vw  = Ttbl.wind_speed;        % m/s  (IF this is knots, convert below)
Qse = Ttbl.Qse_Wm2;           % W/m^2

% --- If your wind speed column is actually in knots, uncomment this:
% Vw = Vw * 0.514444;

% Basic cleaning
Vw = max(Vw, 0);
Wd = mod(Wd, 360);

n  = height(Ttbl);
Tc = nan(n,1);

fprintf("Loaded %d rows from %s (sheet: %s)\n", n, file, sheet);

%% ---- Solve Tc per row (robust bracket + bisection) ----
TolA = 0.5;          % tolerance in A
MaxIter = 50;

Tlow_min = -50;      % °C
Thigh0   = 120;      % °C
ThighMax = 400;      % °C
dThigh   = 40;       % °C expansion step

sgn = @(x) (x>=0)*2-1;  % avoids sign(0)=0 issues

for i = 1:n
    Tlow  = max(Ta(i), Tlow_min);
    Thigh = max(Thigh0, Tlow + 5);

    f_low = Icalc(Tlow,  Ta(i), Wd(i), Vw(i), Qse(i), D0, eps, alpha, R25, R75, Z1) - I_test;

    % If already solved at the lower bound
    if abs(f_low) < TolA
        Tc(i) = Tlow;
        continue;
    end

    f_high = Icalc(Thigh, Ta(i), Wd(i), Vw(i), Qse(i), D0, eps, alpha, R25, R75, Z1) - I_test;

    % Expand upper bound until sign change or hit ThighMax
    while sgn(f_low) == sgn(f_high) && Thigh < ThighMax
        Thigh = Thigh + dThigh;
        f_high = Icalc(Thigh, Ta(i), Wd(i), Vw(i), Qse(i), D0, eps, alpha, R25, R75, Z1) - I_test;

        if abs(f_high) < TolA
            Tc(i) = Thigh;
            break;
        end
    end

    % Solved during expansion
    if ~isnan(Tc(i))
        continue;
    end

    % Still not bracketed
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

%% ---- Summary ----
solved = sum(~isnan(Tc));
fprintf("Solved Tc for %d/%d rows (%.1f%%)\n", solved, n, 100*solved/n);

%% ---- Plot Tc vs time ----
figure;
plot(t, Tc);
xlabel("Time");
ylabel("Conductor temperature T_c (°C)");
title(sprintf("T_c vs time at I = %d A", I_test));
grid on;

%% ---- Save back to Excel ----
Ttbl.Tc_MATLAB = Tc;
outFile = "weather_10yr_with_TcMATLAB.xlsx";
writetable(Ttbl, outFile, "Sheet", sheet);
disp("Saved: " + outFile);

%% ---- OPTIONAL: quick row check (uncomment to use) ----
% row = 2;
% Tc_excel = 61.06292504; % Excel Tc for that SAME row
% I_row = Icalc(Tc_excel, Ta(row), Wd(row), Vw(row), Qse(row), D0, eps, alpha, R25, R75, Z1);
% fprintf("Row %d check: Icalc(Tc_excel) = %.3f A\n", row, I_row);
