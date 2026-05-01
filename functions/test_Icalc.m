clc; clear;

%% === USER INPUTS (edit these) ===
Tc_test = 61.06292504;     % °C (from your Excel row)
Ta      = 7.7;             % °C  <-- change to your actual ambient used in Excel
Wd      = 210.1;            % deg wind direction (from your row)
Vw      = 8.3;            % m/s  <-- ensure units match Excel
Qse     = 0;               % W/m^2 (your row shows solar gain 0, so set 0)
D0      = 0.02814;           % m  <-- conductor diameter (IMPORTANT: must be meters)
eps     = 0.8;             % emissivity
alpha   = 0.8;             % solar absorptivity
R25     = 7.28e-5;          % ohm/m at 25C (example)
R75     = 8.69e-5;          % ohm/m at 75C (example)
Z1      = 90;               % deg line azimuth

I_test  = 2000;            % A (your test current)

%% === CALL Icalc() ===
I_calc = Icalc(Tc_test, Ta, Wd, Vw, Qse, D0, eps, alpha, R25, R75, Z1);

%% === Recompute internals for debugging (must match your Icalc.m equations) ===
% Wind-to-line angle
d = abs(Wd - Z1);      % d = ABS(H2 - Z1)

a = d;
if a > 180
    a = 360 - a;       % IF(d>180, 360-d, d)
end

phi = a;
if phi > 90
    phi = 180 - phi;   % IF(a>90, 180-a, a)
end


Kangle = 1.194 - cosd(phi) + 0.194*cosd(2*phi) + 0.368*sind(2*phi);

Tfilm = 0.5*(Tc_test + Ta);

mu  = 1.458e-6 * ((Tfilm + 273)^(3/2)) / (Tfilm + 383.4); % kg/(m*s)
rho = 1.293 / (1 + 0.00367*Tfilm);                            % kg/m^3
kf  = 0.02424 + 7.477e-5*Tfilm - 4.407e-9*Tfilm^2;           % W/(m*C)

Re = (D0 * rho * Vw) / mu;

dT  = max(Tc_test - Ta, 0);

qcn = 3.645 * sqrt(rho) * (D0^0.75) * (dT^1.25);
qc1 = Kangle * (1.01 + 1.35*(Re^0.52)) * kf * dT;
qc2 = Kangle * 0.754 * (Re^0.6) * kf * dT;
qc  = max([qcn qc1 qc2]);

qr = 17.8 * D0 * eps * (((Tc_test+273)/100)^4 - ((Ta+273)/100)^4);

qs = alpha * Qse * D0;

R  = R25 + (Tc_test - 25) * (R75 - R25) / (75 - 25);

% Heat balance residual for I_test at Tc_test:
% res = I^2 R + qs - (qc + qr)
res = I_test^2 * R + qs - (qc + qr);

%% === PRINT RESULTS ===
fprintf('\n=== INPUTS ===\n');
fprintf('Tc_test = %.6f C\nTa      = %.6f C\nWd      = %.3f deg\nZ1      = %.3f deg\n', Tc_test, Ta, Wd, Z1);
fprintf('Vw      = %.6f m/s\nQse     = %.3f W/m^2\nD0      = %.6f m\neps     = %.3f\nalpha   = %.3f\n', Vw, Qse, D0, eps, alpha);
fprintf('R25     = %.8e ohm/m\nR75     = %.8e ohm/m\n', R25, R75);

fprintf('\n=== GEOMETRY / AIR ===\n');
fprintf('phi     = %.6f deg\nKangle  = %.6f\n', phi, Kangle);
fprintf('Tfilm   = %.6f C\nmu      = %.8e kg/(m*s)\n', Tfilm, mu);
fprintf('rho     = %.8f kg/m^3\nkf      = %.8f W/(m*C)\n', rho, kf);
fprintf('Re      = %.6f\n', Re);

fprintf('\n=== HEAT TERMS (W/m) ===\n');
fprintf('qcn (natural)  = %.6f\n', qcn);
fprintf('qc1 (forced 1) = %.6f\n', qc1);
fprintf('qc2 (forced 2) = %.6f\n', qc2);
fprintf('qc  (max)      = %.6f\n', qc);
fprintf('qr (radiation) = %.6f\n', qr);
fprintf('qs (solar)     = %.6f\n', qs);

fprintf('\n=== ELECTRICAL ===\n');
fprintf('R(Tc)          = %.8e ohm/m\n', R);
fprintf('I_calc(Tc)     = %.6f A\n', I_calc);

fprintf('\n=== HEAT BALANCE CHECK ===\n');
fprintf('I_test         = %.3f A\n', I_test);
fprintf('Residual res = I_test^2*R + qs - (qc + qr) = %.6f W/m\n', res);
fprintf('(If Tc_test is correct for I_test, residual should be ~0.)\n');

%% === OPTIONAL: Solve Tc for given I_test ===
do_solve = true;

if do_solve
    f = @(Tc) (I_test^2 * (R25 + (Tc - 25) * (R75 - R25) / (75 - 25))) ...
              + (alpha*Qse*D0) ...
              - convection_plus_radiation(Tc, Ta, Wd, Vw, D0, eps, Z1);
    
    % bracket search
    Tc_low  = Ta;
    Tc_high = Ta + 200;
    if f(Tc_low)*f(Tc_high) > 0
        warning('Root not bracketed. Increase Tc_high or check inputs/units.');
    else
        Tc_sol = fzero(f, [Tc_low Tc_high]);
        fprintf('\n=== SOLVED Tc for I_test ===\n');
        fprintf('Tc_sol = %.6f C\n', Tc_sol);
    end
end

%% ---- helper function used by the solver ----
function Qout = convection_plus_radiation(Tc, Ta, Wd, Vw, D0, eps, Z1)
    d = abs(Wd - Z1);

a = d;
if a > 180
    a = 360 - a;
end

phi = a;
if phi > 90
    phi = 180 - phi;
end

    Kangle = 1.194 - cosd(phi) + 0.194*cosd(2*phi) + 0.368*sind(2*phi);

    Tfilm = 0.5*(Tc + Ta);
    mu  = 1.458e-6 * ((Tfilm + 273)^(3/2)) / (Tfilm + 383.4);
    rho = 1.293 / (1 + 0.00367*Tfilm);
    kf  = 0.02424 + 7.5477e-5*Tfilm - 4.407e-9*Tfilm^2;
    Re  = (D0 * rho * max(Vw,0)) / mu;

    dT  = max(Tc - Ta, 0);
    qcn = 3.645 * sqrt(rho) * (D0^0.75) * (dT^1.25);
    qc1 = Kangle * (1.01 + 1.35*(Re^0.52)) * kf * dT;
    qc2 = Kangle * 0.754 * (Re^0.6) * kf * dT;
    qc  = max([qcn qc1 qc2]);

    qr = 17.8 * D0 * eps * (((Tc+273)/100)^4 - ((Ta+273)/100)^4);

    Qout = qc + qr;
end
