# Markdown 報告模板

```markdown
## 白金（PL=F）→ 巴西股市（EWZ）傳導分析

**分析日期**: {as_of}
**分析區間**: {start} ~ {end}（{frequency}，{data_points} 筆資料）

---

### TL;DR

{一句話結論，例如：「白金具備中度領先 EWZ 的傳導特徵，最佳領先期約 12 週，傳導強度分數 74/100。」}

---

### 傳導強度分數：{score}/100

| 維度 | 分數 | 權重 | 加權貢獻 |
|------|------|------|----------|
| 最佳相關 | {s_corr} | 30% | {w_corr} |
| Rolling 穩定性 | {s_stability} | 30% | {w_stability} |
| 趨勢一致性 | {s_trend} | 40% | {w_trend} |

---

### 領先落後分析

| 項目 | 結果 |
|------|------|
| 最佳 Lag | {lag} 週 |
| 含義 | {meaning} |
| 相關係數 | {corr} |

---

### Rolling Correlation（{corr_window} 週窗口）

| 指標 | 數值 |
|------|------|
| 最新值 | {latest} |
| 全期正值佔比 | {positive_share_full} |
| 近 5 年正值佔比 | {positive_share_5y} |
| 最長連續正值 | {max_pos} 週 |
| 最長連續負值 | {max_neg} 週 |

---

### 當前 Regime

**Label**: {regime_label}
**趨勢一致性**: {trend_agreement}
**說明**: {regime_detail}

---

### 傳導結論

{基於三維度綜合判斷的結論段落}

---

### 監控清單（非短線）

- {monitoring_note_1}
- {monitoring_note_2}
- {monitoring_note_3}

---

### 替代解釋

- 巴西股市受政治風險、匯率（BRL）、大宗商品結構等多重因素影響
- 白金與 EWZ 可能由共同的第三因素驅動（如全球風險偏好、美元走勢）
- 交叉相關只顯示統計關聯，不代表白金「驅動」巴西股市

---

### 資料限制

- EWZ 以美元計價，受 BRL/USD 匯率影響
- 白金期貨（PL=F）在合約展延日可能出現價格跳動
- Inner join 對齊可能丟失少量交易日資料
- {frequency} 頻率下，領先落後精度為 1 個 {frequency} 單位

---

### 圖表

![白金 vs EWZ 傳導分析](output/platinum_vs_ewz_{date}.png)
```

## 使用方式

腳本根據分析結果填入 `{}` 佔位符，生成完整報告。

### Signal 對應 TL;DR 模板

| signal | TL;DR 模板 |
|--------|-----------|
| `transmission_strong` | 「白金具備高度領先 EWZ 的傳導特徵，最佳領先期約 {lag} 週，傳導強度分數 {score}/100。」 |
| `transmission_moderate` | 「白金具備中度領先 EWZ 的傳導特徵，但關聯具有 regime 依賴性。」 |
| `transmission_weak` | 「白金與 EWZ 的傳導關係較弱，敘事可信度偏低。」 |
| `inconclusive` | 「數據不足以判斷白金與 EWZ 的傳導關係。」 |
