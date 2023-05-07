%{
Created: 30 April 2023
Ji-Eun Byun

Apply "test6_ex1_v4.m" to R2D data
%}

clear
rng(1)
R2D=load('R2D_data/R2Ddata.mat');

nPop = 1e4;
pop_inds = randsample( length(R2D.myMeanRepCost), nPop, false );

income_pop = R2D.myWeeklyIncome(pop_inds)';
repair_pop = R2D.myMeanRepCost(pop_inds)';
repair_pop_std = R2D.myStdRepCost(pop_inds)';
repair_pop_max = income_pop * 26;

income_min = min( R2D.myWeeklyIncome );
dem_min = 0.9 * income_min; % Min. demand given a minimum income
dem_inc_income = 0.5; % Increase in demand per increase in income
dem_max = 10*dem_min; % Maximum demand
dem_orig_fun = @(incomes) arrayfun( @(income1) min([dem_max, dem_min + dem_inc_income*(income1-income_min)]), incomes, 'UniformOutput', true );

dem_pop_orig = dem_orig_fun(income_pop);
% saving_pop = ( income_pop - dem_pop_orig ) * 26;

% Price cap
pcap = 0.1;

% Supply-price curve 
nWeek_disrup  = 15;
nWeek_disrup_cov = 1;
nWeek_disrup_bnd = [4 30];

delP = 0.1; % Increase in production cost (ratio)
delP_cov = 1;
delP_bnd = [0.05 0.3];
delP_g = 0.5; % Increase  by price-gouging (ratio)
delP_g_cov = 1;
delP_g_bnd = [0.25 2];
delQ_b = 1; % Increase in demand for basic goods (ratio)
delQ_b_cov = 0.5;
delQ_b_bnd = [0.5 1.5];

QP_slope_b = 0.5;
QP_slope_b_cov = 0.2;
QP_slope_b_bnd = [0.25 0.75];

QP_slope_r = QP_slope_b/(0.5*sum(income_pop)); % sum(income_pop) is used to make it insensitive to the size of population
QP_slope_r_cov = QP_slope_b_cov;
QP_slope_r_bnd = QP_slope_b_bnd/0.5;


delQ_b_sup_min = -0.95; % lower bound of supply (>-1)

delQ_r_sup_min = 0.05; % lower bound of supply (>0 as there is no originial consumption assumed)
delQ_r_div = 2; % To make it insensivite to the number of population, delQ is set as Q_r / (income_sum * delQ_div)
delQ_r_normal = 0.1 * sum( repair_pop ); % this amount of demand is expected in normality

% Well-being loss
w0 = 0.75; % the well-being ratio that the fulfilment of minimum demand is met (in [0,1])

% etc.
nMCS = 1e4;

Q_hd_b = 0.3; % increase in demand for basic goods because of hoarding
don = 0.1; % donation ratio of remaining income
fname = 'hd3_dn1';


%% Dynamic analysis + Monte Carlo
dem_lack_abs_hist_noban = cell(nMCS,1); wbl_pop_income_hist_noban =  cell(nMCS,1); repair_pop_nWeek_noban = zeros(nPop, nMCS);
dem_lack_abs_hist_ban =  cell(nMCS,1); wbl_pop_income_hist_ban =  cell(nMCS,1); wbl_pop_supply_hist_ban =  cell(nMCS,1); repair_pop_nWeek_ban = zeros(nPop, nMCS);
delP_hist = zeros(nMCS,1); delP_g_hist = zeros(nMCS,1); delQ_b_hist = zeros(nMCS,1); QP_slope_hist = zeros(nMCS,1); nWeek_disrup_hist = zeros(nMCS,1);
nWeek_avg_noban_hist = zeros(nMCS,1); nWeek_avg_ban_hist = zeros(nMCS,1);

% Monte Carlo
for iMCS = 1:nMCS
    disp( ['Sample ' num2str(iMCS) ' ..'] )

    rng(iMCS)

    repair_pop_m = repair_pop + randn( 1, nPop ) .* repair_pop_std;
    repair_pop_m( repair_pop_m < 0 ) = 0; repair_pop_m( repair_pop_m(:) > repair_pop_max(:) ) = repair_pop_max( repair_pop_m(:) > repair_pop_max(:) );
    
    nWeek_disrup_m = round( max([nWeek_disrup_bnd(1), nWeek_disrup + randn * nWeek_disrup_cov * nWeek_disrup]) );
    nWeek_disrup_m = min( [nWeek_disrup_m, nWeek_disrup_bnd(2)] );
    
    delP_m = max([delP_bnd(1), delP + randn * delP_cov * delP]);
    delP_m = min([delP_m, delP_bnd(2)]);
    delP_g_m = max([delP_g_bnd(1), delP_g + randn * delP_g_cov * delP_g]);
    delP_g_m = min( [delP_g_m, delP_g_bnd(2)] );
    delQ_b_m = max([delQ_b_bnd(1), delQ_b + randn * delQ_b_cov * delQ_b]);
    delQ_b_m = min([delQ_b_m, delQ_b_bnd(2)]);
    QP_slope_b_m = max([QP_slope_b_bnd(1), QP_slope_b + randn * QP_slope_b_cov * QP_slope_b]);
    QP_slope_b_m = min( [QP_slope_b_m, QP_slope_b_bnd(2)] );
    QP_slope_r_m = max([QP_slope_r_bnd(1), QP_slope_r + randn * QP_slope_r_cov * QP_slope_r]);
    QP_slope_r_m = min( [QP_slope_r_m, QP_slope_r_bnd(2)] );
    
    % Dynamic analysis
%     income_pop_rem_noban = income_pop+saving_pop;
    income_pop_rem_noban = income_pop;
    repair_pop_rem_noban = repair_pop_m;
    
%     income_pop_rem_ban = income_pop+saving_pop;
    income_pop_rem_ban = income_pop;
    repair_pop_rem_ban = repair_pop_m;
    
    dem_lack_abs_hist_noban_t = zeros(0,1); wbl_pop_income_hist_noban_t = zeros(0,nPop); repair_pop_nWeek_noban_t = zeros(nPop, 1);
    dem_lack_abs_hist_ban_t = zeros(0,1); wbl_pop_income_hist_ban_t = zeros(0,nPop); wbl_pop_supply_hist_ban_t = zeros(0,nPop); repair_pop_nWeek_ban_t = zeros(nPop, 1);
    nWeek = 0;
    while sum( repair_pop_rem_noban ) || sum( repair_pop_rem_ban )
    
        nWeek = nWeek+1;
    
        delP_t = max([0, delP_m * ( (nWeek_disrup_m - nWeek + 1) / nWeek_disrup_m )]);
        delP_g_t = max([0, delP_g_m * ( (nWeek_disrup_m - nWeek + 1) / nWeek_disrup_m )]);
        delQ_b_t = max([0, delQ_b_m * ( (nWeek_disrup_m - nWeek + 1) / nWeek_disrup_m )]);
        Q_hd_b_t = max([0, Q_hd_b * ( (nWeek_disrup_m - nWeek + 1) / nWeek_disrup_m )]);
    
        if sum( repair_pop_rem_noban ) > 0
            [dem_lack_abs_noban, wbl_pop_income_noban, wbl_pop_supply_noban, repair_pop_rem_noban, income_pop_rem_noban] = gg_v2.sim_no_cap( income_pop_rem_noban + income_pop, repair_pop_rem_noban, dem_pop_orig, delP_t, delP_g_t, delQ_b_t, QP_slope_b_m, w0, dem_min, income_pop, QP_slope_r_m, delQ_r_normal, don );
        
            dem_lack_abs_hist_noban_t = [dem_lack_abs_hist_noban_t; dem_lack_abs_noban];
            wbl_pop_income_hist_noban_t = [wbl_pop_income_hist_noban_t; wbl_pop_income_noban];
            repair_pop_nWeek_noban_t( (repair_pop_m(:)>0) & ~repair_pop_nWeek_noban_t(:) & ~repair_pop_rem_noban(:) ) = nWeek;
        end
    
        if sum( repair_pop_rem_ban ) > 0
            [dem_lack_abs_ban, wbl_pop_income_ban, wbl_pop_supply_ban, repair_pop_rem_ban, income_pop_rem_ban] = gg_v2.sim_yes_cap( income_pop_rem_ban + income_pop, repair_pop_rem_ban, dem_pop_orig, delP_t, delP_g_t, delQ_b_t, QP_slope_b_m, w0, dem_min, income_pop, QP_slope_r_m, delQ_r_normal, don, pcap, Q_hd_b_t, delQ_b_sup_min, delQ_r_sup_min );
           
            dem_lack_abs_hist_ban_t = [dem_lack_abs_hist_ban_t; dem_lack_abs_ban];
            wbl_pop_income_hist_ban_t = [wbl_pop_income_hist_ban_t; wbl_pop_income_ban];
            wbl_pop_supply_hist_ban_t = [wbl_pop_supply_hist_ban_t; wbl_pop_supply_ban];
            repair_pop_nWeek_ban_t( (repair_pop_m(:)>0) & ~repair_pop_nWeek_ban_t(:) & ~repair_pop_rem_ban(:) ) = nWeek;
        end
    
    end

    dem_lack_abs_hist_noban{iMCS} = dem_lack_abs_hist_noban_t;
    wbl_pop_income_hist_noban{iMCS} = wbl_pop_income_hist_noban_t;
    repair_pop_nWeek_noban(:,iMCS) = repair_pop_nWeek_noban_t;

    dem_lack_abs_hist_ban{iMCS} = dem_lack_abs_hist_ban_t;
    wbl_pop_income_hist_ban{iMCS} = wbl_pop_income_hist_ban_t;
    wbl_pop_supply_hist_ban{iMCS} = wbl_pop_supply_hist_ban_t;
    repair_pop_nWeek_ban(:,iMCS) = repair_pop_nWeek_ban_t;

    delP_hist(iMCS) = delP_m;
    delP_g_hist(iMCS) = delP_g_m;
    delQ_b_hist(iMCS) = delQ_b_m;
    QP_slope_hist(iMCS) = QP_slope_b_m;
    nWeek_disrup_hist(iMCS) = nWeek_disrup_m;

    nWeek_avg_noban_hist(iMCS) = mean( repair_pop_nWeek_noban_t );
    nWeek_avg_ban_hist(iMCS) = mean( repair_pop_nWeek_ban_t );


    disp( ['[Max. weeks for complete repair] No ban: ' num2str(max(repair_pop_nWeek_noban_t)) ', Ban: ' num2str(max(repair_pop_nWeek_ban_t))] )
    disp( ['[Average weeks for complete repair] No ban: ' num2str(mean(repair_pop_nWeek_noban_t)) ', Ban: ' num2str(mean(repair_pop_nWeek_ban_t))] )

end


%% Decision metrics
run test6_decision.m