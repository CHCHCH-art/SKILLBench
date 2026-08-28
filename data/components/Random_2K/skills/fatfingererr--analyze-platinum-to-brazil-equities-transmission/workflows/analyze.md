# Workflow: 完整傳導分析

<required_reading>
閱讀以下參考文件：
1. references/methodology.md - 傳導分析方法論
2. references/data-sources.md - 資料來源與替代方案
3. references/input-schema.md - 完整輸入參數定義
</required_reading>

<process>

## Step 1: 數據取得

使用 Yahoo Finance 取得白金期貨與巴西股市 ETF 的歷史價格。

```bash
cd scripts
python fetch_data.py --start 2003-01-01 --freq 1wk
```

腳本會自動：
1. 下載 PL=F（白金期貨）與 EWZ（巴西股市 ETF）的歷史價格
2. 依 frequency 參數重採樣（週頻：W-FRI 取 last）
3. 使用 inner join 對齊（只保留共同交易日）
4. 存入 `data/cache/` 快取

### 數據品質確認

- [ ] 兩序列時間範圍一致
- [ ] 無大量連續缺值（超過 4 週）
- [ ] 價格序列無負值或零值

---

## Step 2: 數據處理與分析

```bash
python analyze.py --start 2003-01-01 --freq 1wk --output-mode both
```

### 2.1 生成衍生數據

| 數據 | 計算方式 | 用途 |
|------|----------|------|
| 原值 | 原始收盤價 | 雙軸圖 |
| 正規化 | P / P[0] × normalize_base | 同軸對比 |
| Log Return | ln(P).diff() | 相關分析 |
| Rolling Corr | corr(r_pl, r_ewz, window=52) | 時變關聯 |

### 2.2 領先落後分析

掃描 [-52, +52] 週的 lag：
```
corr(r_ewz, r_platinum.shift(lag))
```

找 |corr| 最大的 lag：
- lag > 0：白金領先 EWZ
- lag < 0：EWZ 領先白金
- lag ≈ 0：同步移動

### 2.3 Regime 判斷

在 regime_window（預設 104 週）內估計趨勢一致性：

```
trend_agreement = 均線斜率同向比例
```

| trend_agreement | Regime Label |
|-----------------|--------------|
| ≥ 0.6 且 corr > 0 | linked_upcycle |
| < 0.4 或 corr < 0 | decoupled |
| corr < -0.2 且 EWZ 下跌 | brazil_idiosyncratic |

### 2.4 傳導強度分數

```
score = best_corr × 30 + rolling_stability × 30 + trend_agreement × 40
```

其中：
- `best_corr`：最佳 lag 的 |corr|，映射到 0-100
- `rolling_stability`：rolling corr > 0 的佔比 × 100
- `trend_agreement`：趨勢同向比例 × 100

---

## Step 3: 生成報告

根據 output_mode 生成對應格式：

### Markdown 報告（output_mode = markdown / both）

參照 `templates/output-markdown.md` 模板：
1. **TL;DR**：一句話結論
2. **量化證據**：lead-lag、rolling corr、score、regime
3. **傳導結論**：基於三維度綜合判斷
4. **監控清單**：非短線追蹤建議
5. **資料限制**：假設與注意事項

### JSON 報告（output_mode = json / both）

參照 `templates/output-json.md` 模板。

---

## Step 4: 視覺化（可選）

```bash
python visualize.py --start 2003-01-01
```

生成 Bloomberg 風格多面板圖表，包含：
1. 原值雙軸圖（左軸 EWZ、右軸 Platinum）
2. 正規化同軸對比圖
3. Rolling Correlation 時間序列
4. Lead-Lag Cross-Correlation 條形圖

輸出到：`output/platinum_vs_ewz_YYYY-MM-DD.png`

---

## Step 5: 傳導結論判讀

### 傳導成立條件

若以下三個條件同時滿足：
1. best lag > 0（白金領先）
2. |corr| ≥ 0.35（關聯達門檻）
3. rolling corr 正值佔比 ≥ 0.5（長期偏正）

→ 「白金具備中度/高度領先 EWZ 的傳導特徵」

### 傳導不穩定

若 lag 不穩定或 rolling corr 多數時間接近 0 / 負：

→ 「關聯具 regime-dependent 性質，需警惕敘事失效」

### 監控清單輸出

根據分析結果自動生成：
- 白金突破長期區間後 X–Y 週內，EWZ 是否趨勢翻多
- Rolling corr 是否由負轉正並維持至少 N 週
- 若白金大漲而 EWZ 不動且 corr 轉負 → 可能為巴西特有風險主導

</process>

<success_criteria>
完整分析完成時應有：

- [ ] 白金與 EWZ 的歷史價格數據（inner join 對齊）
- [ ] 最佳領先落後週數與相關係數
- [ ] 52 週 Rolling Correlation 最新值與正值佔比
- [ ] 傳導強度分數（0-100）
- [ ] 當前 Regime Label
- [ ] 傳導結論（成立/不穩定/不成立）
- [ ] 監控清單
- [ ] JSON 與/或 Markdown 報告
- [ ] Bloomberg 風格圖表（可選）
</success_criteria>

<troubleshooting>

### yfinance 下載失敗

**問題**：`No data found for ticker PL=F`

**解決**：
1. 檢查網路連線
2. 確認 ticker 名稱正確（白金期貨在 Yahoo Finance 為 `PL=F`）
3. 嘗試更短的時間範圍

### 數據不足

**問題**：rolling correlation 視窗不夠

**解決**：
1. 確保 start_date 足夠早（建議至少比 corr_window 多 2 倍）
2. 降低 corr_window 參數（如 26 週）

### EWZ 上市日限制

**問題**：EWZ 上市於 2000-07-10

**解決**：
1. start_date 不要早於 2000-08-01
2. 建議使用 2003-01-01 以獲得穩定數據

</troubleshooting>
