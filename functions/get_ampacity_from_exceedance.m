function I_rating = get_ampacity_from_exceedance(I_list, Tdesign_list, Pexc, Td, p_percent)
%GET_AMPACITY_FROM_EXCEEDANCE  Invert exceedance curve to get ampacity.
%
% I_rating = get_ampacity_from_exceedance(I_list, Tdesign_list, Pexc, Td, p_percent)
%
% Inputs:
%   I_list        : [nI x 1] currents used in sweep (A)
%   Tdesign_list  : [1 x nT] or [nT x 1] design temperatures (°C)
%   Pexc          : [nI x nT] fraction of time Tc >= Td for each (I, Td)
%   Td            : desired design temperature (°C), must exist in Tdesign_list
%   p_percent     : desired exceedance in percent (e.g., 5 for 5%)
%
% Output:
%   I_rating      : ampacity (A) such that exceedance ~= p_percent
%
% Notes:
%   - Uses linear interpolation on a monotonic-smoothed version of Pexc(:,Td).
%   - If p is outside the curve range, it returns NaN and prints a warning.

    p = p_percent / 100;

    % Find closest Td index (exact match preferred)
    Tdesign_list = Tdesign_list(:);
    [minDiff, idxT] = min(abs(Tdesign_list - Td));
    if minDiff > 1e-9
        warning("Td=%.3f not found exactly. Using closest Td=%.3f", Td, Tdesign_list(idxT));
    end

    y = Pexc(:, idxT);   % exceedance fractions for this Td
    x = I_list(:);

    % Remove NaNs
    ok = ~isnan(x) & ~isnan(y);
    x = x(ok); y = y(ok);

    if numel(x) < 2
        warning("Not enough points to interpolate.");
        I_rating = NaN;
        return;
    end

    % Sort by exceedance (y) for inversion
    % (Pexc should increase with I, but sorting makes inversion safe)
    [yS, order] = sort(y, 'ascend');
    xS = x(order);

    % De-duplicate y (interp1 needs unique x-values)
    [yU, ia] = unique(yS, 'stable');
    xU = xS(ia);

    % Check target within range
    if p < yU(1) || p > yU(end)
        warning("Requested exceedance %.2f%% outside available range [%.2f%%, %.2f%%]. Returning NaN.", ...
            p_percent, 100*yU(1), 100*yU(end));
        I_rating = NaN;
        return;
    end

    % Invert using interpolation: yU (exceedance) -> xU (current)
    I_rating = interp1(yU, xU, p, 'linear');
end
