
function [ psnowc, psnic, pslwc, ptsoil, zrfrz, prhofirn,...
    zsupimp, pdgrain, zrogl, psn, pgrndc, pgrndd, pgrndcapc, pgrndhflx,...
    dH_comp, snowbkt, compaction, c] ...
    = subsurface(pts, pgrndc, pgrndd, pslwc, psnic, psnowc, prhofirn, ...
    ptsoil, pdgrain, zsn, zraind, zsnmel, zrogl, pTdeep,...
    snowbkt, c)

% HIRHAM subsurface scheme - version 2016
% Developped by Peter Langen (DMI), Robert Fausto (GEUS)
% and Baptiste Vandecrux (DTU-GEUS)
%
% Variables are:
%     grndhflx - diffusive heat flux to top layer from below (W/m2, positive upwards)
%     tsoil - Layerwise temperatures, top is layer 1 (K)
%     slwc - Layerwise liquid water content (m weq)
%     snic - Layerwise ice content (m weq)
%     snowc - Layerwise snow content (m weq)
%     rhofirn - Layerwise density of snow (kg/m3)
%     slush - Amount of liquid in slush bucket (m weq)
%     snmel - Melting of snow and ice (daily sum, mm/day weq)
%     rogl - Runoff (daily sum, mm/day weq)
%     sn - Snow depth (m weq)
%     rfrz - Layerwise refreezing (daily sum, mm/day weq)
%     supimp - Superimposed ice formation (daily sum, mm/day weq)
%  
% thickness_act(n) = snowc(n)*(rho_w/rhofirn(n)) + snic*(rho_w/rho_ice) + slwc

% NEW Model set up:
% Each layer has a part which is snow (snowc), ice (snic) and water (slwc), 
% and the total water equivalent thickness of layer n is 
% thickness_weq(n) = snowc(n)+snic(n)+slwc(n)
% This thickness is allowed to vary within certain rules.

   if sum(isnan(ptsoil))>1
    fjf= 0;
   end 
   ptsoil_s = ptsoil;
[ptsoil] = tsoil_diffusion (pts, pgrndc, pgrndd, ptsoil, c);
   if sum(isnan(ptsoil))>1
    fjf= 0;
   end 
[prhofirn, dH_comp, compaction] = densification (pslwc, psnowc , prhofirn, ptsoil, c);
                % Update BV 2018

                if c.track_density
                    c.rho_avg_aft_comp = Calculate20mAvgDensity(psnowc, psnic, pslwc, snowbkt, prhofirn, c);
                end

[pdgrain] =  graingrowth ( pslwc, psnowc , pdgrain, c);

[psnowc, psnic, pslwc, pdgrain, prhofirn, ptsoil, snowbkt]...
    = snowfall_new (zsn, psnowc, psnic, pslwc, pdgrain ...
    , prhofirn, ptsoil, pts,snowbkt, zraind, zsnmel,  c);
                % Update BV 2018
                if c.track_density
                    c.rho_avg_aft_snow = Calculate20mAvgDensity(psnowc, psnic, pslwc, snowbkt, prhofirn, c);
                end
%BV 2017 updating cdel, cmid and rcdel
c = update_column_properties(c,psnowc, psnic, pslwc);

[psnowc, psnic, pslwc, pdgrain, prhofirn, ptsoil, snowbkt]...
    = sublimation_new (zsn, psnowc, psnic, pslwc, pdgrain ...
    , prhofirn, ptsoil, snowbkt, c);
                % Update BV 2018
                if c.track_density
                    c.rho_avg_aft_subl = Calculate20mAvgDensity(psnowc, psnic, pslwc, snowbkt, prhofirn, c);
                end
                
%BV 2017 updating cdel, cmid and rcdel
c = update_column_properties(c,psnowc, psnic, pslwc);

[psnowc, psnic, pslwc, pdgrain, prhofirn, ptsoil ] ...
    = rainfall_new (zraind, psnowc, psnic, pslwc, pdgrain ...
    , prhofirn, ptsoil, pts, c);

%BV 2017 updating cdel, cmid and rcdel
c = update_column_properties(c,psnowc, psnic, pslwc);

[zso_capa, zso_cond] = ice_heats (ptsoil, c);

[psnowc, psnic, pslwc, snowbkt] = ...
        melting_new (psnowc, psnic, pslwc, zsnmel, snowbkt, ptsoil,prhofirn, c);
                % Update BV 2018
                if c.track_density
                    c.rho_avg_aft_melt = Calculate20mAvgDensity(psnowc, psnic, pslwc, snowbkt, prhofirn, c);
                end
                
%BV 2017 updating cdel, cmid and rcdel
c = update_column_properties(c,psnowc, psnic, pslwc);

if c.hetero_percol
    [pslwc] = hetero_percol (prhofirn, psnowc , psnic, pslwc, pdgrain, c);
end

[prhofirn, psnowc , psnic, pslwc, ptsoil , pdgrain, zrogl] =...
    perc_runoff_new (prhofirn, psnowc , psnic, pslwc, ptsoil , ...
    pdgrain, zrogl, c);
                % Update BV 2018
                if c.track_density
                    c.rho_avg_aft_runoff = Calculate20mAvgDensity(psnowc, psnic, pslwc, snowbkt, prhofirn, c);
                end
%BV 2017 updating cdel, cmid and rcdel
c = update_column_properties(c,psnowc, psnic, pslwc);

[ psnic, pslwc, ptsoil, zrfrz]...
    = refreeze (psnowc, psnic, pslwc, ptsoil, c );

%BV 2017 updating cdel, cmid and rcdel
c = update_column_properties(c,psnowc, psnic, pslwc);

[ptsoil ,  psnic, pslwc, zsupimp]...
    =  superimposedice (prhofirn, ptsoil            ...
    , psnowc  , psnic, pslwc, zso_cond, c );
                % Update BV 2018
                if c.track_density
                    c.rho_avg_aft_rfrz = Calculate20mAvgDensity(psnowc, psnic, pslwc, snowbkt, prhofirn, c);
                end
[prhofirn, psnowc , psnic, pslwc, ptsoil , pdgrain] =...
    merge_small_layers (prhofirn, psnowc , psnic, pslwc, ptsoil , ...
    pdgrain, c);
                % Update BV 2018
                if c.track_density
                    rho_avg_test = Calculate20mAvgDensity(psnowc, psnic, pslwc, snowbkt, prhofirn, c);
                    if abs(rho_avg_test - c.rho_avg_aft_rfrz) > 1
                        error('merge_small_layer changing density')
                    end
                end

%BV 2017 updating cdel, cmid and rcdel
c = update_column_properties(c,psnowc, psnic, pslwc);

[psn] =  calc_snowdepth1D (psnowc, psnic, snowbkt, c);

[pgrndc, pgrndd, pgrndcapc, pgrndhflx]...
    = update_tempdiff_params (prhofirn, pTdeep ...
    , psnowc, psnic, ptsoil, zso_cond, zso_capa, c);

end

