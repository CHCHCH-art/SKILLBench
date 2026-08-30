# Health Coaching Algorithms

How OpenClaw generates personalized health insights and recommendations based on your data patterns.

## Weight Management

### Trend Analysis
- **7-day moving average** to smooth daily fluctuations
- **Weekly rate calculation** to identify sustainable vs rapid changes
- **Pattern recognition** for plateaus, consistent loss/gain, or volatility

### Coaching Rules
```
IF weekly_rate > 2.5 lbs:
  → WARNING: "Rapid weight loss. Consider slowing to 1-2 lbs/week"
  → ACTION: "Increase caloric intake by 100-200 calories/day"

IF weekly_rate < -2.5 lbs:
  → WARNING: "Rapid weight gain. Monitor portion sizes and activity"
  → ACTION: "Reduce caloric intake or increase daily activity"

IF weekly_rate between 1-2 lbs loss:
  → POSITIVE: "Healthy weight loss rate"
  → ACTION: "Continue current approach"

IF plateau (< 0.5 lb change) for 14+ days:
  → INFO: "Weight plateau detected"
  → ACTION: "Consider adjusting calories or workout intensity"
```

## Activity & Exercise

### Step Goals
- **Base goal:** 8,000 steps/day (adjustable)
- **Trend tracking:** 7-day average vs goal
- **Streak tracking:** Consecutive days meeting goal

### Workout Frequency
```
IF workouts >= 4 per week:
  → POSITIVE: "Excellent workout consistency" 
  → ACTION: "Focus on recovery and nutrition"

IF workouts 2-3 per week:
  → INFO: "Good workout frequency"
  → ACTION: "Consider adding one more session"

IF workouts < 2 per week:
  → WARNING: "Low workout frequency"
  → ACTION: "Schedule 2-3 sessions this week"

IF rest_days = 0 for 7+ days:
  → WARNING: "No rest days detected"
  → ACTION: "Schedule recovery days to prevent overtraining"
```

## Recovery Indicators

### Workout Duration
```
IF single_workout > 90 minutes:
  → INFO: "Long workout session"
  → ACTION: "Focus on post-workout nutrition and hydration"

IF daily_workouts > 2:
  → WARNING: "Multiple workouts in one day"
  → ACTION: "Monitor energy levels and consider rest"
```

### Activity Patterns
```
IF steps_today < (avg_steps * 0.5):
  → INFO: "Low activity day"
  → ACTION: "Add 10-15 minute walks between meals"

IF active_calories < 300 for 3+ days:
  → WARNING: "Consistently low calorie burn"
  → ACTION: "Increase daily movement or add structured exercise"
```

## Heart Rate Analysis (if available)

### Resting Heart Rate
```
IF resting_hr increasing for 3+ days:
  → WARNING: "Rising resting heart rate"
  → ACTION: "Monitor stress levels and ensure adequate sleep"

IF resting_hr < personal_baseline - 5:
  → POSITIVE: "Improving cardiovascular fitness"
  → ACTION: "Continue current training approach"
```

### Workout Intensity
```
IF max_hr > 90% predicted_max for 30+ minutes:
  → WARNING: "Very high intensity workout"
  → ACTION: "Allow extra recovery time"

IF avg_hr < 60% predicted_max during "workout":
  → INFO: "Low intensity session"
  → ACTION: "Good for recovery days"
```

## Sleep Integration (if available)

### Sleep Duration
```
IF avg_sleep < 6 hours for 3+ days:
  → WARNING: "Insufficient sleep"
  → ACTION: "Prioritize 7-9 hours sleep for recovery"

IF sleep_quality < 70% for 5+ days:
  → INFO: "Poor sleep quality trend"
  → ACTION: "Review sleep hygiene and stress levels"
```

## Nutrition Correlations

### Weight vs Calorie Balance
```
IF weight_loss AND calorie_deficit < 300:
  → INFO: "Weight loss without large deficit"
  → ACTION: "Current approach sustainable"

IF weight_gain AND calorie_surplus > 500:
  → WARNING: "Large calorie surplus"
  → ACTION: "Review portion sizes and food choices"
```

### Performance vs Fuel
```
IF workout_performance declining AND low_carb_intake:
  → INFO: "Performance may be fuel-limited"
  → ACTION: "Consider pre-workout carbohydrates"
```

## Contextual Adjustments

### Seasonal Factors
- **Winter months:** Lower vitamin D, higher depression risk
- **Summer months:** Higher activity, hydration needs
- **Holidays:** Weight gain patterns, social eating

### Life Events
- **Travel days:** Disrupted patterns expected
- **Sick days:** Lower activity acceptable
- **High stress periods:** Impact on weight and sleep

## Data Quality Checks

### Missing Data Handling
```
IF missing_weight for 3+ days:
  → INFO: "No recent weight data"
  → ACTION: "Weigh yourself for trend accuracy"

IF missing_workouts but high_calories:
  → WARNING: "High calorie burn without logged workouts"
  → ACTION: "Log activities for better tracking"
```

### Outlier Detection
- **Weight:** Changes > 3 lbs in single day (likely measurement error)
- **Steps:** < 500 or > 30,000 (phone likely not carried or counting error)
- **Calories:** Active calories > 2000 without workout (likely calculation error)

## Coaching Tone Guidelines

### Positive Reinforcement
- Celebrate consistent behaviors
- Acknowledge progress even if small
- Focus on sustainable habits

### Gentle Corrections
- Frame concerns as opportunities
- Provide specific, actionable advice
- Avoid judgmental language

### Educational Approach
- Explain the "why" behind recommendations
- Reference research when relevant
- Encourage self-awareness

---

**Algorithm Updates:** These rules are continuously refined based on user feedback and outcomes. The goal is helpful, non-judgmental coaching that promotes sustainable health habits.