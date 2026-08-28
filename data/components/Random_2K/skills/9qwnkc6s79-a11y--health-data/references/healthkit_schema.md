# HealthKit Data Types Research

## Target Health Metrics

### 1. Daily Weight (from RENPHO scale)
**HealthKit Type:** `HKQuantityTypeIdentifier.bodyMass`
- **Unit:** Pounds (lbs) or Kilograms (kg)
- **Frequency:** Daily (when user weighs in)
- **iOS Shortcuts Access:** ✅ "Get Health Data" → Body Mass
- **Typical Value:** 150.0-250.0 lbs

### 2. Workout Data (from Fitbod)
**HealthKit Type:** `HKWorkout` 
- **Data Available:**
  - Workout type (Strength Training, Cardio, etc.)
  - Start/end time and duration
  - Calories burned
  - Source app (Fitbod)
- **iOS Shortcuts Access:** ✅ "Get Health Data" → Workouts
- **Frequency:** Per workout session

### 3. Daily Steps
**HealthKit Type:** `HKQuantityTypeIdentifier.stepCount`
- **Unit:** Count (steps)
- **Frequency:** Continuous throughout day
- **iOS Shortcuts Access:** ✅ "Get Health Data" → Step Count
- **Aggregation:** Can get daily totals

### 4. Additional Useful Metrics

**Active Energy Burned:**
- **Type:** `HKQuantityTypeIdentifier.activeEnergyBurned`
- **Unit:** Kilocalories (kcal)
- **Good for:** Daily calorie burn tracking

**Resting Heart Rate:**
- **Type:** `HKQuantityTypeIdentifier.restingHeartRate`  
- **Unit:** Beats per minute (BPM)
- **Good for:** Recovery and fitness trends

**Sleep Analysis:**
- **Type:** `HKCategoryTypeIdentifier.sleepAnalysis`
- **Data:** Sleep duration and quality
- **Good for:** Recovery tracking

---

## iOS Shortcuts Data Access

### Available Actions:
1. **"Get Health Data"** - Query any HealthKit data type
2. **"Get My Shortcuts"** - Can trigger other shortcuts
3. **"Save to Files"** - Export data to iCloud/Files app
4. **"Get Contents of URL"** - Can send data to web services

### Query Options:
- **Time Range:** Today, Yesterday, Last 7 days, Last 30 days
- **Sort:** Most recent, oldest first
- **Limit:** Number of results to return
- **Specific Date:** Can query exact date ranges

### Export Formats:
- **JSON:** Best for structured data
- **CSV:** Good for spreadsheet import  
- **Plain Text:** Simple but less structured

---

## Sample iOS Shortcut Workflow

```
1. Get Health Data (Body Mass, Latest Value)
   ↓
2. Get Health Data (Step Count, Today)
   ↓  
3. Get Health Data (Workouts, Today)
   ↓
4. Get Health Data (Active Energy, Today)
   ↓
5. Format as JSON Text:
   {
     "date": "[Current Date]",
     "weight_lbs": "[Body Mass]",
     "steps": "[Step Count]", 
     "active_calories": "[Active Energy]",
     "workouts": "[Workouts]"
   }
   ↓
6. Save to Files (iCloud/health-export.json)
```

**Automation Trigger Options:**
- **Time of Day:** Daily at specific time (8 AM)
- **App Launch:** When opening Health app
- **Location:** When arriving at gym/home
- **Manual:** Run from Shortcuts widget

---

## Sample Data Output

```json
{
  "date": "2026-02-07",
  "weight_lbs": 185.2,
  "steps": 8450,
  "active_calories": 520,
  "workouts": [
    {
      "type": "Strength Training",
      "duration": 45,
      "calories": 220,
      "source": "Fitbod",
      "start_time": "2026-02-07T07:00:00Z"
    }
  ],
  "resting_hr": 58,
  "sleep_hours": 7.5
}
```

## Next Steps

1. ✅ **Research complete** - iOS Shortcuts can access all needed data
2. 🔄 **Build shortcut prototype** - Create working export shortcut  
3. ⏳ **Test with real data** - Verify RENPHO/Fitbod data appears
4. ⏳ **Create processing script** - Parse exported JSON
5. ⏳ **Set up automation** - Daily export and processing