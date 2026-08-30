# 輸入參數定義

---

## 必要參數

| 參數 | 類型 | 說明 | 範例 |
|------|------|------|------|
| `start_date` | string (YYYY-MM-DD) | 分析起始日期 | `"2003-01-01"` |

**注意**：EWZ 上市於 2000-07-10，建議 start_date 不早於 2000-08-01。推薦使用 2003-01-01 以獲得穩定數據。

---

## 選用參數

| 參數 | 類型 | 預設值 | 說明 |
|------|------|--------|------|
| `end_date` | string (YYYY-MM-DD) | 今日 | 分析結束日期 |
| `frequency` | string | `"1wk"` | 資料頻率：`1d` / `1wk` / `1mo` |
| `platinum_ticker` | string | `"PL=F"` | 白金價格 ticker |
| `brazil_ticker` | string | `"EWZ"` | 巴西股市 proxy ticker |
| `price_field` | string | `"auto"` | 價格欄位：`auto` / `Adj Close` / `Close` |
| `normalize_base` | number | `100` | 正規化基準 |
| `corr_window` | int | `52` | Rolling correlation 視窗（frequency 單位） |
| `lead_lag_max` | int | `52` | 領先/落後最大掃描期數 |
| `regime_window` | int | `104` | 長期 regime 判斷窗口（frequency 單位） |
| `output_mode` | string | `"both"` | 輸出格式：`markdown` / `json` / `both` |

---

## 參數建議

### frequency 選擇

| 頻率 | 適用場景 | corr_window 建議 | lead_lag_max 建議 |
|------|----------|-------------------|-------------------|
| `1wk` | 長週期傳導分析（推薦） | 52（1年） | 52（1年） |
| `1mo` | 超長週期概覽 | 12（1年） | 24（2年） |
| `1d` | 短期細節觀察 | 252（1年） | 252（1年） |

### price_field = "auto" 邏輯

```python
if ticker is ETF (e.g., EWZ):
    use "Adj Close"  # 反映股息再投資
else:
    use "Adj Close" if available, else "Close"
```

### regime_window 選擇

| 值 | 等效 | 適用場景 |
|----|------|----------|
| 52 | 1 年 | 較敏感，適合觀察近期 regime 變化 |
| 104 | 2 年 | 預設，平衡敏感度與穩定性 |
| 156 | 3 年 | 更穩定，適合判斷長期結構 |
