function [psnic, psnowc, pslwc, pdgrain, prhofirn, ptsoil] = ...
            merge_layer(psnic, psnowc, pslwc, pdgrain, prhofirn, ptsoil, c)
% merge_layer: This function finds the two layers in the column that are
% most similar,merges them and frees the top layer. The similarity between
% layers is a weighted average of 5 objective criteria: difference in
% temperature, in firn denisty, in grain size, in ice fraction, in water
% content plus a 6th crietria that encourage the model to merge layers that
% are deeper in the column and therefore preserve good resolution near the
% surface. The parameter w can be tuned to encourage deep merging strongly(
% w<<1) or not encouraging at all (w>>1).
%	
%   input:
%         
%         prhofirn - vector of firn (snow) density (kg/m^3) 
%
%         psnowc, psnic, pslwc - vectors of respectively snow, ice and
%         liquid water part for each subsurface layer (m weq).
%
%         ptsoil - vector of subsurface temperature (K)
%
%         pdgrain - Vector of layer grain size. see graingrowth function.
%
%         c - Structure containing all the physical, site-dependant or user
%         defined variables.
%
%   output:
%          updated [psnowc, psnic, pslwc, pdgrain, prhofirn, ptsoil]
%
%   This script was originally developped by Baptiste Vandecrux (bava@byg.dtu.dk), 
%   Peter L. Langen (pla@dmi.dk) and Robert S. Fausto (rsf@geus.dk).
%=========================================================================

% CHANGE TO PERMEABILITY CRITERIA?
    % 1st criterion: Difference in temperature
    diff = abs(ptsoil(1:end-1) - ptsoil(2:end));
    diff(end+1) = diff(end);
    crit_1 = interp1([0, c.merge_crit_temp], [1, 0], diff, 'linear', 0);

    % 2nd criterion: Difference in firn density
    diff = abs(prhofirn(1:end-1) - prhofirn(2:end));
    diff(end+1) = diff(end);
    crit_2 = interp1([0, c.merge_crit_dens], [1, 0], diff, 'linear', 0);
    crit_2(and(psnowc(1:end-1)==0 , psnowc(2:end)==0)) = 0;

    % 3rd criterion: Difference in grain size
    diff = abs(pdgrain(1:end-1) - pdgrain(2:end));
    diff(end+1) = diff(end);
    crit_3 = interp1([0, c.merge_crit_gsize], [1, 0], diff, 'linear', 0);
    crit_3(and(psnowc(1:end-1)==0 , psnowc(2:end)==0)) = 0;

    % 4th criterion: Difference in water content (rel. to layer size)
    % saturation instead?
    rel_lwc = pslwc./(pslwc+psnic+psnowc);
    diff = abs(rel_lwc(1:end-1) - rel_lwc(2:end));
% 	diff(end+1) = diff(end);
    crit_4 = interp1([0, c.merge_crit_rel_lwc], [1, 0], diff, 'linear', 0);
    crit_4(and(pslwc(1:end-1)==0 , pslwc(2:end)==0)) = 0;
    crit_4(end+1) = crit_4(end);

    % 5th criterion: difference in ice content (rel. to layer size)
    rel_ic = psnic./(pslwc+psnic+psnowc);
    diff = abs(rel_ic(1:end-1) - rel_ic(2:end));
% 	diff(end+1) = diff(end);
    crit_5 = interp1([0, c.merge_crit_rel_snic], [1, 0], diff, 'linear', 0);
    crit_5(and(psnic(1:end-1)==0 , psnic(2:end)==0)) = 0;
    crit_5(end+1) = crit_5(end);

    % 6th criterion: arbitrary preference for deep layers to merge more
    % than shallow layers
    thickness_weq = psnic + psnowc + pslwc;
    depth_weq = cumsum(thickness_weq);
    mid_point_weq = depth_weq - thickness_weq./2;

    isshallow = mid_point_weq < c.shallow_firn_lim;
    isdeep    = mid_point_weq > c.deep_firn_lim;

    crit_6(isshallow) = 0;
    crit_6(isdeep) = 1;
    
    if sum(isshallow+isdeep) < length(mid_point_weq)
       isbetween = and(~isshallow,~isdeep);
        crit_6(isbetween) = interp1(...
            [c.deep_firn_lim, c.shallow_firn_lim],...
            [0.9, 0.1], mid_point_weq(isbetween));
    end
    crit_6 = crit_6';
    
    % Update BV2017: We keep one third of the layers to describe the two
    % deeper third of the column.
    if depth_weq(floor(c.jpgrnd*2/3)-1) < max(depth_weq)/3
        crit_6(floor(c.jpgrnd*2/3):end) = -1;
    end
    
    % final rating:
    w1 = 1;
    w2 = 1;
    w3 = 1;
    w4 = 2;
    w5 = 2;
    w6 = 1.5;
    crit = (w1.*crit_1 + w2.*crit_2+ w3.*crit_3 + w4.*crit_4 + w5.*crit_5 + w6 .* crit_6)./(w1+w2+w3+w4+w5+w6);
    
    [~, i_merg] = max(crit);
    i_merg = min(c.jpgrnd-1, i_merg);

% fprintf('Merging layer %i and %i.\n',i_merg, i_merg +1);

    % layer of index i_merg and i_merg+1 are merged
    if (psnowc(i_merg+1) + psnowc(i_merg))> c.smallno
        if psnowc(i_merg+1)<c.smallno
            psnowc(i_merg+1) = 0;
        end
        if psnowc(i_merg)<c.smallno
            psnowc(i_merg) = 0;
        end
        %if there is snow in the two layers
        pdgrain(i_merg+1) = (psnowc(i_merg) * pdgrain(i_merg) + psnowc(i_merg+1) * pdgrain(i_merg+1)) ...
           /(psnowc(i_merg+1) + psnowc(i_merg));
        prhofirn(i_merg+1) = (psnowc(i_merg+1) + psnowc(i_merg)) ...
           / (psnowc(i_merg)/prhofirn(i_merg) +  psnowc(i_merg+1)/prhofirn(i_merg+1));
    else
        pdgrain(i_merg+1) = -999;
        prhofirn(i_merg+1) = -999;
    end
    ptsoil(i_merg+1) = ((psnic(i_merg) + psnowc(i_merg) + pslwc(i_merg)) * ptsoil(i_merg) ...
        + (psnic(i_merg+1) + psnowc(i_merg+1) + pslwc(i_merg+1)) * ptsoil(i_merg+1)) ...
        /(psnic(i_merg) + psnowc(i_merg) + pslwc(i_merg) + psnic(i_merg+1) + psnowc(i_merg+1) + pslwc(i_merg+1));

    psnowc(i_merg+1) = psnowc(i_merg+1) + psnowc(i_merg);
    psnic(i_merg+1) = psnic(i_merg+1) + psnic(i_merg);
    pslwc(i_merg+1) = pslwc(i_merg+1) + pslwc(i_merg);

    % shifting column to free top layer
    if i_merg ~= 1
        psnowc(2:i_merg) = psnowc(1:i_merg-1);
        psnic(2:i_merg) = psnic(1:i_merg-1);
        pslwc(2:i_merg) = pslwc(1:i_merg-1);
        pdgrain(2:i_merg) = pdgrain(1:i_merg-1);
        prhofirn(2:i_merg) = prhofirn(1:i_merg-1);
        ptsoil(2:i_merg) = ptsoil(1:i_merg-1);
    end
end