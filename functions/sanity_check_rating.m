%% sanity_check_rating.m
% Verify that interpolated rating really gives desired exceedance

clear; clc;

%% --- Load weather ---
file  = "weather_10yr.xlsx";
sheet = "Data";

Ttbl = readtable(file, "Sheet", sheet);

Ta  = Ttbl.air_temperature;
Wd  = mod(Ttbl.wind_direction, 360);
Vw  = max(Ttbl.wind_speed, 0);
Qse = Ttbl.Qse_Wm2;

% If wind is in knots, uncomment:
% Vw = Vw * 0.514444;

n = height(Ttbl);

%% --- Conductor constants ---
D0    = 0.02814;
eps   = 0.8;
alpha = 0.8;
R25   = 7.283e-05;
R75   = 8.688e-05;
Z1    = 90;

%% --- Rating to verify ---
I_test = 1206.7;   % ← your interpolated 5% rating
Tmax_check = 75;   % temperature limit

%% --- Tc solver settings ---
TolA = 0.5;
MaxIter = 50;

Tlow_min = -50;
Thigh0   = 120;
ThighMax = 500;
dThigh   = 50;

sgn = @(x) (x>=0)*2-1;

Tc = nan(n,1);

for i = 1:n
    Tlow  = max(Ta(i), Tlow_min);
    Thigh = max(Thigh0, Tlow + 5);

    f_low = Icalc(Tlow, Ta(i), Wd(i), Vw(i), Qse(i), D0, eps, alpha, R25, R75, Z1) - I_test;

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
            Thigh = Tmid;
        else
            Tlow = Tmid;
            f_low = f_mid;
        end
    end
end

%% --- Compute exceedance ---
Tc_valid = Tc(~isnan(Tc));
exceedance = mean(Tc_valid >= Tmax_check);

fprintf("\nSanity check result:\n");
fprintf("At I = %.1f A\n", I_test);
fprintf("P(Tc >= %.0f°C) = %.4f (%.2f%%)\n", ...
    Tmax_check, exceedance, 100*exceedance);
