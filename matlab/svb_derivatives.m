
% The price of a bond is a function of its yield, P(y).
%   1st derivative -> modified duration
%   2nd derivative -> convexity
% With a 2nd order Taylor expansion these give the price change for a rate change.
%

clear; clc;

%% Data
% Typed in by hand from the public sources below.

% US Treasury yields at year end (FRED series DGS2, DGS5, DGS10, DGS30)
% https://fred.stlouisfed.org/series/DGS10
tenors = [2 5 10 30];
y2021 = [0.73 1.26 1.52 1.90] / 100;   % 31 Dec 2021
y2022 = [4.41 3.99 3.88 3.97] / 100;   % 30 Dec 2022

% 2022 total return of the 10 year Treasury according to Damodaran (used as a check)
% https://aswathdamodaran.blogspot.com/2023/01/data-update-3-for-2023-inflation-and.html
damodaran10y = -0.1783;

% SVB held-to-maturity securities in dollars, first value 2021, second 2022
% https://www.sec.gov/Archives/edgar/data/719739/000071973922000023/R93.htm (2021 10-K)
% https://www.sec.gov/Archives/edgar/data/719739/000071973923000021/R91.htm (2022 10-K)
cost = [98.202e9 91.327e9];
fair = [97.227e9 76.169e9];

% Duration of the HTM portfolio in years (Q4 earnings releases, 8-K Ex. 99.1)
% https://www.sec.gov/Archives/edgar/data/719739/000071973922000007/q421earningsrelease_991.htm
% https://www.sec.gov/Archives/edgar/data/719739/000071973923000009/q422earningsrelease_991.htm
D0 = 4.1;   % end of 2021
D1 = 6.2;   % end of 2022

% Total equity at the end of 2022 (2022 10-K, Item 1)
equity = 16.0e9;


%% Part 1: check the derivatives with finite differences
% 10 year bond bought at par, so coupon = yield = 1.52%
y = 0.0152;
c = 0.0152;
T = 10;
h = 1e-4;   % 1 basis point

[ctr, sec, fwd] = finite_diff(y, c, T, h);
d1 = dprice(y, c, T);
d2 = d2price(y, c, T);

fprintf('Part 1: analytic derivative vs finite difference\n');
fprintf('P''(y):  analytic = %.6f, central = %.6f, forward (PV01) = %.6f\n', d1, ctr, fwd);
fprintf('P''''(y): analytic = %.4f, central = %.4f\n', d2, sec);
fprintf('relative error: 1st = %.1e, 2nd = %.1e\n', abs(ctr/d1 - 1), abs(sec/d2 - 1));
fprintf('DV01 for $100 face = %.4f\n\n', dv01(y, c, T));


%% Part 2: 2022 back-test on Treasuries
% Buy a par bond at the 2021 yield, then move the yield to the 2022 level.
fprintf('Part 2: 2022 back-test\n');
fprintf('tenor     D       C   duration only   dur + conv    exact\n');
for i = 1:4
    T = tenors(i);
    y0 = y2021(i);
    dy = y2022(i) - y0;

    D = duration(y0, y0, T);
    C = convexity(y0, y0, T);
    [first, second] = taylor_estimate(y0, dy, y0, T);
    exact = price(y0 + dy, y0, T) / price(y0, y0, T) - 1;

    fprintf('%4dy %7.2f %7.1f %+13.2f%% %+11.2f%% %+8.2f%%\n', ...
        T, D, C, 100*first, 100*second, 100*exact);
end

% Total return of the 10y bond in 2022: price change + one year of coupon
y0 = y2021(3);
y1 = y2022(3);
totalReturn = price(y1, y0, 10)/100 - 1 + y0;
fprintf('10y total return in 2022: %+.2f%% (Damodaran: %+.2f%%)\n\n', ...
    100*totalReturn, 100*damodaran10y);


%% Part 3: SVB
% Unrealized loss = fair value - cost. The part that appeared during 2022:
loss2022 = (fair(1) - cost(1)) - (fair(2) - cost(2));
V0 = fair(1);
fprintf('Part 3: SVB\n');
fprintf('actual loss in 2022 = $%.2fB (equity = $%.2fB)\n', loss2022/1e9, equity/1e9);

% SVB doesn't say which rate its bonds follow, so try both the 5y and the 10y move.
for j = 2:3
    y0 = y2021(j);
    dy = y2022(j) - y0;

    % convexity of a Treasury with the same duration (positive)
    Ct = convexity_for_duration(D0, y0);
    % convexity implied by the duration going from 4.1 to 6.2 (negative)
    Ci = implied_convexity(D0, D1, dy);

    estA = V0 * D0 * dy;                  % duration only
    estB = V0 * (D0*dy - 0.5*Ct*dy^2);    % + Treasury convexity
    estC = V0 * (D0*dy - 0.5*Ci*dy^2);    % + implied convexity
    estD = integral_loss(V0, D0, D1, dy); % integrate the duration

    fprintf('\n%dy rate move: dy = %.2f pp, Treasury C = %+.1f, implied C = %+.1f\n', ...
        tenors(j), 100*dy, Ct, Ci);
    fprintf('A. duration only:            $%.2fB (%+.0f%% vs actual)\n', estA/1e9, 100*(estA/loss2022 - 1));
    fprintf('B. + Treasury convexity:     $%.2fB (%+.0f%% vs actual)\n', estB/1e9, 100*(estB/loss2022 - 1));
    fprintf('C. + implied convexity:      $%.2fB (%+.0f%% vs actual)\n', estC/1e9, 100*(estC/loss2022 - 1));
    fprintf('D. integrate duration path:  $%.2fB (%+.0f%% vs actual)\n', estD/1e9, 100*(estD/loss2022 - 1));
end


%% Part 4: DV01 and a +200bp shock at the end of 2021
fprintf('\nPart 4: stress test\n');
fprintf('portfolio DV01 = V*D*0.0001 = $%.1fM per 1bp\n', V0*D0*1e-4/1e6);

shock = 0.02;
y0 = y2021(2);
dy5 = y2022(2) - y0;
linearLoss = V0 * D0 * shock;

% with Treasury convexity
C = convexity_for_duration(D0, y0);
curve = 0.5 * V0 * C * shock^2;
loss = linearLoss - curve;
fprintf('+200bp, Treasury C = %+.1f: linear $%.2fB, curvature %+.2fB -> loss $%.2fB = %.0f%% of equity\n', ...
    C, linearLoss/1e9, curve/1e9, loss/1e9, 100*loss/equity);

% with the implied (MBS) convexity
C = implied_convexity(D0, D1, dy5);
curve = 0.5 * V0 * C * shock^2;
loss = linearLoss - curve;
fprintf('+200bp, implied C = %+.1f: linear $%.2fB, curvature %+.2fB -> loss $%.2fB = %.0f%% of equity\n', ...
    C, linearLoss/1e9, curve/1e9, loss/1e9, 100*loss/equity);


%% Part 5: plot price, tangent line and parabola
y0 = y2021(3);
T = 10;
ys = linspace(0, 0.06, 200);

Py = zeros(size(ys));
for i = 1:length(ys)
    Py(i) = price(ys(i), y0, T);
end

p0 = price(y0, y0, T);
p1 = dprice(y0, y0, T);
p2 = d2price(y0, y0, T);
tangent = p0 + p1*(ys - y0);
parabola = p0 + p1*(ys - y0) + 0.5*p2*(ys - y0).^2;

figure; hold on;
plot(100*ys, Py, 'LineWidth', 2);
plot(100*ys, tangent, '--');
plot(100*ys, parabola, ':', 'LineWidth', 2);
plot(100*y0, p0, 'ko', 'MarkerFaceColor', 'k');
xline(100*y2022(3), 'Color', [0.5 0.5 0.5]);
xlabel('Yield (%)');
ylabel('Price per $100 face');
title('10-year Treasury (1.52% coupon): price vs. yield');
legend('Exact price P(y)', '1st derivative: tangent (duration)', ...
    '1st + 2nd derivative: parabola (convexity)', 'Location', 'northeast');


%% Functions
% Treasuries pay coupons twice a year, so y is compounded semiannually.

function [k, CF] = cash_flows(c, T)
% k = 1..2T half-year periods, each coupon is 100*c/2,
% and the last payment also includes the face value 100
k = 1:round(2*T);
CF = 100*c/2 * ones(size(k));
CF(end) = CF(end) + 100;
end

function P = price(y, c, T)
% P(y) = sum of CF_k / (1 + y/2)^k
[k, CF] = cash_flows(c, T);
P = sum(CF .* (1 + y/2).^(-k));
end

function dP = dprice(y, c, T)
% 1st derivative with the power and chain rule:
% dP/dy = -(1/2) * sum of k * CF_k * (1 + y/2)^(-k-1)
[k, CF] = cash_flows(c, T);
dP = -0.5 * sum(k .* CF .* (1 + y/2).^(-k-1));
end

function d2P = d2price(y, c, T)
% 2nd derivative:
% d2P/dy2 = (1/4) * sum of k(k+1) * CF_k * (1 + y/2)^(-k-2)
[k, CF] = cash_flows(c, T);
d2P = 0.25 * sum(k .* (k+1) .* CF .* (1 + y/2).^(-k-2));
end

function D = duration(y, c, T)
% modified duration D = -P'(y) / P(y)
D = -dprice(y, c, T) / price(y, c, T);
end

function C = convexity(y, c, T)
% convexity C = P''(y) / P(y)
C = d2price(y, c, T) / price(y, c, T);
end

function d = dv01(y, c, T)
% loss per $100 face when the yield rises 1 basis point
d = -dprice(y, c, T) * 1e-4;
end

function [ctr, sec, fwd] = finite_diff(y, c, T, h)
% central difference for P', central difference for P'',
% and forward difference (this is how Basel MAR21.19 defines PV01)
Pup = price(y + h, c, T);
Pmid = price(y, c, T);
Pdown = price(y - h, c, T);
ctr = (Pup - Pdown) / (2*h);
sec = (Pup - 2*Pmid + Pdown) / h^2;
fwd = (Pup - Pmid) / h;
end

function [first, second] = taylor_estimate(y, dy, c, T)
% percentage price change when the yield moves by dy
% first:  only the 1st derivative (tangent line)
% second: 1st + 2nd derivative (parabola)
D = duration(y, c, T);
C = convexity(y, c, T);
first = -D*dy;
second = -D*dy + 0.5*C*dy^2;
end

function C = implied_convexity(D0, D1, dy)
% From D = -P'/P the quotient rule gives dD/dy = D^2 - C, so C = D^2 - dD/dy.
% Use the average duration for D and (D1 - D0)/dy for dD/dy.
Dbar = (D0 + D1) / 2;
C = Dbar^2 - (D1 - D0) / dy;
end

function loss = integral_loss(V0, D0, D1, dy)
% d/dy ln V = -D, so V1 = V0 * exp(-integral of D dy).
% Trapezoid rule: integral = Dbar*dy
Dbar = (D0 + D1) / 2;
loss = V0 * (1 - exp(-Dbar * dy));
end

function C = convexity_for_duration(target, y)
% convexity of a par Treasury whose duration equals target:
% find the two half-year maturities around it and interpolate linearly
hi = 0.5;
while duration(y, y, hi) < target
    hi = hi + 0.5;
end
lo = hi - 0.5;
Dlo = duration(y, y, lo);
Dhi = duration(y, y, hi);
w = (target - Dlo) / (Dhi - Dlo);
C = (1 - w) * convexity(y, y, lo) + w * convexity(y, y, hi);
end
