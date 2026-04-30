%% --- run_Scenario4_Bulk_Extreme_BNM.m ---
clear; clc;
t_start_sim = tic; 
warning('off', 'all');

% =====================================================
% 1. USER CONTROL PANEL
% =====================================================
MAX_ITERATIONS = 200;      
lambda         = 1.20;    
VOLL           = 1000;    
LINE_PENALTY   = 5000;    
scenario_name     = 'Scenario4_Bulk_Extreme_BNM';                  
current_wind_caps = [100, 100, 900]; % Extreme Wind (900MW at Bus 21)
chosen_tmax    = 75;               
EXCEEDANCE_SLR = 0.01;             

% =====================================================
% 1.5 DISPLAY SIMULATION CONFIGURATION
% =====================================================
fprintf('\n======================================================\n');
fprintf(' ⚙️ SIMULATION CONFIGURATION INITIALIZING...\n');
fprintf('------------------------------------------------------\n');
fprintf(' Scenario Name:    %s\n', scenario_name);
fprintf(' Target Tmax:      %d °C\n', chosen_tmax);
fprintf(' Baseline Risk:    %.2f%% (SLR Exceedance)\n', EXCEEDANCE_SLR);
fprintf(' Wind Injection:   Bus 7 (%d MW) | Bus 13 (%d MW) | Bus 21 (%d MW)\n', current_wind_caps(1), current_wind_caps(2), current_wind_caps(3));
fprintf('======================================================\n\n');

% =====================================================
% 2. INITIALIZATION
% =====================================================
define_constants; 
fprintf('Loading IEEE RTS-96 Grid Data...\n');
load('Grid_Study_Data.mat');         
load('All_Seasons_PLR_Dataset.mat'); 
load('Custom_Wind_Profile.mat'); 

% This will now create a brand new folder!
folder_name = sprintf('Results_Combined_%s', scenario_name); 
if ~exist(folder_name, 'dir'), mkdir(folder_name); end
checkpoint_file = fullfile(folder_name, 'Checkpoint_FULL.mat');
excel_file      = fullfile(folder_name, sprintf('Final_Results_%s.xlsx', scenario_name));

mpc_base = loadcase('case24_ieee_rts');
num_real_gens = size(mpc_base.gen, 1);
num_buses = size(mpc_base.bus, 1);
num_branches = size(mpc_base.branch, 1);
num_wind = length(current_wind_caps);

mpopt = mpoption('model', 'DC', 'verbose', 0, 'out.all', 0, 'opf.dc.solver', 'MIPS');
mpopt = mpoption(mpopt, 'opf.softlims.default', 1); 

rts_for_map = containers.Map([12, 20, 50, 76, 100, 155, 197, 350, 400], [0.02, 0.10, 0.01, 0.02, 0.04, 0.04, 0.05, 0.08, 0.12]);
gen_FOR_array = zeros(num_real_gens, 1);
for g = 1:num_real_gens
    size_mw = round(mpc_base.gen(g, PMAX)); 
    if isKey(rts_for_map, size_mw), gen_FOR_array(g) = rts_for_map(size_mw); else, gen_FOR_array(g) = 0.05; end
end

[~, f_idx] = ismember(mpc_base.branch(:, F_BUS), mpc_base.bus(:, BUS_I));
[~, t_idx] = ismember(mpc_base.branch(:, T_BUS), mpc_base.bus(:, BUS_I));
is_line = (mpc_base.bus(f_idx, BASE_KV) == mpc_base.bus(t_idx, BASE_KV));
line_kV = mpc_base.bus(f_idx(is_line), BASE_KV);

wind_buses = [7, 13, 21];
wind_gen_idx = zeros(1, num_wind);
for w = 1:num_wind
    new_gen = zeros(1, size(mpc_base.gen, 2));
    new_gen(GEN_BUS) = wind_buses(w); new_gen(GEN_STATUS) = 1; 
    mpc_base.gen = [mpc_base.gen; new_gen];
    mpc_base.gencost = [mpc_base.gencost; [2 0 0 3 0 0 0]];
    wind_gen_idx(w) = size(mpc_base.gen, 1);
end

tmax_idx = find(Tmax_list == chosen_tmax, 1);
I_slr = rating_from_exceedance(compiled_results.Summer.I_list, compiled_results.Summer.Pexc_mat(:, tmax_idx), EXCEEDANCE_SLR);
SLR_MVA = (sqrt(3) .* line_kV .* I_slr) ./ 1000;
seasons = fieldnames(compiled_results);
plr_limits = struct();
for s = 1:length(seasons)
    s_name = seasons{s}; s_lower = lower(s_name); 
    plr_limits.(s_lower).p5  = (sqrt(3) .* line_kV .* rating_from_exceedance(compiled_results.(s_name).I_list, compiled_results.(s_name).Pexc_mat(:, tmax_idx), 5.0)) ./ 1000;
    plr_limits.(s_lower).p10 = (sqrt(3) .* line_kV .* rating_from_exceedance(compiled_results.(s_name).I_list, compiled_results.(s_name).Pexc_mat(:, tmax_idx), 10.0)) ./ 1000;
    plr_limits.(s_lower).p15 = (sqrt(3) .* line_kV .* rating_from_exceedance(compiled_results.(s_name).I_list, compiled_results.(s_name).Pexc_mat(:, tmax_idx), 15.0)) ./ 1000;
end

fprintf('\n======================================================\n');
fprintf(' RATINGS SUMMARY (Dynamic Limits Calculated)\n');
fprintf('------------------------------------------------------\n');
fprintf(' SLR Limit:   %.2f MVA\n', mean(SLR_MVA));
for s = 1:length(seasons)
    s_n = seasons{s}; s_l = lower(s_n);
    fprintf(' PLR %-6s : P5=%.2f MVA | P10=%.2f MVA | P15=%.2f MVA\n', s_n, mean(plr_limits.(s_l).p5), mean(plr_limits.(s_l).p10), mean(plr_limits.(s_l).p15));
end
fprintf('======================================================\n');

% =====================================================
% 3. SIMULATION LOOP WITH FULL TRACKING
% =====================================================
if isfile(checkpoint_file)
    fprintf('\n>>> Checkpoint found! Loading... <<<\n'); load(checkpoint_file); start_iter = iter + 1;
else
    start_iter = 1;
    % System Metrics
    t_ens_sh_slr = zeros(MAX_ITERATIONS, 1); t_ens_ov_slr = zeros(MAX_ITERATIONS, 1); t_ens_tot_slr = zeros(MAX_ITERATIONS, 1); t_curt_slr = zeros(MAX_ITERATIONS, 1);
    t_ens_sh_p5  = zeros(MAX_ITERATIONS, 1); t_ens_ov_p5  = zeros(MAX_ITERATIONS, 1); t_ens_tot_p5  = zeros(MAX_ITERATIONS, 1); t_curt_p5  = zeros(MAX_ITERATIONS, 1);
    t_ens_sh_p10 = zeros(MAX_ITERATIONS, 1); t_ens_ov_p10 = zeros(MAX_ITERATIONS, 1); t_ens_tot_p10 = zeros(MAX_ITERATIONS, 1); t_curt_p10 = zeros(MAX_ITERATIONS, 1);
    t_ens_sh_p15 = zeros(MAX_ITERATIONS, 1); t_ens_ov_p15 = zeros(MAX_ITERATIONS, 1); t_ens_tot_p15 = zeros(MAX_ITERATIONS, 1); t_curt_p15 = zeros(MAX_ITERATIONS, 1);
    
    % FULL Granular Metrics for ALL ratings
    b_ens_slr = zeros(MAX_ITERATIONS, num_buses); b_ens_p5 = zeros(MAX_ITERATIONS, num_buses); b_ens_p10 = zeros(MAX_ITERATIONS, num_buses); b_ens_p15 = zeros(MAX_ITERATIONS, num_buses);
    l_ov_slr = zeros(MAX_ITERATIONS, num_branches); l_ov_p5 = zeros(MAX_ITERATIONS, num_branches); l_ov_p10 = zeros(MAX_ITERATIONS, num_branches); l_ov_p15 = zeros(MAX_ITERATIONS, num_branches);
    w_curt_slr = zeros(MAX_ITERATIONS, num_wind); w_curt_p5 = zeros(MAX_ITERATIONS, num_wind); w_curt_p10 = zeros(MAX_ITERATIONS, num_wind); w_curt_p15 = zeros(MAX_ITERATIONS, num_wind);
end

for iter = start_iter:MAX_ITERATIONS
    rng(iter, 'twister'); random_year = randi([1, 10]); wind_start_hr = (random_year - 1) * 8760; 
    
    y_sh_slr = 0; y_ov_slr = 0; y_cu_slr = 0; y_sh_p5 = 0; y_ov_p5 = 0; y_cu_p5 = 0; y_sh_p10 = 0; y_ov_p10 = 0; y_cu_p10 = 0; y_sh_p15 = 0; y_ov_p15 = 0; y_cu_p15 = 0; 
    y_b_slr = zeros(1, num_buses); y_b_p5 = zeros(1, num_buses); y_b_p10 = zeros(1, num_buses); y_b_p15 = zeros(1, num_buses);
    y_l_slr = zeros(1, num_branches); y_l_p5 = zeros(1, num_branches); y_l_p10 = zeros(1, num_branches); y_l_p15 = zeros(1, num_branches);
    y_w_slr = zeros(1, num_wind); y_w_p5 = zeros(1, num_wind); y_w_p10 = zeros(1, num_wind); y_w_p15 = zeros(1, num_wind);
    
    reverseStr = ''; 
    for t = 1:8760
        season = lower(string(Ttbl.Season(t)));
        scaled_load = (load_10yr_MW(t) / 2850) * mpc_base.bus(:, PD) * lambda; total_requested = sum(scaled_load);
        mpc_t = mpc_base; mpc_t.bus(:, PD) = scaled_load;
        cf = P_Farm_300MW_10yr(wind_start_hr + t) / 300; total_avail_wind = 0;
        
        for w = 1:num_wind
            assigned = current_wind_caps(w) * cf; mpc_t.gen(wind_gen_idx(w), PMAX) = assigned; total_avail_wind = total_avail_wind + assigned;
        end
        
        mpc_t.gen(1:num_real_gens, GEN_STATUS) = (rand(num_real_gens, 1) >= gen_FOR_array);
        mpc_disp = load2disp(mpc_t, '', [], VOLL); disp_idx = (num_real_gens + num_wind + 1) : size(mpc_disp.gen, 1);
        ratings_list = {SLR_MVA, plr_limits.(season).p5, plr_limits.(season).p10, plr_limits.(season).p15};
        
        for r_idx = 1:4
            mpc_r = mpc_disp; mpc_r.branch(is_line, RATE_A) = ratings_list{r_idx};
            mpc_r.softlims.RATE_A.hl_mod = 'remove'; mpc_r.softlims.RATE_A.cost = LINE_PENALTY;
            res_r = rundcopf(mpc_r, mpopt);
            
            % System Totals
            h_sh = max(0, total_requested - sum(-res_r.gen(disp_idx, PG))); h_cu = max(0, total_avail_wind - sum(res_r.gen(wind_gen_idx, PG)));
            act_f = abs(res_r.branch(:, PF)); lims = res_r.branch(:, RATE_A); v_idx = find(lims > 0);
            
            % Granular Arrays
            h_lo_arr = zeros(num_branches, 1); h_lo_arr(v_idx) = max(0, act_f(v_idx) - lims(v_idx)); h_ov_sys = sum(h_lo_arr);
            
            h_b_shed = zeros(1, num_buses);
            for k = 1:length(disp_idx)
                b_id = res_r.gen(disp_idx(k), GEN_BUS); h_b_shed(b_id) = h_b_shed(b_id) + max(0, scaled_load(b_id) - (-res_r.gen(disp_idx(k), PG)));
            end
            
            h_w_curt = zeros(1, num_wind);
            for w = 1:num_wind
                g_idx = wind_gen_idx(w); h_w_curt(w) = max(0, mpc_t.gen(g_idx, PMAX) - res_r.gen(g_idx, PG));
            end
            
            % Full tracking assignments
            if r_idx == 1
                y_sh_slr = y_sh_slr + h_sh; y_ov_slr = y_ov_slr + h_ov_sys; y_cu_slr = y_cu_slr + h_cu; 
                y_b_slr = y_b_slr + h_b_shed; y_l_slr = y_l_slr + h_lo_arr'; y_w_slr = y_w_slr + h_w_curt;
            elseif r_idx == 2
                y_sh_p5 = y_sh_p5 + h_sh; y_ov_p5 = y_ov_p5 + h_ov_sys; y_cu_p5 = y_cu_p5 + h_cu;
                y_b_p5 = y_b_p5 + h_b_shed; y_l_p5 = y_l_p5 + h_lo_arr'; y_w_p5 = y_w_p5 + h_w_curt;
            elseif r_idx == 3
                y_sh_p10 = y_sh_p10 + h_sh; y_ov_p10 = y_ov_p10 + h_ov_sys; y_cu_p10 = y_cu_p10 + h_cu;
                y_b_p10 = y_b_p10 + h_b_shed; y_l_p10 = y_l_p10 + h_lo_arr'; y_w_p10 = y_w_p10 + h_w_curt;
            elseif r_idx == 4
                y_sh_p15 = y_sh_p15 + h_sh; y_ov_p15 = y_ov_p15 + h_ov_sys; y_cu_p15 = y_cu_p15 + h_cu; 
                y_b_p15 = y_b_p15 + h_b_shed; y_l_p15 = y_l_p15 + h_lo_arr'; y_w_p15 = y_w_p15 + h_w_curt;
            end
        end
        if mod(t, 24) == 0 || t == 8760
            day = ceil(t/24); 
            msg = sprintf('Iter %2d | Day %3d | EENS [S:%5.0f P5:%5.0f P10:%5.0f P15:%5.0f] | Curt [S:%5.0f P5:%5.0f P10:%5.0f P15:%5.0f]', ...
                iter, day, ...
                y_sh_slr+y_ov_slr, y_sh_p5+y_ov_p5, y_sh_p10+y_ov_p10, y_sh_p15+y_ov_p15, ...
                y_cu_slr, y_cu_p5, y_cu_p10, y_cu_p15);
            fprintf([reverseStr, msg]); 
            reverseStr = repmat(sprintf('\b'), 1, length(msg)); 
            drawnow; 
        end
    end
    fprintf('\n'); 
    
    % Save all data
    t_ens_sh_slr(iter) = y_sh_slr; t_ens_ov_slr(iter) = y_ov_slr; t_ens_tot_slr(iter) = y_sh_slr + y_ov_slr; t_curt_slr(iter) = y_cu_slr;
    t_ens_sh_p5(iter)  = y_sh_p5;  t_ens_ov_p5(iter)  = y_ov_p5;  t_ens_tot_p5(iter)  = y_sh_p5 + y_ov_p5;   t_curt_p5(iter)  = y_cu_p5;
    t_ens_sh_p10(iter) = y_sh_p10; t_ens_ov_p10(iter) = y_ov_p10; t_ens_tot_p10(iter) = y_sh_p10 + y_ov_p10; t_curt_p10(iter) = y_cu_p10;
    t_ens_sh_p15(iter) = y_sh_p15; t_ens_ov_p15(iter) = y_ov_p15; t_ens_tot_p15(iter) = y_sh_p15 + y_ov_p15; t_curt_p15(iter) = y_cu_p15;
    
    b_ens_slr(iter, :) = y_b_slr; b_ens_p5(iter, :) = y_b_p5; b_ens_p10(iter, :) = y_b_p10; b_ens_p15(iter, :) = y_b_p15; 
    l_ov_slr(iter, :) = y_l_slr; l_ov_p5(iter, :) = y_l_p5; l_ov_p10(iter, :) = y_l_p10; l_ov_p15(iter, :) = y_l_p15;
    w_curt_slr(iter, :) = y_w_slr; w_curt_p5(iter, :) = y_w_p5; w_curt_p10(iter, :) = y_w_p10; w_curt_p15(iter, :) = y_w_p15;
    
    save(checkpoint_file, 't_ens_sh_slr','t_ens_ov_slr','t_ens_tot_slr','t_curt_slr', 't_ens_sh_p5','t_ens_ov_p5','t_ens_tot_p5','t_curt_p5', ...
         't_ens_sh_p10','t_ens_ov_p10','t_ens_tot_p10','t_curt_p10', 't_ens_sh_p15','t_ens_ov_p15','t_ens_tot_p15','t_curt_p15', ...
         'b_ens_slr','b_ens_p5','b_ens_p10','b_ens_p15', 'l_ov_slr','l_ov_p5','l_ov_p10','l_ov_p15', ...
         'w_curt_slr','w_curt_p5','w_curt_p10','w_curt_p15', 'iter');
end

% Final Excel Export
Iteration = (1:MAX_ITERATIONS)';
T_Sys = table(Iteration, t_ens_sh_slr, t_ens_ov_slr, t_ens_tot_slr, t_curt_slr, t_ens_sh_p5, t_ens_ov_p5, t_ens_tot_p5, t_curt_p5, t_ens_sh_p10, t_ens_ov_p10, t_ens_tot_p10, t_curt_p10, t_ens_sh_p15, t_ens_ov_p15, t_ens_tot_p15, t_curt_p15, ...
    'VariableNames', {'Iter','SLR_Sh','SLR_Ov','SLR_Tot','SLR_Cu','P5_Sh','P5_Ov','P5_Tot','P5_Cu','P10_Sh','P10_Ov','P10_Tot','P10_Cu','P15_Sh','P15_Ov','P15_Tot','P15_Cu'});
writetable(T_Sys, excel_file, 'Sheet', 'System_Totals');

BusNames = cell(1, num_buses); for b = 1:num_buses, BusNames{b} = sprintf('Bus_%d', b); end
writetable([table(Iteration), array2table(b_ens_slr, 'VariableNames', BusNames)], excel_file, 'Sheet', 'Bus_Shed_SLR');
writetable([table(Iteration), array2table(b_ens_p5, 'VariableNames', BusNames)], excel_file, 'Sheet', 'Bus_Shed_P5');
writetable([table(Iteration), array2table(b_ens_p10, 'VariableNames', BusNames)], excel_file, 'Sheet', 'Bus_Shed_P10');
writetable([table(Iteration), array2table(b_ens_p15, 'VariableNames', BusNames)], excel_file, 'Sheet', 'Bus_Shed_P15');

LineNames = cell(1, num_branches); for L = 1:num_branches, LineNames{L} = sprintf('Line_%d_to_%d', mpc_base.branch(L, F_BUS), mpc_base.branch(L, T_BUS)); end
LineNames = matlab.lang.makeUniqueStrings(LineNames);
writetable([table(Iteration), array2table(l_ov_slr, 'VariableNames', LineNames)], excel_file, 'Sheet', 'Line_Over_SLR');
writetable([table(Iteration), array2table(l_ov_p5, 'VariableNames', LineNames)], excel_file, 'Sheet', 'Line_Over_P5');
writetable([table(Iteration), array2table(l_ov_p10, 'VariableNames', LineNames)], excel_file, 'Sheet', 'Line_Over_P10');
writetable([table(Iteration), array2table(l_ov_p15, 'VariableNames', LineNames)], excel_file, 'Sheet', 'Line_Over_P15');

WindNames = cell(1, num_wind); for w = 1:num_wind, WindNames{w} = sprintf('Wind_Bus_%d', wind_buses(w)); end
WindNames = matlab.lang.makeUniqueStrings(WindNames);
writetable([table(Iteration), array2table(w_curt_slr, 'VariableNames', WindNames)], excel_file, 'Sheet', 'Farm_Curt_SLR');
writetable([table(Iteration), array2table(w_curt_p5, 'VariableNames', WindNames)], excel_file, 'Sheet', 'Farm_Curt_P5');
writetable([table(Iteration), array2table(w_curt_p10, 'VariableNames', WindNames)], excel_file, 'Sheet', 'Farm_Curt_P10');
writetable([table(Iteration), array2table(w_curt_p15, 'VariableNames', WindNames)], excel_file, 'Sheet', 'Farm_Curt_P15');

elapsed_time = toc(t_start_sim);
fprintf('\n======================================================\n');
fprintf(' 🎉 SCENARIO 4 (BNM) COMPLETE WITH FULL TRACKING. Total Time: %.2f seconds\n', elapsed_time);
fprintf('======================================================\n');