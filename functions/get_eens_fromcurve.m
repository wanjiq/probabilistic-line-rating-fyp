%% eens_table_lambda_curve_based_slr_acopf.m
% Curve-based SLR from exceedance curve -> I* -> MVA conversion
% Branch RATE_A built per branch using bus BASE_KV:
%   - Lines: Vbranch = Vf (since Vf=Vt)
%   - Transformers: Vbranch = (Vf + Vt)/2  (e.g., 138↔230 -> 184 kV)
% Then scaled by rating_factor sweep and used in AC OPF with dispatchable loads.
%
% IMPORTANT: I* is obtained using the SAME method that yields ~868 A:
%   - exceedance in dataset is FRACTION (not percent)
%   - user enters exceedance in percent (e.g., 0.1 meaning 0.1%)
%   - target = exceed_pct_user/100
%   - linear interpolation, no cummax, no pchip

clc; clear;
define_constants;

%% ---------- USER SETTINGS ----------
case_name       = 'case24_ieee_rts';

% Exceedance curve dataset
plr_matfile     = "PLR_dataset.mat";  % has Tmax_list, I_ref, Pexc_mat
Tmax_ref        = 75;                 % which Tmax curve to use
exceed_pct_user = 0.1;                % user-facing percent (0.1 means 0.1%)

% Rating multipliers
rating_factor = [1.10 1.05 1.00 0.95 0.90 0.85 0.80 0.75 0.70];
rating_labels = {'ENS_110','ENS_105','ENS_100','ENS_95','ENS_90','ENS_85','ENS_80','ENS_75','ENS_70'};

% Load scaling
lam = 1.0 : 0.05 : 1.6;

%% 1) Load original RTS-24 case
mpc0 = loadcase(case_name);

Pbase_MW   = sum(mpc0.bus(:, PD));
Qbase_MVAr = sum(mpc0.bus(:, QD));
fprintf('Original case base load: Pbase = %.2f MW, Qbase = %.2f MVAr\n', Pbase_MW, Qbase_MVAr);

%% 2) Convert fixed loads to dispatchable loads (EENS enabled)
VOLL = 10000; % $/MWh
mpc_base = load2disp(mpc0, [], [], VOLL);

%% 3) OPF options (AC OPF)
mpopt = mpoption('verbose', 0, 'out.all', 0);

%% 4) Branch voltage levels from bus BASE_KV (lines + transformers)
fbus = mpc0.branch(:, F_BUS);
tbus = mpc0.branch(:, T_BUS);

% robust bus-number -> row mapping (works even if BUS_I not 1..nbus)
[~, row_f] = ismember(fbus, mpc0.bus(:, BUS_I));
[~, row_t] = ismember(tbus, mpc0.bus(:, BUS_I));
if any(row_f==0) || any(row_t==0)
    error("Bus mapping failed: some branch buses not found in mpc.bus(:,BUS_I).");
end

Vf_kV = mpc0.bus(row_f, BASE_KV);
Vt_kV = mpc0.bus(row_t, BASE_KV);

is_xfmr = abs(Vf_kV - Vt_kV) > 1e-3;
is_line = ~is_xfmr;

% Voltage choice:
Vbranch_kV = Vf_kV;
Vbranch_kV(is_xfmr) = 0.5*(Vf_kV(is_xfmr) + Vt_kV(is_xfmr));  % 184 kV for 138↔230

fprintf("Detected %d lines and %d transformers.\n", sum(is_line), sum(is_xfmr));
fprintf("Using Vbranch = Vf for lines; Vbranch = (Vf+Vt)/2 for transformers.\n");

%% 5) Read I* from exceedance curve (SLR-equivalent anchor)
S = load(plr_matfile, "Tmax_list", "I_ref", "Pexc_mat");
Tmax_list = S.Tmax_list(:);
I_ref     = S.I_ref(:);
Pexc_mat  = S.Pexc_mat;

idxT = find(Tmax_list == Tmax_ref, 1);
if isempty(idxT)
    error("Tmax=%g not found in %s. Available Tmax: %s", ...
        Tmax_ref, plr_matfile, strjoin(string(Tmax_list), ", "));
end

Pexc_I = Pexc_mat(:, idxT);     % FRACTION exceedance vs current

% Convert user percent to FRACTION to match dataset
target = exceed_pct_user / 100;

% EXACT lookup method: linear interpolation on (Pexc -> I), no cummax, no pchip
I_star_A = rating_from_exceedance_linear(I_ref, Pexc_I, target);

if isnan(I_star_A)
    error("I* returned NaN. target=%.6g (fraction) may be outside curve range.", target);
end

fprintf("Curve-based SLR anchor: Tmax=%g°C, exceed=%.4g%% (%.6g frac) -> I* = %.2f A\n", ...
    Tmax_ref, exceed_pct_user, target, I_star_A);

%% 6) Convert I* to RATE_A (MVA) per branch (ALL branches)
RATEA_curve_MVA = sqrt(3) .* Vbranch_kV .* I_star_A ./ 1000;

%% 6b) Report
fprintf("\n--- Curve-based rating (I*) converted to MVA ---\n");
fprintf("I* = %.2f A, RATE_A = sqrt(3)*Vbranch(kV)*I/1000 (MVA)\n", I_star_A);

[uKV,~,g] = unique(round(Vbranch_kV, 3));
nBr_kV  = accumarray(g, 1);
minMVA  = accumarray(g, RATEA_curve_MVA, [], @min);
meanMVA = accumarray(g, RATEA_curve_MVA, [], @mean);
maxMVA  = accumarray(g, RATEA_curve_MVA, [], @max);

SummaryKV = table(uKV, nBr_kV, minMVA, meanMVA, maxMVA, ...
    'VariableNames', {'kV_branch','nBranches','RATEA_Min_MVA','RATEA_Mean_MVA','RATEA_Max_MVA'});

disp("Summary (ALL branches) of curve-based RATE_A (100% multiplier):");
disp(SummaryKV);

%% Prepare result matrices
ENS_matrix = nan(numel(lam), numel(rating_factor));
success_matrix = false(numel(lam), numel(rating_factor));

%% 7) Main loops: rating scenario x load level
for r = 1:numel(rating_factor)

    mpc_rating = mpc_base;

    % Apply to ALL branches (lines + transformers) consistently
    mpc_rating.branch(:, RATE_A) = rating_factor(r) * RATEA_curve_MVA;

    for k = 1:numel(lam)

        mpc = mpc_rating;

        % Scale ALL loads (fixed + dispatchable, both P and Q) by lambda
        opt = struct('scale','FACTOR','pq','PQ','which','BOTH');
        mpc = scale_load(lam(k), mpc, [], opt);

        % Run AC OPF
        res = runopf(mpc, mpopt);
        success_matrix(k,r) = (res.success == 1);

        if ~success_matrix(k,r)
            ENS_matrix(k,r) = NaN;
            continue;
        end

        % Load shed (MW) from dispatchable loads
        shed_MW = sum(loadshed(res.gen));

        % ENS for 1 hour snapshot: MWh = MW * 1 hour -> equals MW
        ENS_matrix(k,r) = shed_MW;
    end
end

%% 8) Build ENS table
TotalLoad_MW = lam(:) * Pbase_MW;

ENS_Table = array2table([lam(:), TotalLoad_MW, ENS_matrix], ...
    'VariableNames', [{'Load_pu_lambda','TotalLoad_MW'}, rating_labels]);

disp('=== ENS Comparison Table (AC OPF, curve-based RATE_A, 1-hour snapshot) ===');
disp(ENS_Table);

%% 9) Export to Excel
outFile = 'ENS_CurveBasedSLR_ACOPF.xlsx';
writetable(ENS_Table, outFile, 'Sheet', 'ENS_Results');

% Export ratings used (100% multiplier)
nBr = size(mpc0.branch, 1);
BranchID  = (1:nBr)';
FromBus   = mpc0.branch(:, F_BUS);
ToBus     = mpc0.branch(:, T_BUS);

BranchRatings_Table = table(BranchID, FromBus, ToBus, Vf_kV, Vt_kV, Vbranch_kV, is_xfmr, RATEA_curve_MVA, ...
    'VariableNames', {'BranchID','FromBus','ToBus','Vf_kV','Vt_kV','Vbranch_kV','IsXfmr','RATEA_MVA_100pct'});

writetable(BranchRatings_Table, outFile, 'Sheet', 'CurveBased_Ratings');
fprintf('\nSaved Excel file: %s\n', outFile);

%% 10) Plot ENS vs lambda
figure; hold on; grid on;
for r = 1:numel(rating_factor)
    plot(lam, ENS_matrix(:,r), '-o', ...
        'DisplayName', sprintf('Rating %.0f%% of curve-SLR', 100*rating_factor(r)));
end
xlabel('Load (p.u.) = \lambda');
ylabel('ENS (MWh in 1 hour)');  % equals MW for 1h
title(sprintf('ENS vs Load (Curve-based SLR: Tmax=%g°C, exceed=%.4g%%)', Tmax_ref, exceed_pct_user));
legend('Location','northwest');

%% -------- Local helper function (matches your 868 A style) --------
function I_star = rating_from_exceedance_linear(I_ref, Pexc_I, target_frac)
% I_ref: current grid (A)
% Pexc_I: exceedance values for chosen Tmax (FRACTION)
% target_frac: exceedance target (FRACTION), e.g. 0.001 for 0.1%

    I = I_ref(:);
    P = Pexc_I(:);

    ok = isfinite(I) & isfinite(P);
    I = I(ok); P = P(ok);

    if numel(I) < 2
        I_star = NaN; return;
    end

    % Sort by P (x-axis for interp1 must be increasing)
    [Psorted, order] = sort(P);
    Isorted = I(order);

    % Remove duplicate P values
    [Psorted, ia] = unique(Psorted, 'stable');
    Isorted = Isorted(ia);

    if target_frac < min(Psorted) || target_frac > max(Psorted)
        I_star = NaN; return;
    end

    % Linear interpolation (transparent)
    I_star = interp1(Psorted, Isorted, target_frac, 'linear');
end