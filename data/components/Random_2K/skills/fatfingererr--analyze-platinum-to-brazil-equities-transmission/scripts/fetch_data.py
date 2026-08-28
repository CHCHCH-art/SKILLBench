#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
白金→巴西股市 數據抓取工具

從 Yahoo Finance 取得白金期貨（PL=F）與巴西股市 ETF（EWZ）的歷史價格。

Usage:
    python fetch_data.py --start 2003-01-01
    python fetch_data.py --start 2003-01-01 --end 2026-01-28 --freq 1wk
    python fetch_data.py --start 2003-01-01 --force-refresh
"""

import argparse
import json
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

import pandas as pd
import numpy as np

try:
    import yfinance as yf
except ImportError:
    print("Error: yfinance not installed. Run: pip install yfinance")
    raise

# ============================================================================
# 配置
# ============================================================================

CACHE_DIR = Path(__file__).parent.parent / "data" / "cache"
CACHE_MAX_AGE_HOURS = 12

DEFAULT_PLATINUM_TICKER = "PL=F"
DEFAULT_BRAZIL_TICKER = "EWZ"

RESAMPLE_RULES = {
    "1wk": "W-FRI",
    "1mo": "ME",
}


# ============================================================================
# 數據下載
# ============================================================================

def download_series(ticker: str, start: str, end: Optional[str] = None) -> pd.Series:
    """
    從 Yahoo Finance 下載單一 ticker 的價格序列。

    Parameters
    ----------
    ticker : str
        Yahoo Finance ticker (e.g., "PL=F", "EWZ")
    start : str
        起始日期 (YYYY-MM-DD)
    end : str, optional
        結束日期 (YYYY-MM-DD)，預設今日

    Returns
    -------
    pd.Series
        價格序列（DatetimeIndex）
    """
    print(f"[Fetch] Downloading {ticker} from {start} to {end or 'today'}...")

    df = yf.download(ticker, start=start, end=end, progress=False)

    if df.empty:
        print(f"[Warning] No data returned for {ticker}")
        return pd.Series(dtype=float, name=ticker)

    # 選擇價格欄位
    # ETF (EWZ) 用 Adj Close 反映股息再投資
    # 期貨 (PL=F) 用 Close 或 Adj Close（兩者等價）
    if "Adj Close" in df.columns:
        s = df["Adj Close"]
    else:
        s = df["Close"]

    # 處理 MultiIndex columns (yfinance >= 0.2.31)
    if isinstance(s, pd.DataFrame):
        s = s.iloc[:, 0]

    s = s.rename(ticker).dropna()
    # 確保 index 是 DatetimeIndex 且無時區
    s.index = pd.to_datetime(s.index).tz_localize(None)

    print(f"[Fetch] {ticker}: {len(s)} data points, {s.index.min().date()} ~ {s.index.max().date()}")
    return s


def resample_last(s: pd.Series, freq: str) -> pd.Series:
    """
    重採樣到指定頻率（取 last）。

    Parameters
    ----------
    s : pd.Series
        日頻價格序列
    freq : str
        目標頻率："1d" / "1wk" / "1mo"
    """
    if freq == "1d":
        return s

    rule = RESAMPLE_RULES.get(freq)
    if rule is None:
        print(f"[Warning] Unknown frequency '{freq}', returning original")
        return s

    return s.resample(rule).last().dropna()


# ============================================================================
# 快取
# ============================================================================

def _cache_path(key: str) -> Path:
    return CACHE_DIR / f"{key}.csv"


def _cache_raw_path(key: str) -> Path:
    return CACHE_DIR / f"{key}_raw.json"


def is_cache_valid(key: str) -> bool:
    """檢查快取是否有效（未過期）"""
    path = _cache_path(key)
    if not path.exists():
        return False
    mtime = datetime.fromtimestamp(path.stat().st_mtime)
    return (datetime.now() - mtime) < timedelta(hours=CACHE_MAX_AGE_HOURS)


def save_cache(key: str, df: pd.DataFrame):
    """儲存整理後的數據到快取"""
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    df.to_csv(_cache_path(key))
    print(f"[Cache] Saved to {_cache_path(key)}")


def load_cache(key: str) -> Optional[pd.DataFrame]:
    """載入快取數據"""
    path = _cache_path(key)
    if not path.exists():
        return None

    df = pd.read_csv(path, index_col=0, parse_dates=True)
    print(f"[Cache] Loaded from {path} ({len(df)} rows)")
    return df


# ============================================================================
# 主函數
# ============================================================================

def fetch_aligned_data(
    start: str,
    end: Optional[str] = None,
    freq: str = "1wk",
    platinum_ticker: str = DEFAULT_PLATINUM_TICKER,
    brazil_ticker: str = DEFAULT_BRAZIL_TICKER,
    force_refresh: bool = False,
) -> pd.DataFrame:
    """
    取得對齊後的白金與巴西股市價格數據。

    Parameters
    ----------
    start : str
        起始日期 (YYYY-MM-DD)
    end : str, optional
        結束日期
    freq : str
        頻率 ("1d" / "1wk" / "1mo")
    platinum_ticker : str
        白金 ticker
    brazil_ticker : str
        巴西股市 ticker
    force_refresh : bool
        是否強制重新抓取

    Returns
    -------
    pd.DataFrame
        columns: [platinum_ticker, brazil_ticker], index: DatetimeIndex
    """
    cache_key = f"platinum_ewz_{freq}"

    # 檢查快取
    if not force_refresh and is_cache_valid(cache_key):
        cached = load_cache(cache_key)
        if cached is not None:
            return cached

    # 下載數據
    pl = download_series(platinum_ticker, start, end)
    ewz = download_series(brazil_ticker, start, end)

    if pl.empty or ewz.empty:
        print("[Error] Failed to download one or both series")
        return pd.DataFrame()

    # 重採樣
    pl = resample_last(pl, freq)
    ewz = resample_last(ewz, freq)

    # Inner join 對齊
    prices = pd.concat([pl, ewz], axis=1).dropna()
    prices.columns = [platinum_ticker, brazil_ticker]

    print(f"[Aligned] {len(prices)} aligned data points, {prices.index.min().date()} ~ {prices.index.max().date()}")

    # 儲存快取
    save_cache(cache_key, prices)

    return prices


# ============================================================================
# CLI
# ============================================================================

def main():
    parser = argparse.ArgumentParser(description="Fetch Platinum & EWZ data from Yahoo Finance")
    parser.add_argument("--start", required=True, help="Start date (YYYY-MM-DD)")
    parser.add_argument("--end", default=None, help="End date (YYYY-MM-DD)")
    parser.add_argument("--freq", default="1wk", choices=["1d", "1wk", "1mo"], help="Frequency")
    parser.add_argument("--platinum", default=DEFAULT_PLATINUM_TICKER, help="Platinum ticker")
    parser.add_argument("--brazil", default=DEFAULT_BRAZIL_TICKER, help="Brazil ticker")
    parser.add_argument("--force-refresh", action="store_true", help="Force refresh (ignore cache)")
    args = parser.parse_args()

    df = fetch_aligned_data(
        start=args.start,
        end=args.end,
        freq=args.freq,
        platinum_ticker=args.platinum,
        brazil_ticker=args.brazil,
        force_refresh=args.force_refresh,
    )

    if not df.empty:
        print(f"\nData summary:")
        print(f"  Period: {df.index.min().date()} ~ {df.index.max().date()}")
        print(f"  Points: {len(df)}")
        print(f"  {args.platinum}: {df[args.platinum].iloc[-1]:.2f} (latest)")
        print(f"  {args.brazil}: {df[args.brazil].iloc[-1]:.2f} (latest)")
    else:
        print("\nNo data available.")


if __name__ == "__main__":
    main()
