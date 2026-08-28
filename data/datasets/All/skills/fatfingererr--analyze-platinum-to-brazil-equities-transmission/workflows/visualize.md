# Workflow: 視覺化圖表

<required_reading>
閱讀以下參考文件：
1. references/methodology.md - 了解圖表對應的分析邏輯
</required_reading>

<process>

## Step 1: 確認數據可用

確認已有快取數據或先執行數據抓取：

```bash
cd scripts

# 若需重新抓取
python fetch_data.py --start 2003-01-01 --freq 1wk

# 生成圖表
python visualize.py --start 2003-01-01
```

---

## Step 2: 圖表結構

Bloomberg 風格多面板佈局：

```
┌─────────────────────────────────────────────────┐
│       白金（PL=F）vs 巴西股市（EWZ）原值雙軸圖    │
│       左軸：EWZ（橙色）  右軸：Platinum（青色）   │
├─────────────────────┬───────────────────────────┤
│  正規化同軸對比圖    │  Lead-Lag Cross-Corr      │
│  （base=100）       │  條形圖                   │
├─────────────────────┴───────────────────────────┤
│       52-Week Rolling Correlation               │
│       （含零線、±0.5 參考線）                    │
└─────────────────────────────────────────────────┘
```

### 面板說明

| 位置 | 面板名稱 | 內容 |
|------|----------|------|
| 上方（跨整列） | 原值雙軸圖 | EWZ（左軸）+ Platinum（右軸），Bloomberg 深色背景 |
| 左中 | 正規化對比 | 兩者正規化至 base=100，同軸直接比較走勢 |
| 右中 | Lead-Lag | 交叉相關條形圖，標示最佳 lag 位置 |
| 下方（跨整列） | Rolling Corr | 52 週滾動相關時間序列，含正/負區域著色 |

### 配色方案

```python
COLORS = {
    "background": "#1a1a2e",
    "grid": "#2d2d44",
    "text": "#ffffff",
    "platinum": "#00bcd4",   # 青色
    "ewz": "#ff9800",        # 橙色
    "positive_corr": "#4caf50",  # 綠色（正相關）
    "negative_corr": "#f44336",  # 紅色（負相關）
    "best_lag": "#ffeb3b",   # 黃色（最佳 lag 標記）
}
```

---

## Step 3: 輸出

- **預設路徑**：`{專案根目錄}/output/platinum_vs_ewz_YYYY-MM-DD.png`
- **解析度**：150 DPI
- **尺寸**：16x12 英寸
- **格式**：PNG

---

## Step 4: 解讀指南

### 原值雙軸圖
- 觀察兩條線是否長期同向移動
- 注意分歧期（一升一降）→ 可能的 decoupled regime

### 正規化對比圖
- 起點對齊後，觀察累積報酬的差異
- 差距擴大 → 表現分化；收斂 → 回歸連動

### Lead-Lag Cross-Correlation
- 峰值在正 lag → 白金領先
- 峰值高度代表最大可解釋程度
- 多個峰值 → 關聯可能是周期性的

### Rolling Correlation
- 持續正值（綠色區域）→ 傳導結構穩定
- 頻繁穿越零線 → regime-dependent
- 持續負值 → 反向關聯或脫鉤

</process>

<success_criteria>
視覺化完成時應有：

- [ ] 四面板 Bloomberg 風格圖表
- [ ] 原值雙軸圖（左軸 EWZ、右軸 Platinum）
- [ ] 正規化同軸對比圖
- [ ] Lead-Lag Cross-Correlation 條形圖
- [ ] Rolling Correlation 時間序列圖
- [ ] 輸出 PNG 檔案至 output/ 目錄
</success_criteria>
