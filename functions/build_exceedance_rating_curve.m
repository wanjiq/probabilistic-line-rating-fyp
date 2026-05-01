%% build_exceedance_rating_curve.m
% FLOW:
% 1) Solve Tc(t) for each test current
% 2) Compute exceedance above Tmax for each current
% Outputs: I_list, Pexc_I, Tmax_fixed saved to .mat for querying later

% DON'T clearvars here (it breaks the driver script)
clc; close all;

%% ---- File ----
file  = "weather_10yr.xlsx";
sheet = "Data";

%% ---- Conductor constants (match Excel) ----
D0    = 0.02814;      % m
eps   = 0.8;
alpha = 0.8;
R25   = 7.283e-05;    % ohm/m
R75   = 8.688e-05;    % ohm/m
Z1    = 90;           % deg

%% ---- USER CHOICES ----
if ~exist("Tmax_fixed","var")
    Tmax_fixed = 75;   % default
end
                 % °C  <-- max conductor temperature threshold
I_list = (700:50:2000)';         % A   <-- rating candidates (use smaller step for smoother results)

%% ---- Tc solver settings ----
TolA = 0.5;
MaxIter = 50;

Tlow_min = -50;
Thigh0   = 120;
ThighMax = 500;   % allow higher if you are testing big currents
dThigh   = 50;

sgn = @(x) (x>=0)*2-1;

%% ---- Read weather (whole year) ----
Ttbl = readtable(file, "Sheet", sheet);

t   = datetime(Ttbl.ob_time);
Ta  = Ttbl.air_temperature;
Wd  = mod(Ttbl.wind_direction, 360);
Vw  = max(Ttbl.wind_speed, 0);
Qse = Ttbl.Qse_Wm2;

% If wind speed is knots, uncomment:
% Vw = Vw * 0.514444;

n = numel(t);
fprintf("Using full year: %d samples\n", n);

%% ---- Output: exceedance vs current ----
Pexc_I = nan(numel(I_list),1);    % P(Tc >= Tmax_fixed) for each current
validFrac = nan(numel(I_list),1); % fraction of hours where Tc solved (not NaN)
TcMax = nan(numel(I_list),1);     % optional: max Tc for sanity

for j = 1:numel(I_list)
    I_test = I_list(j);
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

        while sgn(f_low) == sgn(f_high) && Thigh < ThighMax
            Thigh = Thigh + dThigh;
            f_high = Icalc(Thigh, Ta(i), Wd(i), Vw(i), Qse(i), D0, eps, alpha, R25, R75, Z1) - I_test;

            if abs(f_high) < TolA
                Tc(i) = Thigh;
                break;
            end
        end

        if ~isnan(Tc(i)), continue; end
        if sgn(f_low) == sgn(f_high)
            Tc(i) = NaN;
            continue;
        end

        for k = 1:MaxIter
            Tmid  = 0.5*(Tlow + Thigh);
            f_mid = Icalc(Tmid, Ta(i), Wd(i), Vw(i), Qse(i), D0, eps, alpha, R25, R75, Z1) - I_test;

            Tc(i) = Tmid;

            if abs(f_mid) < TolA
                break;
            end

            if sgn(f_low) ~= sgn(f_mid)
                Thigh = Tmid; f_high = f_mid;
            else
                Tlow = Tmid;  f_low  = f_mid;
            end
        end
    end

    valid = ~isnan(Tc);
    Tc_v = Tc(valid);

    validFrac(j) = mean(valid);
    TcMax(j) = max(Tc_v);

    % Exceedance probability above Tmax_fixed
    Pexc_I(j) = mean(Tc_v >= Tmax_fixed);

    fprintf("I=%4d A: valid=%.1f%%, exceed(T>=%.0f)=%.3f\n", ...
        I_test, 100*validFrac(j), Tmax_fixed, Pexc_I(j));
end



%% ---- Save results for query step ----
save("rating_curve_Tmax.mat", "I_list", "Pexc_I", "Tmax_fixed", "validFrac", "TcMax");
disp("Saved: rating_curve_Tmax.mat");
