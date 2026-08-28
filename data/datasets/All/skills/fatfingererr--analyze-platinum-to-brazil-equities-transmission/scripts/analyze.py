#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
白金→巴西股市 傳導分析

執行完整的傳導檢驗：領先落後、Rolling Correlation、Regime 判斷、傳導強度分數。

Usage:
    python analyze.py --start 2003-01-01
    python analyze.py --start 2003-01-01 --end 2026-01-28 --freq 1wk
    python analyze.py --start 2003-01-01 --output-mode both --chart
"""

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional, Tuple

import numpy as np
import pandas as pd

# 加入本目錄到 path
sys.path.insert(0, str(Path(__file__).parent))
from fetch_data import fetch_aligned_data

# ============================================================================
# 配置
# ============================================================================

DEFAULT_CORR_WINDOW = 52
DEFAULT_LEAD_LAG_MAX = 52
DEFAULT_REGIME_WINDOW = 104
DEFAULT_NORMALIZE_BASE = 100

OUTPUT_DIR = Path(__file__).parent.parent.parent.parent / "output"


# ============================================================================
# 分析函數
# ============================================================================

def compute_log_returns(prices: pd.DataFrame) -> pd.DataFrame:
    """計算 log return"""
    return np.log(prices).diff().dropna()


def compute_rolling_correlation(
    returns: pd.DataFrame,
    col_a: str,
    col_b: str,
    window: int = DEFAULT_CORR_WINDOW,
) -> pd.Series:
    """計算 rolling correlation"""
    return returns[col_a].rolling(window).corr(returns[col_b]).dropna()


def compute_best_lead_lag(
    returns: pd.DataFrame,
    col_platinum: str,
    col_ewz: str,
    max_lag: int = DEFAULT_LEAD_LAG_MAX,
) -> Dict:
    """
    掃描 [-max_lag, +max_lag] 找最佳領先落後。

    lag > 0: platinum leads EWZ
    lag < 0: EWZ leads platinum
    """
    r_pl = returns[col_platinum]
    r_ewz = returns[col_ewz]

    best = {"lag": 0, "corr": 0.0}
    all_lags = {}

    for lag in range(-max_lag, max_lag + 1):
        c = r_ewz.corr(r_pl.shift(lag))
        if pd.notna(c):
            all_lags[lag] = float(c)
            if abs(c) > abs(best["corr"]):
                best = {"lag": lag, "corr": float(c)}

    # 解讀
    if best["lag"] > 0:
        meaning = f"Platinum leads EWZ by ~{best['lag']} periods"
    elif best["lag"] < 0:
        meaning = f"EWZ leads Platinum by ~{abs(best['lag'])} periods"
    else:
        meaning = "Platinum and EWZ move simultaneously"

    return {
        "lag": best["lag"],
        "corr": round(best["corr"], 4),
        "meaning": meaning,
        "all_lags": all_lags,
    }


def compute_regime(
    prices: pd.DataFrame,
    col_platinum: str,
    col_ewz: str,
    rolling_corr_latest: float,
    regime_window: int = DEFAULT_REGIME_WINDOW,
) -> Dict:
    """判斷當前 regime"""
    # 取最近 regime_window 期的數據
    recent = prices.iloc[-regime_window:] if len(prices) >= regime_window else prices

    # 計算 26 期均線斜率
    ma_window = min(26, len(recent) // 4)
    ma_pl = recent[col_platinum].rolling(ma_window).mean()
    ma_ewz = recent[col_ewz].rolling(ma_window).mean()

    slope_pl = ma_pl.diff().dropna()
    slope_ewz = ma_ewz.diff().dropna()

    # 趨勢一致性：斜率符號相同的比例
    aligned = pd.concat([slope_pl, slope_ewz], axis=1).dropna()
    if len(aligned) == 0:
        return {"label": "inconclusive", "trend_agreement": 0.0, "detail": "數據不足"}

    signs_match = (np.sign(aligned.iloc[:, 0]) == np.sign(aligned.iloc[:, 1]))
    trend_agreement = float(signs_match.mean())

    # EWZ 累積報酬
    ewz_cum_return = float(recent[col_ewz].iloc[-1] / recent[col_ewz].iloc[0] - 1)

    # Regime 判定
    if trend_agreement >= 0.6 and rolling_corr_latest > 0:
        label = "linked_upcycle"
        detail = f"趨勢一致性 {trend_agreement:.1%}，rolling corr {rolling_corr_latest:.3f}，傳導結構活躍"
    elif rolling_corr_latest < -0.2 and ewz_cum_return < 0:
        label = "brazil_idiosyncratic"
        detail = f"Rolling corr {rolling_corr_latest:.3f}（負），EWZ 累積報酬 {ewz_cum_return:.1%}，巴西特有風險主導"
    else:
        label = "decoupled"
        detail = f"趨勢一致性 {trend_agreement:.1%}，rolling corr {rolling_corr_latest:.3f}，關聯斷裂"

    return {
        "label": label,
        "trend_agreement": round(trend_agreement, 4),
        "ewz_cum_return": round(ewz_cum_return, 4),
        "detail": detail,
    }


def compute_transmission_score(
    best_corr: float,
    rolling_stability: float,
    trend_agreement: float,
) -> Dict:
    """計算傳導強度分數（0-100）"""
    # 映射到 0-100
    s_corr = min(abs(best_corr) / 0.7, 1.0) * 100
    s_stability = rolling_stability * 100
    s_trend = trend_agreement * 100

    # 加權
    w_corr, w_stability, w_trend = 0.30, 0.30, 0.40
    score = w_corr * s_corr + w_stability * s_stability + w_trend * s_trend

    return {
        "score": round(score, 1),
        "best_corr_component": round(w_corr * s_corr, 1),
        "rolling_stability_component": round(w_stability * s_stability, 1),
        "trend_agreement_component": round(w_trend * s_trend, 1),
        "raw": {
            "s_corr": round(s_corr, 1),
            "s_stability": round(s_stability, 1),
            "s_trend": round(s_trend, 1),
        },
    }


def determine_signal(score: float, best_lag: int, best_corr: float) -> Tuple[str, str]:
    """決定 signal 和 confidence"""
    if score >= 70 and best_lag > 0 and abs(best_corr) >= 0.35:
        return "transmission_strong", "high"
    elif score >= 50 and abs(best_corr) >= 0.25:
        return "transmission_moderate", "medium"
    elif score >= 30:
        return "transmission_weak", "low"
    else:
        return "inconclusive", "low"


def generate_monitoring_notes(
    best_lag: int,
    regime_label: str,
    rolling_corr_latest: float,
    freq: str,
) -> list:
    """生成監控清單"""
    unit = {"1d": "天", "1wk": "週", "1mo": "月"}.get(freq, "期")
    notes = []

    if best_lag > 0:
        half_lag = max(1, best_lag // 2)
        double_lag = best_lag * 2
        notes.append(
            f"若 PL=F 突破長期區間，觀察 EWZ 在 {half_lag}-{double_lag} {unit}內是否趨勢翻多"
        )

    notes.append(
        f"要求 52{unit} rolling corr 維持正值至少 26 {unit}作為確認"
    )
    notes.append(
        "若白金大漲而 EWZ 不動且 corr 轉負，視為 regime break（可能為巴西特有風險主導）"
    )

    if regime_label == "decoupled":
        notes.append("當前處於 decoupled regime，傳導敘事暫時失效，建議降低關注度")

    return notes


# ============================================================================
# 主分析
# ============================================================================

def run_analysis(
    start: str,
    end: Optional[str] = None,
    freq: str = "1wk",
    platinum_ticker: str = "PL=F",
    brazil_ticker: str = "EWZ",
    corr_window: int = DEFAULT_CORR_WINDOW,
    lead_lag_max: int = DEFAULT_LEAD_LAG_MAX,
    regime_window: int = DEFAULT_REGIME_WINDOW,
    normalize_base: int = DEFAULT_NORMALIZE_BASE,
    force_refresh: bool = False,
) -> Dict:
    """執行完整分析"""

    # Step 1: 取得數據
    prices = fetch_aligned_data(
        start=start, end=end, freq=freq,
        platinum_ticker=platinum_ticker,
        brazil_ticker=brazil_ticker,
        force_refresh=force_refresh,
    )

    if prices.empty:
        return {"status": "error", "message": "No data available"}

    col_pl = platinum_ticker
    col_ewz = brazil_ticker

    # Step 2: 衍生數據
    normalized = prices / prices.iloc[0] * normalize_base
    returns = compute_log_returns(prices)

    # Step 3: Rolling Correlation
    roll_corr = compute_rolling_correlation(returns, col_pl, col_ewz, corr_window)
    rolling_corr_latest = float(roll_corr.iloc[-1]) if len(roll_corr) > 0 else 0.0

    # Rolling corr 統計
    positive_share_full = float((roll_corr > 0).mean()) if len(roll_corr) > 0 else 0.0

    # 近 5 年
    five_years_periods = {"1d": 252 * 5, "1wk": 52 * 5, "1mo": 12 * 5}.get(freq, 260)
    recent_corr = roll_corr.iloc[-five_years_periods:] if len(roll_corr) >= five_years_periods else roll_corr
    positive_share_5y = float((recent_corr > 0).mean()) if len(recent_corr) > 0 else 0.0

    # 最長連續正/負
    if len(roll_corr) > 0:
        pos_runs = (roll_corr > 0).astype(int)
        neg_runs = (roll_corr <= 0).astype(int)
        max_pos = int(_max_consecutive(pos_runs))
        max_neg = int(_max_consecutive(neg_runs))
    else:
        max_pos = max_neg = 0

    # Step 4: Lead-Lag
    lead_lag = compute_best_lead_lag(returns, col_pl, col_ewz, lead_lag_max)

    # Step 5: Regime
    regime = compute_regime(prices, col_pl, col_ewz, rolling_corr_latest, regime_window)

    # Step 6: Transmission Score
    score_result = compute_transmission_score(
        best_corr=lead_lag["corr"],
        rolling_stability=positive_share_5y,
        trend_agreement=regime["trend_agreement"],
    )

    # Step 7: Signal & Confidence
    signal, confidence = determine_signal(
        score_result["score"], lead_lag["lag"], lead_lag["corr"]
    )

    # Step 8: Monitoring Notes
    monitoring = generate_monitoring_notes(
        lead_lag["lag"], regime["label"], rolling_corr_latest, freq
    )

    # Step 9: Interpretation
    if signal in ("transmission_strong", "transmission_moderate"):
        interpretation = (
            f"白金具備{'高度' if signal == 'transmission_strong' else '中度'}領先 EWZ 的傳導特徵，"
            f"最佳領先期約 {lead_lag['lag']} {_freq_unit(freq)}，"
            f"52{_freq_unit(freq)} rolling correlation 有 {positive_share_5y:.0%} 時間為正。"
            f"當前處於 {regime['label']} 體制。"
        )
    elif signal == "transmission_weak":
        interpretation = (
            f"白金與 EWZ 的關聯具 regime-dependent 性質，需警惕敘事失效。"
            f"Rolling correlation 正值佔比僅 {positive_share_5y:.0%}，"
            f"當前處於 {regime['label']} 體制。"
        )
    else:
        interpretation = (
            f"數據不足以支持白金領先 EWZ 的敘事。"
            f"最佳 lag = {lead_lag['lag']}（{lead_lag['meaning']}），相關係數僅 {lead_lag['corr']}。"
        )

    # 組裝結果
    result = {
        "skill": "analyze-platinum-to-brazil-equities-transmission",
        "as_of": datetime.now().strftime("%Y-%m-%d"),
        "status": "ok",
        "pair": {
            "platinum": platinum_ticker,
            "brazil_equities": brazil_ticker,
        },
        "period": {
            "start": str(prices.index.min().date()),
            "end": str(prices.index.max().date()),
            "frequency": freq,
            "data_points": len(prices),
        },
        "signal": signal,
        "confidence": confidence,
        "transmission": {
            "transmission_strength_score_0_100": score_result["score"],
            "best_lead_lag": {
                "lag_weeks": lead_lag["lag"],
                "meaning": lead_lag["meaning"],
                "corr": lead_lag["corr"],
            },
            "rolling_corr": {
                "window_weeks": corr_window,
                "latest": round(rolling_corr_latest, 4),
                "positive_share_full": round(positive_share_full, 4),
                "positive_share_5y": round(positive_share_5y, 4),
                "max_consecutive_positive_weeks": max_pos,
                "max_consecutive_negative_weeks": max_neg,
            },
            "regime": regime,
            "score_breakdown": score_result,
        },
        "interpretation": interpretation,
        "monitoring_notes": monitoring,
        "data_limitations": [
            "交叉相關只顯示統計關聯，不代表因果關係",
            "EWZ 以美元計價，受 BRL/USD 匯率影響",
            "期貨價格在展延日可能出現非市場因素的跳動",
        ],
    }

    return result


def _max_consecutive(binary_series: pd.Series) -> int:
    """計算最長連續 1 的長度"""
    groups = binary_series.ne(binary_series.shift()).cumsum()
    return binary_series.groupby(groups).sum().max() if len(binary_series) > 0 else 0


def _freq_unit(freq: str) -> str:
    return {"1d": "天", "1wk": "週", "1mo": "月"}.get(freq, "期")


# ============================================================================
# 輸出格式化
# ============================================================================

def format_markdown(result: Dict) -> str:
    """格式化為 Markdown 報告"""
    t = result["transmission"]
    ll = t["best_lead_lag"]
    rc = t["rolling_corr"]
    rg = t["regime"]
    sb = t["score_breakdown"]

    lines = [
        f"## 白金（{result['pair']['platinum']}）→ 巴西股市（{result['pair']['brazil_equities']}）傳導分析",
        "",
        f"**分析日期**: {result['as_of']}",
        f"**分析區間**: {result['period']['start']} ~ {result['period']['end']}（{result['period']['frequency']}，{result['period']['data_points']} 筆資料）",
        "",
        "---",
        "",
        "### TL;DR",
        "",
        result["interpretation"],
        "",
        "---",
        "",
        f"### 傳導強度分數：{t['transmission_strength_score_0_100']}/100",
        "",
        "| 維度 | 分數 | 權重 | 加權貢獻 |",
        "|------|------|------|----------|",
        f"| 最佳相關 | {sb['raw']['s_corr']} | 30% | {sb['best_corr_component']} |",
        f"| Rolling 穩定性 | {sb['raw']['s_stability']} | 30% | {sb['rolling_stability_component']} |",
        f"| 趨勢一致性 | {sb['raw']['s_trend']} | 40% | {sb['trend_agreement_component']} |",
        "",
        "---",
        "",
        "### 領先落後分析",
        "",
        "| 項目 | 結果 |",
        "|------|------|",
        f"| 最佳 Lag | {ll['lag_weeks']} 週 |",
        f"| 含義 | {ll['meaning']} |",
        f"| 相關係數 | {ll['corr']} |",
        "",
        "---",
        "",
        f"### Rolling Correlation（{rc['window_weeks']} 週窗口）",
        "",
        "| 指標 | 數值 |",
        "|------|------|",
        f"| 最新值 | {rc['latest']} |",
        f"| 全期正值佔比 | {rc['positive_share_full']:.1%} |",
        f"| 近 5 年正值佔比 | {rc['positive_share_5y']:.1%} |",
        f"| 最長連續正值 | {rc['max_consecutive_positive_weeks']} 週 |",
        f"| 最長連續負值 | {rc['max_consecutive_negative_weeks']} 週 |",
        "",
        "---",
        "",
        f"### 當前 Regime: {rg['label']}",
        "",
        f"- 趨勢一致性：{rg['trend_agreement']:.1%}",
        f"- {rg['detail']}",
        "",
        "---",
        "",
        "### 監控清單",
        "",
    ]
    for note in result["monitoring_notes"]:
        lines.append(f"- {note}")

    lines.extend([
        "",
        "---",
        "",
        "### 資料限制",
        "",
    ])
    for lim in result["data_limitations"]:
        lines.append(f"- {lim}")

    return "\n".join(lines)


# ============================================================================
# CLI
# ============================================================================

def main():
    parser = argparse.ArgumentParser(description="Platinum → Brazil Equities Transmission Analysis")
    parser.add_argument("--start", required=True, help="Start date (YYYY-MM-DD)")
    parser.add_argument("--end", default=None, help="End date (YYYY-MM-DD)")
    parser.add_argument("--freq", default="1wk", choices=["1d", "1wk", "1mo"])
    parser.add_argument("--platinum", default="PL=F")
    parser.add_argument("--brazil", default="EWZ")
    parser.add_argument("--corr-window", type=int, default=DEFAULT_CORR_WINDOW)
    parser.add_argument("--lead-lag-max", type=int, default=DEFAULT_LEAD_LAG_MAX)
    parser.add_argument("--regime-window", type=int, default=DEFAULT_REGIME_WINDOW)
    parser.add_argument("--output-mode", default="both", choices=["json", "markdown", "both"])
    parser.add_argument("--output-dir", default=None, help="Output directory")
    parser.add_argument("--chart", action="store_true", help="Generate chart")
    parser.add_argument("--force-refresh", action="store_true")
    args = parser.parse_args()

    # 執行分析
    result = run_analysis(
        start=args.start,
        end=args.end,
        freq=args.freq,
        platinum_ticker=args.platinum,
        brazil_ticker=args.brazil,
        corr_window=args.corr_window,
        lead_lag_max=args.lead_lag_max,
        regime_window=args.regime_window,
        force_refresh=args.force_refresh,
    )

    if result.get("status") == "error":
        print(f"[Error] {result.get('message')}")
        sys.exit(1)

    # 輸出
    output_dir = Path(args.output_dir) if args.output_dir else OUTPUT_DIR
    output_dir.mkdir(parents=True, exist_ok=True)

    date_str = result["as_of"]

    if args.output_mode in ("json", "both"):
        # 移除 all_lags（太大）
        result_clean = {k: v for k, v in result.items()}
        json_path = output_dir / f"platinum_ewz_analysis_{date_str}.json"
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(result_clean, f, ensure_ascii=False, indent=2, default=str)
        print(f"\n[Output] JSON: {json_path}")

    if args.output_mode in ("markdown", "both"):
        md = format_markdown(result)
        md_path = output_dir / f"platinum_ewz_analysis_{date_str}.md"
        with open(md_path, "w", encoding="utf-8") as f:
            f.write(md)
        print(f"[Output] Markdown: {md_path}")

    # 主要結果摘要
    t = result["transmission"]
    print(f"\n{'='*60}")
    print(f"Signal: {result['signal']} (Confidence: {result['confidence']})")
    print(f"Transmission Score: {t['transmission_strength_score_0_100']}/100")
    print(f"Best Lag: {t['best_lead_lag']['lag_weeks']} weeks ({t['best_lead_lag']['meaning']})")
    print(f"Best Corr: {t['best_lead_lag']['corr']}")
    print(f"Rolling Corr (latest): {t['rolling_corr']['latest']}")
    print(f"Regime: {t['regime']['label']}")
    print(f"{'='*60}")
    print(f"\n{result['interpretation']}")

    # 圖表
    if args.chart:
        try:
            from visualize import generate_chart
            chart_path = generate_chart(
                start=args.start, end=args.end, freq=args.freq,
                platinum_ticker=args.platinum, brazil_ticker=args.brazil,
                analysis_result=result,
            )
            print(f"\n[Output] Chart: {chart_path}")
        except ImportError:
            print("\n[Warning] matplotlib not installed, skipping chart generation")


if __name__ == "__main__":
    main()
