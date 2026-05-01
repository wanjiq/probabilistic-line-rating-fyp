%% add_wind_rts24_full_FIXED.m
% Purpose:
%   Add wind generation to IEEE RTS 24-bus in MATPOWER (case24_ieee_rts)
%   following MATPOWER case-data approach:
%     1) append a row to mpc.gen
%     2) append a matching row to mpc.gencost (MATCH COL COUNT!)
%     3) run OPF (single snapshot or time-series)

clc; clear;
define_constants;

%% ---------------- USER SETTINGS ----------------
case_name = 'case24_ieee_rts';

% Wind placement
wind_buses  = [3];        % e.g., [3] or [3 5 7 16 21 23]
wind_cap_MW = [300];      % installed capacity per wind farm (MW)

% Single snapshot availability (0..1)
avail = 0.60;

% Reactive capability (MVAr) – used only in AC OPF realistically
Qmax_MVAr = 0 ;
Qmin_MVAr = 0 ;

% Voltage setpoint at wind buses (AC OPF uses; DC OPF ignores)
VG_set = 1.00;

% Wind cost (very low => dispatched first)
wind_c1 = 0;     % linear coefficient
wind_c0 = 0;     % constant term

% OPF type
use_dc = true;   % DC OPF fast; AC OPF slower

% Optional time-series profile (availability per hour). Leave [] for single snapshot.
wind_avail_profile = [];  % e.g., linspace(0.1,0.9,24);

%% ---------------- OPTIONS ----------------
mpopt = mpoption('verbose', 1, 'out.all', 1);
mpopt = mpoption(mpopt, 'opf.dc', double(use_dc));

%% ---------------- LOAD CASE ----------------
mpc0 = loadcase(case_name);
mpc  = mpc0;

% Checks
assert(numel(wind_buses) == numel(wind_cap_MW), 'wind_buses and wind_cap_MW must match length');
assert(numel(wind_buses) == numel(Qmax_MVAr),   'Qmax_MVAr length must match wind_buses');
assert(numel(wind_buses) == numel(Qmin_MVAr),   'Qmin_MVAr length must match wind_buses');

%% ---------------- ADD WIND FARMS ----------------
% Helpful info
fprintf('Existing gencost columns = %d\n', size(mpc.gencost,2));

for k = 1:numel(wind_buses)
    bus_k  = wind_buses(k);
    Pcap   = wind_cap_MW(k);

    % Available wind this snapshot (time-series loop will overwrite PMAX)
    Pmax_avail = avail * Pcap;

    % ----- append gen row -----
    new_gen = mpc.gen(1,:);           % copy template (keeps correct #cols)
    new_gen(GEN_BUS)    = bus_k;
    new_gen(PG)         = 0;
    new_gen(QG)         = 0;
    new_gen(QMAX)       = Qmax_MVAr(k);
    new_gen(QMIN)       = Qmin_MVAr(k);
    new_gen(VG)         = VG_set;
    new_gen(MBASE)      = mpc.baseMVA;
    new_gen(GEN_STATUS) = 1;
    new_gen(PMAX)       = Pmax_avail;
    new_gen(PMIN)       = 0;

    mpc.gen = [mpc.gen; new_gen];

    % ----- append matching gencost row -----
    % MUST have same number of columns as existing mpc.gencost
    ngc = size(mpc.gencost, 2);

    if ngc == 7
        % quadratic polynomial: [2 startup shutdown 3 c2 c1 c0]
        new_cost = [2 0 0 3 0 wind_c1 wind_c0];
    elseif ngc == 6
        % linear polynomial: [2 startup shutdown 2 c1 c0]
        new_cost = [2 0 0 2 wind_c1 wind_c0];
    else
        % generic fallback: build zeros and set safe fields
        new_cost = zeros(1, ngc);
        % default to polynomial model
        new_cost(1) = 2;     % MODEL = polynomial
        new_cost(2) = 0;     % startup
        new_cost(3) = 0;     % shutdown

        % choose NCOST and place coefficients at the end
        if ngc >= 7
            new_cost(4) = 3;                 % quadratic container
            new_cost(end-2:end) = [0 wind_c1 wind_c0];
        elseif ngc >= 6
            new_cost(4) = 2;                 % linear
            new_cost(end-1:end) = [wind_c1 wind_c0];
        else
            error('Unexpected gencost width = %d. Cannot append safely.', ngc);
        end
    end

    mpc.gencost = [mpc.gencost; new_cost];
end

% Sanity check: gencost rows == gen rows (required for OPF)
if size(mpc.gencost,1) ~= size(mpc.gen,1)
    error('gencost row count (%d) does not match gen row count (%d).', size(mpc.gencost,1), size(mpc.gen,1));
end

%% ---------------- RUN SINGLE SNAPSHOT OR TIME-SERIES ----------------
nW = numel(wind_buses);
wind_gen_rows = (size(mpc.gen,1)-nW+1):size(mpc.gen,1);

if isempty(wind_avail_profile)
    % ----- Single snapshot -----
    results = runopf(mpc, mpopt);

    fprintf('\n=== WIND DISPATCH (single snapshot) ===\n');
    for i = 1:nW
        gi = wind_gen_rows(i);
        fprintf('Wind @ bus %d: PG = %.2f MW (PMAX=%.2f)\n', ...
            results.gen(gi, GEN_BUS), results.gen(gi, PG), results.gen(gi, PMAX));
    end
    fprintf('Objective f = %.4f | success=%d\n', results.f, results.success);

else
    % ----- Time-series -----
    T = numel(wind_avail_profile);

    PG_wind = zeros(T, nW);
    success = false(T,1);
    fval    = nan(T,1);

    for t = 1:T
        % Update wind availability (per farm)
        for i = 1:nW
            gi = wind_gen_rows(i);
            mpc.gen(gi, PMAX) = wind_avail_profile(t) * wind_cap_MW(i);
        end

        r = runopf(mpc, mpopt);

        success(t) = (r.success == 1);
        fval(t)    = r.f;

        for i = 1:nW
            gi = wind_gen_rows(i);
            PG_wind(t,i) = r.gen(gi, PG);
        end

        fprintf('t=%d/%d | avail=%.3f | success=%d\n', t, T, wind_avail_profile(t), success(t));
    end

    fprintf('\n=== TIME-SERIES SUMMARY ===\n');
    fprintf('Success rate: %.1f%%\n', 100*mean(success));
    if any(success)
        fprintf('Mean objective f (success only): %.4f\n', mean(fval(success)));
    end

    figure;
    plot(1:T, sum(PG_wind,2), 'LineWidth', 1.5);
    grid on; xlabel('Hour'); ylabel('Total Wind PG (MW)');
    title('Wind dispatch over time');
end