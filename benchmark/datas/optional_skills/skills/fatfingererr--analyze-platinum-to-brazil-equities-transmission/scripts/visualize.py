#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Platinum vs Brazil Equities (EWZ) — Bloomberg-style visualization.

Two-panel layout:
  1. Dual-axis price chart (EWZ left, Platinum right)
  2. 36-Week Rolling Correlation

Usage:
    python visualize.py --start 2003-01-01
    python visualize.py --start 2003-01-01 --end 2026-01-28
"""

import argparse
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional

import matplotlib
matplotlib.use('Agg')

import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import matplotlib.gridspec as gridspec
import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).parent))
from fetch_data import fetch_aligned_data
from analyze import compute_log_returns, compute_rolling_correlation

# ============================================================================
# Configuration
# ============================================================================

ROLLING_WINDOW = 36  # weeks — fixed

plt.rcParams['font.sans-serif'] = ['DejaVu Sans', 'Arial', 'Helvetica']
plt.rcParams['axes.unicode_minus'] = False

COLORS = {
    "background": "#1a1a2e",
    "grid": "#2d2d44",
    "text": "#ffffff",
    "text_dim": "#888888",
    "platinum": "#00bcd4",
    "ewz": "#ff9800",
    "positive_corr": "#4caf50",
    "negative_corr": "#f44336",
    "best_lag": "#ffeb3b",
    "zero_line": "#555555",
}

OUTPUT_DIR = Path(__file__).parent.parent.parent.parent / "output"


# ============================================================================
# Chart Generation
# ============================================================================

def generate_chart(
    start: str,
    end: Optional[str] = None,
    freq: str = "1wk",
    platinum_ticker: str = "PL=F",
    brazil_ticker: str = "EWZ",
    output_path: Optional[str] = None,
    analysis_result: Optional[Dict] = None,
) -> str:
    """Generate a two-panel Bloomberg-style chart with source/as-of footer."""

    # Fetch data
    prices = fetch_aligned_data(start=start, end=end, freq=freq,
                                platinum_ticker=platinum_ticker,
                                brazil_ticker=brazil_ticker)

    if prices.empty:
        print("[Error] No data for chart")
        return ""

    col_pl = platinum_ticker
    col_ewz = brazil_ticker

    # Derived data
    returns = compute_log_returns(prices)
    roll_corr = compute_rolling_correlation(returns, col_pl, col_ewz, ROLLING_WINDOW)

    # ── Figure layout: 2 rows ──
    fig = plt.figure(figsize=(16, 10), facecolor=COLORS["background"])
    gs = gridspec.GridSpec(
        2, 1,
        height_ratios=[2, 1],
        hspace=0.30,
        left=0.07, right=0.93, top=0.93, bottom=0.08,
    )

    # ── Panel 1: Dual-axis price chart ──
    ax1 = fig.add_subplot(gs[0])
    _style_axis(ax1)
    ax1_pl = ax1.twinx()

    # 100-week EMA
    EMA_SPAN = 100
    ewz_ema = prices[col_ewz].ewm(span=EMA_SPAN, adjust=False).mean()
    pl_ema = prices[col_pl].ewm(span=EMA_SPAN, adjust=False).mean()

    ax1.plot(prices.index, prices[col_ewz], color=COLORS["ewz"],
             linewidth=1.2, label=f"{col_ewz} (left)", alpha=0.9)
    ax1.plot(ewz_ema.index, ewz_ema, color=COLORS["ewz"],
             linewidth=0.8, linestyle='--', alpha=0.35, label=f"{col_ewz} 100w EMA")
    ax1_pl.plot(prices.index, prices[col_pl], color=COLORS["platinum"],
                linewidth=1.2, label=f"{col_pl} (right)", alpha=0.9)
    ax1_pl.plot(pl_ema.index, pl_ema, color=COLORS["platinum"],
                linewidth=0.8, linestyle='--', alpha=0.35, label=f"{col_pl} 100w EMA")

    ax1.set_ylabel(f"{col_ewz} (USD)", color=COLORS["ewz"], fontsize=10)
    ax1_pl.set_ylabel(f"{col_pl} (USD/oz)", color=COLORS["platinum"], fontsize=10)
    ax1.tick_params(axis='y', colors=COLORS["ewz"])
    ax1_pl.tick_params(axis='y', colors=COLORS["platinum"])
    ax1_pl.spines['right'].set_color(COLORS["platinum"])
    ax1_pl.spines['left'].set_color(COLORS["ewz"])

    ax1.set_title(
        f"Platinum ({col_pl}) vs Brazil Equities ({col_ewz})",
        color=COLORS["text"], fontsize=13, fontweight='bold', pad=10,
    )

    # Combined legend
    lines1, labels1 = ax1.get_legend_handles_labels()
    lines2, labels2 = ax1_pl.get_legend_handles_labels()
    ax1.legend(lines1 + lines2, labels1 + labels2,
               loc='upper left', fontsize=9, facecolor=COLORS["background"],
               edgecolor=COLORS["grid"], labelcolor=COLORS["text"])

    ax1.xaxis.set_major_formatter(mdates.DateFormatter('%Y'))
    ax1.xaxis.set_major_locator(mdates.YearLocator(2))

    # ── Panel 2: 36-Week Rolling Correlation ──
    ax2 = fig.add_subplot(gs[1], sharex=ax1)
    _style_axis(ax2)

    pos_mask = roll_corr >= 0
    neg_mask = roll_corr < 0

    ax2.fill_between(roll_corr.index, 0, roll_corr.where(pos_mask),
                     color=COLORS["positive_corr"], alpha=0.3)
    ax2.fill_between(roll_corr.index, 0, roll_corr.where(neg_mask),
                     color=COLORS["negative_corr"], alpha=0.3)
    ax2.plot(roll_corr.index, roll_corr, color=COLORS["text"],
             linewidth=0.8, alpha=0.8)

    ax2.axhline(y=0, color=COLORS["zero_line"], linewidth=0.8)
    ax2.axhline(y=0.5, color=COLORS["text_dim"], linewidth=0.3, linestyle='--')
    ax2.axhline(y=-0.5, color=COLORS["text_dim"], linewidth=0.3, linestyle='--')

    ax2.set_ylim(-1, 1)
    ax2.set_ylabel("Correlation", color=COLORS["text_dim"], fontsize=9)
    ax2.set_title(
        f"{ROLLING_WINDOW}-Week Rolling Correlation (latest: {roll_corr.iloc[-1]:.3f})",
        color=COLORS["text"], fontsize=11, fontweight='bold', pad=8,
    )
    ax2.xaxis.set_major_formatter(mdates.DateFormatter('%Y'))
    ax2.xaxis.set_major_locator(mdates.YearLocator(2))

    # ── Low-correlation zone highlighting (<0.05) on both panels ──
    DECORR_THRESHOLD = 0.05
    low_corr_mask = roll_corr < DECORR_THRESHOLD

    # Align mask to prices index for ax1 shading
    low_corr_aligned = low_corr_mask.reindex(prices.index, method='nearest').fillna(False)

    # Shade both panels
    for ax in (ax1, ax2):
        ax.fill_between(
            prices.index, 0, 1,
            where=low_corr_aligned,
            transform=ax.get_xaxis_transform(),
            color=COLORS["negative_corr"], alpha=0.12,
            linewidth=0, zorder=0,
        )

    # ── Mark arrows at END of each low-corr zone ──
    # Direction depends on Platinum vs 100-week EMA:
    #   PL below 100w EMA → arrow ABOVE EWZ, pointing DOWN (bearish)
    #   PL above 100w EMA → arrow BELOW EWZ, pointing UP   (bullish)

    mask_arr = low_corr_aligned.astype(int)
    diff = mask_arr.diff().fillna(0)
    zone_ends = diff[diff == -1].index

    for end_date in zone_ends:
        loc = prices.index.get_loc(end_date)
        if loc == 0:
            continue
        bottom_date = prices.index[loc - 1]
        ewz_val = float(prices[col_ewz].loc[bottom_date])

        # Determine Platinum vs 100w EMA direction
        ma_val = pl_ema.loc[bottom_date] if bottom_date in pl_ema.index else np.nan
        pl_val = float(prices[col_pl].loc[bottom_date])

        if pd.isna(ma_val):
            continue

        pl_below_ma = pl_val < float(ma_val)

        if pl_below_ma:
            # Platinum below 100w EMA → bearish → arrow above, pointing down
            ax1.annotate(
                '',
                xy=(bottom_date, ewz_val),
                xytext=(0, 22),
                textcoords='offset points',
                arrowprops=dict(
                    arrowstyle='-|>',
                    color=COLORS["negative_corr"],
                    lw=1.8,
                ),
            )
        else:
            # Platinum above 100w EMA → bullish → arrow below, pointing up
            ax1.annotate(
                '',
                xy=(bottom_date, ewz_val),
                xytext=(0, -22),
                textcoords='offset points',
                arrowprops=dict(
                    arrowstyle='-|>',
                    color=COLORS["best_lag"],
                    lw=1.8,
                ),
            )

    # ── Footer: Source (left) / As of (right) ──
    data_start = prices.index[0].strftime('%Y-%m-%d')
    data_end = prices.index[-1].strftime('%Y-%m-%d')
    as_of_str = datetime.now().strftime('%Y-%m-%d')

    fig.text(
        0.07, 0.015,
        f"Source: Yahoo Finance ({col_pl}, {col_ewz}), {data_start} to {data_end}",
        ha='left', fontsize=8, color=COLORS["text_dim"],
    )
    fig.text(
        0.93, 0.015,
        f"As of {as_of_str}",
        ha='right', fontsize=8, color=COLORS["text_dim"],
    )

    # ── Score / Regime annotation (if analysis result provided) ──
    if analysis_result and analysis_result.get("status") == "ok":
        t = analysis_result["transmission"]
        score_text = (
            f"Transmission Score: {t['transmission_strength_score_0_100']}/100"
            f"  |  Regime: {t['regime']['label']}"
            f"  |  Latest Corr: {t['rolling_corr']['latest']:.3f}"
        )
        fig.text(
            0.5, 0.015, score_text,
            ha='center', fontsize=9,
            color=COLORS["best_lag"], fontweight='bold',
            bbox=dict(
                boxstyle='round,pad=0.4',
                facecolor=COLORS["background"],
                edgecolor=COLORS["best_lag"],
                alpha=0.8,
            ),
        )

    # ── Save ──
    if output_path is None:
        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        date_str = datetime.now().strftime("%Y-%m-%d")
        output_path = str(OUTPUT_DIR / f"platinum_vs_ewz_{date_str}.png")

    fig.savefig(output_path, dpi=150, bbox_inches='tight',
                facecolor=COLORS["background"], edgecolor='none')
    plt.close(fig)

    print(f"[Chart] Saved to {output_path}")
    return output_path


def _style_axis(ax):
    """Apply Bloomberg dark-theme style to an axis."""
    ax.set_facecolor(COLORS["background"])
    ax.tick_params(colors=COLORS["text_dim"], labelsize=8)
    for spine in ax.spines.values():
        spine.set_color(COLORS["grid"])
    ax.grid(True, color=COLORS["grid"], linewidth=0.3, alpha=0.5)


# ============================================================================
# CLI
# ============================================================================

def main():
    parser = argparse.ArgumentParser(description="Platinum vs EWZ Bloomberg-style Chart")
    parser.add_argument("--start", required=True, help="Start date (YYYY-MM-DD)")
    parser.add_argument("--end", default=None, help="End date (YYYY-MM-DD)")
    parser.add_argument("--freq", default="1wk", choices=["1d", "1wk", "1mo"])
    parser.add_argument("--platinum", default="PL=F")
    parser.add_argument("--brazil", default="EWZ")
    parser.add_argument("--output", default=None, help="Output path")
    args = parser.parse_args()

    path = generate_chart(
        start=args.start, end=args.end, freq=args.freq,
        platinum_ticker=args.platinum, brazil_ticker=args.brazil,
        output_path=args.output,
    )

    if path:
        print(f"\nChart generated: {path}")

if __name__ == "__main__":
    main()
