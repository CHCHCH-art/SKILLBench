## 1. 數據預處理

### 1.1 頻率重採樣

```python
# 日頻 → 週頻重採樣
rule = {"1wk": "W-FRI", "1mo": "ME"}[frequency]
series = series.resample(rule).last().dropna()
```

**為何用 W-FRI**：週五收盤價最能反映一週的市場定價。

### 1.2 對齊

```python
prices = pd.concat([platinum, ewz], axis=1).dropna()  # inner join
```

**為何用 inner join**：白金期貨與 EWZ 的交易日不完全重疊（如巴西假日），使用 ffill 或 interpolate 會引入假訊號。

### 1.3 價格欄位選擇

| Ticker | 欄位選擇              | 原因                 |
|--------|-----------------------|----------------------|
| EWZ    | Adj Close             | ETF 需反映股息再投資 |
| PL=F   | Close（或 Adj Close） | 期貨無股息，兩者等價 |

---

## 2. 正規化

```
P_norm(t) = P(t) / P(0) × normalize_base
```

其中 P(0) 為序列第一個有效值，normalize_base 預設 100。

正規化使不同量級的資產（白金 ~$1000/oz vs EWZ ~$30）可在同軸比較。

---

## 3. Log Return

```
r(t) = ln(P(t)) - ln(P(t-1)) = ln(P(t) / P(t-1))
```

使用 log return 而非 simple return 的原因：
- 時間可加性：多期 log return 可直接相加
- 統計特性更好：更接近常態分佈
- 與百分比變化在小幅變動時近似

---

## 4. Rolling Correlation

```
ρ_rolling(t) = corr(r_platinum[t-w+1:t], r_ewz[t-w+1:t])
```

其中 w = corr_window（預設 52 週 ≈ 1 年）。

### 解讀

| ρ 值       | 含義       | 傳導意涵     |
|------------|------------|--------------|
| > 0.5      | 強正相關   | 傳導結構穩固 |
| 0.2 ~ 0.5  | 中等正相關 | 有關聯但不強 |
| -0.2 ~ 0.2 | 接近零     | 無明顯關聯   |
| < -0.2     | 負相關     | 反向或脫鉤   |

### Stability 指標

```
rolling_corr_stability = count(ρ > 0) / total_count
```

stability ≥ 0.6 表示「多數時間正相關」，為傳導穩定性的基本門檻。

---

## 5. Lead-Lag Cross-Correlation

### 公式

```
CC(lag) = corr(r_ewz(t), r_platinum(t - lag))
```

掃描範圍：lag ∈ [-lead_lag_max, +lead_lag_max]

### 最佳 Lag

```
best_lag = argmax_{lag} |CC(lag)|
best_corr = CC(best_lag)
```

### 解讀規則

| best_lag | 含義                           |
|----------|--------------------------------|
| > 0      | 白金領先 EWZ（platinum leads） |
| = 0      | 同步移動                       |
| < 0      | EWZ 領先白金                   |

### 合理範圍

對於商品→新興市場股市的傳導，合理的領先期為 4-26 週（1-6 個月）。

---

## 6. Regime 判斷

### 趨勢一致性

在 regime_window（預設 104 週 ≈ 2 年）內計算：

```python
# 方法一：均線斜率同向比例
ma_platinum = platinum.rolling(26).mean()
ma_ewz = ewz.rolling(26).mean()

slope_platinum = ma_platinum.diff()
slope_ewz = ma_ewz.diff()

# 兩者斜率符號相同的比例
trend_agreement = (np.sign(slope_platinum) == np.sign(slope_ewz)).mean()
```

### Regime Label 判定

| 條件                                             | Label                  | 含義                   |
|--------------------------------------------------|------------------------|------------------------|
| trend_agreement ≥ 0.6 且 rolling_corr_latest > 0 | `linked_upcycle`       | 連動上行（或下行）週期 |
| trend_agreement < 0.4 或 rolling_corr_latest ≤ 0 | `decoupled`            | 脫鉤                   |
| rolling_corr_latest < -0.2 且 EWZ 累積報酬 < 0   | `brazil_idiosyncratic` | 巴西特有風險主導       |

---

## 7. 傳導強度分數（Transmission Strength Score）

### 三維度加權

```
score = w1 × S_corr + w2 × S_stability + w3 × S_trend
```

| 維度           | 符號        | 權重 | 計算方式                     |
|----------------|-------------|------|------------------------------|
| 最佳相關       | S_corr      | 30%  | min(                         |
| Rolling 穩定性 | S_stability | 30%  | rolling_corr_stability × 100 |
| 趨勢一致性     | S_trend     | 40%  | trend_agreement × 100        |

### 分數解讀

| 分數區間 | 等級     | 含義                             |
|----------|----------|----------------------------------|
| ≥ 70     | 強傳導   | 白金對 EWZ 有穩定的領先/連動關係 |
| 50-69    | 中等傳導 | 存在關聯但有 regime 依賴性       |
| < 50     | 弱傳導   | 關聯不穩定，敘事可信度低         |

---

## 8. 傳導結論模板

### 傳導成立

條件：best lag > 0 且 |corr| ≥ 0.35 且 rolling corr 正值佔比 ≥ 0.5

> 「白金具備中度/高度領先 EWZ 的傳導特徵，最佳領先期約 {lag} 週，
> 52 週 rolling correlation 有 {pct}% 時間為正。當前處於 {regime} 體制。」

### 傳導不穩定

條件：lag 不穩定或 rolling corr 多數時間接近 0 / 負

> 「白金與 EWZ 的關聯具 regime-dependent 性質，需警惕敘事失效。
> Rolling correlation 正值佔比僅 {pct}%，當前處於 {regime} 體制。」

### 傳導不成立

條件：|best_corr| < 0.2 或 best_lag < 0

> 「數據不支持白金領先 EWZ 的敘事。最佳 lag = {lag}（{meaning}），
> 相關係數僅 {corr}。建議探索其他傳導路徑或驅動因素。」
