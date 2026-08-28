# 資料來源

---

## 主要來源：Yahoo Finance

**存取方式**：`yfinance` Python 套件（免費、無需 API key、無速率限制）

### Ticker 對應

| 資產 | Ticker | 名稱 | 單位 | 上市日期 |
|------|--------|------|------|----------|
| 白金期貨 | `PL=F` | Platinum Futures | USD/oz | 長期可用 |
| 巴西股市 ETF | `EWZ` | iShares MSCI Brazil ETF | USD | 2000-07-10 |

### 欄位選擇

| Ticker | 欄位 | 原因 |
|--------|------|------|
| EWZ | `Adj Close` | ETF 需反映股息再投資與分割調整 |
| PL=F | `Close`（或 `Adj Close`） | 期貨無股息，兩者等價 |

### 頻率

| 參數值 | yfinance 等效 | 說明 |
|--------|---------------|------|
| `1d` | `1d` | 日頻（每個交易日） |
| `1wk` | `1wk` | 週頻（每週五收盤） |
| `1mo` | `1mo` | 月頻（每月最後交易日） |

### 數據品質注意事項

1. **EWZ 早期流動性較低**：2000-2002 年成交量偏低，價格可能不穩定
2. **PL=F 合約展延**：期貨在展延日可能出現價格跳動
3. **假日差異**：白金（NYMEX）與 EWZ（NYSE）交易日不完全重疊

---

## 備援來源

### Trading Economics（白金現貨）

| 項目 | 說明 |
|------|------|
| URL | `https://tradingeconomics.com/commodity/platinum` |
| 存取方式 | Chrome CDP 爬取 Highcharts 數據 |
| 頻率 | 日頻（1Y）/ 週頻（5Y） |
| 限制 | 免費版最多 5 年歷史 |

適用場景：需要現貨價格而非期貨價格時。

### FRED（間接指標）

FRED 沒有直接的白金或 EWZ 數據，但可取得相關宏觀指標：

| 系列代碼 | 名稱 | 用途 |
|----------|------|------|
| DEXBZUS | Brazil / U.S. Foreign Exchange Rate | 巴西匯率（BRL/USD） |
| DTWEXBGS | Trade Weighted U.S. Dollar Index | 美元指數（做 DXY 調整用） |

---

## 快取策略

| 層級 | 格式 | 有效期 | 用途 |
|------|------|--------|------|
| 原始快取 | JSON | 12 小時 | 保留原始下載數據 |
| 整理快取 | CSV | 12 小時 | `date,platinum,ewz` 三欄 |

### 快取路徑

```
data/cache/
├── platinum_ewz_raw.json    # 原始 yfinance 數據
└── platinum_ewz.csv         # 整理後對齊數據
```

### 強制更新

```bash
python fetch_data.py --start 2003-01-01 --force-refresh
```
