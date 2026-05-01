clc; clear;
define_constants;

%% 1) Load RTS-96 (24-bus)
mpc_base = loadcase('case24_ieee_rts');

%% 2) Make loads dispatchable (curtailable) with high penalty (VOLL)
VOLL = 10000;                       % $/MWh, pick big so shedding is last resort
mpc_base = load2disp(mpc_base, [], [], VOLL);   % :contentReference[oaicite:1]{index=1}

%% 3) AC OPF options (AC is default, so do NOT set opf.dc)
mpopt = mpoption('verbose', 0, 'out.all', 0);

%% 4) Define load scaling factors (lambda)
lam = 1.0 : 0.05 : 2.0;             % 1.00 to 2.00 in 5% steps
ENS_MWh_1h = nan(size(lam));        % ENS for a 1-hour snapshot at each lambda
success = false(size(lam));

%% 5) Ramp study
for k = 1:numel(lam)
    mpc = mpc_base;

    % Scale ALL loads (both fixed + dispatchable) in P and Q
    opt = struct('scale','FACTOR','pq','PQ','which','BOTH');
    mpc = scale_load(lam(k), mpc, [], opt);      % :contentReference[oaicite:2]{index=2}

    % Run standard AC OPF
    r = runopf(mpc, mpopt);
    success(k) = (r.success == 1);

    if ~success(k)
        continue;  % keep NaN
    end

    % Amount of load shed (MW) from dispatchable loads
    shed_MW = sum(loadshed(r.gen));              % :contentReference[oaicite:3]{index=3}
    ENS_MWh_1h(k) = shed_MW * 1.0;               % 1 hour -> MWh
end

%% 6) Results table + plot
T = table(lam(:), success(:), ENS_MWh_1h(:), ...
    'VariableNames', {'lambda','opf_success','ENS_MWh_per_hour'});
disp(T);

figure;
plot(lam, ENS_MWh_1h, '-o'); grid on;
xlabel('Load scaling factor \lambda');
ylabel('ENS (MWh for 1 hour)');
title('IEEE RTS-96 (24-bus): AC OPF Load Ramp (with load shedding)');
writetable(T, 'rts96_acopf_load_ramp_ens.xlsx');