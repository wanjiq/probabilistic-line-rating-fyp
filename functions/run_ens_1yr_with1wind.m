%% run_eens_1yr_with1wind_dispatchableLoads.m
% 1-year (8760h) DC-OPF with:
% - dispatchable loads (MATPOWER load2disp) for ENS
% - one wind generator (hourly PMAX = P_wind_1yr)
%
% Output:
% - Results table (hourly ENS, wind used, etc.)
% - EENS_year (MWh/year)

clear; clc;
define_constants;

%% ---------------- USER SETTINGS ----------------
case_name   = 'case24_ieee_rts';   % MATPOWER case
wind_bus    = 7;                  % connect wind here
VOLL        = 1e5;                % $/MWh for shedding (must be HIGH)
use_dc      = 1;                  % 1=DC OPF (fast), 0=AC OPF (slow)

%% ---------------- LOAD WIND PROFILE ----------------
S = load('wind_profile_1yr.mat');        % must contain P_wind_1yr
assert(isfield(S,'P_wind_1yr'), "wind_profile_1yr.mat must contain variable 'P_wind_1yr'");
P_wind_1yr = S.P_wind_1yr(:);
assert(numel(P_wind_1yr)==8760, "P_wind_1yr must be 8760x1");

% wind nameplate
if isfield(S,'Pr')
    Pwind_rated = S.Pr;
else
    Pwind_rated = max(P_wind_1yr);
end

%% ---------------- CONVERT LOADS -> DISPATCHABLE LOADS ----------------
% IMPORTANT: for your MATPOWER version, pass the CASE NAME (string), not an mpc struct
% allow_load_increase = 1 (recommended)
mpc0 = load2disp(case_name, VOLL, 1);

% Identify the dispatchable loads among "gen" rows:
% They are negative generators (PMIN < 0) with PMAX == 0 in typical MATPOWER output.
is_dload = (mpc0.gen(:, PMAX) == 0) & (mpc0.gen(:, PMIN) < 0);
dload_idx = find(is_dload);

fprintf('Dispatchable loads created: %d\n', numel(dload_idx));

%% ---------------- ADD ONE WIND GENERATOR ----------------
gT = mpc0.gen(1,:);
gW = gT;
gW(GEN_BUS)    = wind_bus;
gW(PG)         = 0;
gW(QG)         = 0;
gW(QMAX)       = 0;
gW(QMIN)       = 0;
gW(VG)         = 1.0;
gW(MBASE)      = mpc0.baseMVA;
gW(GEN_STATUS) = 1;
gW(PMAX)       = Pwind_rated;   % overwritten hourly
gW(PMIN)       = 0;

mpc0.gen(end+1,:) = gW;
wind_gen_idx = size(mpc0.gen,1);

% matching gencost row for wind (zero marginal cost)
% gencost format: [MODEL STARTUP SHUTDOWN NCOST c1 c0] for linear
mpc0.gencost(end+1,:) = [2 0 0 2 0 0];

fprintf('Wind generator added at bus %d (gen row %d), rated %.1f MW\n', wind_bus, wind_gen_idx, Pwind_rated);

%% ---------------- OPF OPTIONS ----------------
mpopt = mpoption('verbose',0,'out.all',0);
if use_dc
    mpopt = mpoption(mpopt,'opf.dc',1);
end

%% ---------------- RUN 8760 HOURS ----------------
ENS_MWh      = zeros(8760,1);
WindAvail_MW = zeros(8760,1);
WindUsed_MW  = zeros(8760,1);
OPFsuccess   = false(8760,1);

for h = 1:8760
    mpc = mpc0;

    % set wind availability (PMAX) for this hour
    Pav = max(0, min(Pwind_rated, P_wind_1yr(h)));
    mpc.gen(wind_gen_idx, PMAX) = Pav;
    mpc.gen(wind_gen_idx, PMIN) = 0;
    mpc.gen(wind_gen_idx, PG)   = 0;

    WindAvail_MW(h) = Pav;

    r = runopf(mpc, mpopt);
    OPFsuccess(h) = r.success;

    if r.success
        WindUsed_MW(h) = r.gen(wind_gen_idx, PG);

        % Dispatchable loads are negative generators.
        % Their PG will be negative; the magnitude corresponds to load reduction.
        shed_MW = -sum(r.gen(dload_idx, PG));     % positive MW shed
        ENS_MWh(h) = max(0, shed_MW) * 1;         % 1 hour timestep
    else
        WindUsed_MW(h) = NaN;
        ENS_MWh(h)     = NaN;
    end
end

ok = OPFsuccess & ~isnan(ENS_MWh);
EENS_year = sum(ENS_MWh(ok));

fprintf('\n=== RESULTS (1 year) ===\n');
fprintf('OPF success rate: %.2f%%\n', 100*mean(OPFsuccess));
fprintf('EENS (MWh/year):  %.2f\n', EENS_year);
fprintf('Avg wind avail (MW): %.2f\n', mean(WindAvail_MW(ok)));
fprintf('Avg wind used  (MW): %.2f\n', mean(WindUsed_MW(ok),'omitnan'));
fprintf('Avg curtail (MW):    %.2f\n', mean(WindAvail_MW(ok) - WindUsed_MW(ok),'omitnan'));

%% ---------------- SAVE RESULTS ----------------
Results = table((1:8760).', WindAvail_MW, WindUsed_MW, (WindAvail_MW - WindUsed_MW), ENS_MWh, OPFsuccess, ...
    'VariableNames', {'Hour','WindAvail_MW','WindUsed_MW','WindCurtail_MW','ENS_MWh','OPFsuccess'});

writetable(Results, 'results_1yr_dispatchableLoads_1wind.xlsx');
save('results_1yr_dispatchableLoads_1wind.mat', 'Results', 'EENS_year', 'wind_bus', 'VOLL', 'Pwind_rated');