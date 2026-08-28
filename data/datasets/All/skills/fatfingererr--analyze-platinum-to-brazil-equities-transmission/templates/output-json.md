# JSON 輸出模板

```json
{
  "skill": "analyze-platinum-to-brazil-equities-transmission",
  "as_of": "YYYY-MM-DD",
  "status": "ok | error | partial",

  "pair": {
    "platinum": "PL=F",
    "brazil_equities": "EWZ"
  },

  "period": {
    "start": "YYYY-MM-DD",
    "end": "YYYY-MM-DD",
    "frequency": "1wk",
    "data_points": 1100
  },

  "signal": "transmission_strong | transmission_moderate | transmission_weak | inconclusive",
  "confidence": "high | medium | low",

  "transmission": {
    "transmission_strength_score_0_100": 74,

    "best_lead_lag": {
      "lag_weeks": 12,
      "meaning": "Platinum leads EWZ by ~12 weeks",
      "corr": 0.52
    },

    "rolling_corr": {
      "window_weeks": 52,
      "latest": 0.41,
      "positive_share_full": 0.62,
      "positive_share_5y": 0.68,
      "max_consecutive_positive_weeks": 78,
      "max_consecutive_negative_weeks": 34
    },

    "regime": {
      "window_weeks": 104,
      "label": "linked_upcycle | decoupled | brazil_idiosyncratic",
      "trend_agreement": 0.65,
      "detail": "Regime 判斷說明"
    },

    "score_breakdown": {
      "best_corr_component": 22.3,
      "rolling_stability_component": 20.4,
      "trend_agreement_component": 26.0,
      "weights": {
        "best_corr": 0.30,
        "rolling_stability": 0.30,
        "trend_agreement": 0.40
      }
    }
  },

  "interpretation": "一句話結論",

  "monitoring_notes": [
    "若 PL=F 突破長期區間，觀察 EWZ 在 8-16 週內是否趨勢翻多",
    "要求 52 週 rolling corr 維持正值至少 26 週作為確認",
    "若白金大漲而 EWZ 不動且 corr 轉負，視為 regime break"
  ],

  "data_limitations": [
    "交叉相關只顯示統計關聯，不代表因果關係",
    "EWZ 以美元計價，受 BRL/USD 匯率影響",
    "期貨價格在展延日可能出現非市場因素的跳動"
  ],

  "artifacts": {
    "charts": [
      "output/platinum_vs_ewz_YYYY-MM-DD.png"
    ],
    "data_cache": [
      "data/cache/platinum_ewz.csv"
    ]
  }
}
```

## 欄位說明

| 欄位 | 類型 | 說明 |
|------|------|------|
| `status` | string | 執行狀態：ok / error / partial |
| `signal` | string | 傳導訊號等級 |
| `confidence` | string | 信心水準 |
| `transmission_strength_score_0_100` | int | 傳導強度分數（0-100） |
| `best_lead_lag.lag_weeks` | int | 最佳領先落後週數（正=白金領先） |
| `best_lead_lag.corr` | float | 最佳 lag 的相關係數 |
| `rolling_corr.latest` | float | 最新 rolling correlation 值 |
| `rolling_corr.positive_share_5y` | float | 近 5 年 rolling corr 正值佔比 |
| `regime.label` | string | 當前 regime 標籤 |
| `regime.trend_agreement` | float | 趨勢一致性比例 |
| `monitoring_notes` | string[] | 監控建議清單 |
| `data_limitations` | string[] | 資料限制說明 |
