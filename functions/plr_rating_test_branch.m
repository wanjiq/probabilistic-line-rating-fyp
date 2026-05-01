clc; clear; close all;
define_constants;

%% Load RTS-24 case
mpc0 = loadcase('case24_ieee_rts');

%% --- PLR Rating ---
I_PLR_A = 1206.1;     % 7% exceedance @ 75°C

%% --- Choose transmission line (NOT transformer) ---
br = 23;   % Branch 8 : Bus 4 - Bus 9

%% --- Convert Current (A) -> MVA limit ---
from_bus = mpc0.branch(br, F_BUS);
to_bus   = mpc0.branch(br, T_BUS);

V_kV = mpc0.bus(from_bus, BASE_KV);

I_kA = I_PLR_A / 1000;

rateA_MVA = sqrt(3) * V_kV * I_kA;

fprintf('\nApplying PLR rating:\n');
fprintf('Branch %d (%d-%d)\n', br, from_bus, to_bus);
fprintf('Voltage Level = %.1f kV\n', V_kV);
fprintf('PLR Current   = %.1f A\n', I_PLR_A);
fprintf('Converted RATE_A = %.2f MVA\n\n', rateA_MVA);

%% --- Apply PLR rating ---
mpc = mpc0;
mpc.branch(br, RATE_A) = rateA_MVA;

%% --- Run AC OPF ---
mpopt = mpoption('verbose', 1, ...
                 'out.all', 0, ...
                 'opf.ac.solver', 'MIPS');

res = runopf(mpc, mpopt);

fprintf('\nOPF success = %d\n\n', res.success);

%% --- Check Line Loading ---
if res.success
    
    flowMW = abs(res.branch(br, PF));
    limitMVA = res.branch(br, RATE_A);
    loadingPct = 100 * flowMW / max(1e-6, limitMVA);
    
    fprintf('Flow on branch %d = %.2f MW\n', br, flowMW);
    fprintf('Limit (RATE_A)    = %.2f MVA\n', limitMVA);
    fprintf('Loading           = %.2f %%\n', loadingPct);
    
else
    fprintf('OPF did NOT converge.\n');
end
