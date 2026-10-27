# Could derivatives have predicted SVB's 2022 bond loss?

A calculus project in MATLAB. A bond's price is a function of its yield, P(y). Its first derivative gives **modified duration** and its second derivative gives **convexity**. Together they form a second-order Taylor expansion that estimates how much a bond loses when rates rise.

The project tests that idea on real data. It reprices US Treasuries through the 2022 rate shock. It then asks whether the duration that Silicon Valley Bank reported for its held-to-maturity (HTM) portfolio at the end of 2021 would have predicted the loss that portfolio took in 2022.

## Key results

**2022 back-test.** A par Treasury is bought at its end-2021 yield and repriced at its end-2022 yield:

| Tenor | Duration | Convexity | Duration only | Duration + convexity | Exact |
|---|---|---|---|---|---|
| 2y  | 1.98  | 4.9   | −7.29%  | −6.96%  | −6.97%  |
| 5y  | 4.83  | 26.2  | −13.19% | −12.21% | −12.26% |
| 10y | 9.24  | 94.0  | −21.82% | −19.20% | −19.41% |
| 30y | 22.79 | 624.8 | −47.17% | −33.78% | −36.11% |

Duration alone overstates the loss. Adding the convexity term gets within about 0.2 percentage points of the exact result up to 10 years.

**SVB.** The unrealized loss on SVB's HTM securities grew by **$14.18B** during 2022. Total equity was $16.0B. These estimates start from SVB's reported end-2021 duration of 4.1 years and use the move in the 5-year Treasury yield (+2.73 pp):

| Method | Estimate | vs. actual |
|---|---|---|
| A. Duration only | $10.88B | −23% |
| B. + Treasury-like (positive) convexity | $10.19B | −28% |
| C. + convexity implied by the duration rising from 4.1 to 6.2 years (negative, as in MBS) | $12.71B | −10% |
| D. Integrating along the duration path | $12.75B | −10% |

Duration alone already pointed to a loss of roughly two-thirds of SVB's equity. The remaining gap comes mostly from the **negative convexity** of mortgage-backed securities: as rates rose, prepayments slowed and the portfolio's duration extended. A +200 bp regulatory-style stress test on the end-2021 book gives a loss of $7.6–9.0B, which is 48–56% of equity.

## How to run

Open MATLAB in this folder and run one of the two entry points:

```
svb_derivatives   % whole project in one file
```

The chart shows the exact price curve, the tangent line (1st derivative) and the Taylor parabola (2nd derivative).

## Data sources

All figures were typed in by hand from public pages.

- US Treasury constant-maturity yields, 31 Dec 2021 and 30 Dec 2022: FRED series DGS2, DGS5, DGS10, DGS30 — https://fred.stlouisfed.org/series/DGS10
- SVB Financial Group HTM securities (amortized cost and fair value): FY2021 and FY2022 10-K filings, SEC EDGAR
- SVB HTM portfolio duration (4.1 and 6.2 years): Q4 2021 and Q4 2022 earnings releases (8-K Exhibit 99.1), SEC EDGAR
- SVB total equity ($16.0B): FY2022 10-K, Item 1
- 10-year Treasury 2022 total return (−17.83%), used as a cross-check: Aswath Damodaran, "Data Update 3 for 2023"

The exact URLs are listed next to each value in `svb_derivatives.m`.

## Limitations

- SVB's HTM book was mostly agency MBS, not Treasuries. A single Treasury yield move is only a proxy for the rates that drove its value.
- Reported duration is a portfolio average. The portfolio's composition also changed during 2022.
- This is an educational exercise, not investment or risk-management advice. SVB is named only as a public case study. This project has no affiliation with the bank or its successors.
