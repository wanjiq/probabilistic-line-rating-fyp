function I_rating = rating_from_exceedance(I_list, Pexc_I, p_percent)
%RATING_FROM_EXCEEDANCE  Get rating current for a target exceedance percentage.
% Inputs:
%   I_list  : currents (A)
%   Pexc_I  : exceedance fractions for each current (same length)
%   p_percent : target exceedance in % (e.g. 5)
% Output:
%   I_rating : interpolated rating (A)

p = p_percent/100;

x = I_list(:);
y = Pexc_I(:);

ok = ~isnan(x) & ~isnan(y);
x = x(ok); y = y(ok);

% Sort by exceedance to invert safely
[yS, order] = sort(y, 'ascend');
xS = x(order);

% Unique y for interp
[yU, ia] = unique(yS, 'stable');
xU = xS(ia);

if p < yU(1) || p > yU(end)
    warning("Target %.2f%% outside range [%.2f%%, %.2f%%].", p_percent, 100*yU(1), 100*yU(end));
    I_rating = NaN;
    return;
end

I_rating = interp1(yU, xU, p, 'linear');
end
