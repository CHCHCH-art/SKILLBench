# Quick Setup: Apple Health → OpenClaw Integration

**Goal:** Automatically pull daily weight, workout data, and steps from Apple Health into nutrition tracking system.

**Time to deploy:** 15 minutes  
**Maintenance:** Zero (fully automated)

---

## ⚡ 3-Step Setup Process

### Step 1: Create iOS Shortcut (5 minutes)

1. **Open Shortcuts app** on iPhone
2. **Create new shortcut** named "Export Health Data"
3. **Add these 5 actions:**

   **Action 1: Get Weight**
   - Add "Get Health Data"
   - Data Type: Body Mass → Latest Value → Pounds

   **Action 2: Get Steps** 
   - Add "Get Health Data"
   - Data Type: Step Count → Today → Count

   **Action 3: Get Calories**
   - Add "Get Health Data" 
   - Data Type: Active Energy Burned → Today → Kilocalories

   **Action 4: Get Workouts**
   - Add "Get Health Data"
   - Data Type: Workouts → Today

   **Action 5: Format & Save**
   - Add "Text" action with JSON template:
   ```json
   {
     "date": "2026-02-07",
     "weight_lbs": [Body Mass],
     "steps": [Step Count],
     "active_calories": [Active Energy], 
     "workouts": [Workouts]
   }
   ```
   - Add "Save to Files" → iCloud Drive/Health-Export/daily-health-export.json

4. **Test shortcut** - tap Run and grant Health permissions
5. **Set daily automation** - Automation tab → Time of Day → 8:00 AM Daily

### Step 2: Install Processing Script (5 minutes)

1. **Open Terminal**
2. **Navigate to OpenClaw workspace:**
   ```bash
   cd ~/openclaw  # or wherever your workspace is
   ```

3. **Test the health processor:**
   ```bash
   python3 health-sync/scripts/process_health_data.py --generate-report
   ```

4. **Set up daily automation:**
   ```bash
   crontab -e
   # Add this line for 8:30 AM daily processing:
   30 8 * * * cd ~/openclaw && python3 health-sync/scripts/process_health_data.py --generate-report
   ```

### Step 3: Verify Integration (5 minutes)

1. **Check data sources:**
   - Health app → Body Measurements → verify RENPHO weight data
   - Health app → Activity → verify Fitbod workouts

2. **Test manual run:**
   ```bash
   python3 health-sync/scripts/process_health_data.py --generate-report
   ```

3. **Check output:**
   - Daily reports in: `health-sync/reports/YYYY-MM-DD.md`
   - Health history in: `health-sync/data/health_history.json`

---

## 🎯 What You Get

### Daily Automated Reports
```markdown
# Daily Health Report - 2026-02-07

## 📊 Health Metrics (Auto-synced from Apple Health)
- **Weight:** 185.2 lbs
- **Steps:** 8,450  
- **Active Calories:** 520 cal

## 🏋️ Workouts
- **Strength Training:** 45 min, 220 cal

## 🍽️ Nutrition Tracking
### Meals (Manual Entry)
- **Breakfast:** [Fill in your meals]
- **Lunch:** 
- **Dinner:** 
```

### Coaching Insights (After 7+ days)
```
🎯 Coaching Insights

✅ **Weight:** Healthy weight loss rate (1.2 lbs/week).
   Action: Continue current approach

🚨 **Activity:** Low daily activity (6,200 steps).
   Action: Add 10-15 minute walks between meals

ℹ️ **Recovery:** Long workout session today (65 minutes).
   Action: Focus on post-workout nutrition and hydration
```

---

## 📱 Data Flow

```
RENPHO Scale → Apple Health ← Fitbod Workouts
     ↓              ↓               ↓
Apple Watch → Apple Health ← iPhone Steps  
     ↓
iOS Shortcuts (8:00 AM daily)
     ↓  
iCloud Drive/Health-Export/
     ↓
Python Processing (8:30 AM daily) 
     ↓
Daily Reports + Nutrition Integration
```

---

## 🔧 Troubleshooting

**No health data in reports:**
- Check Health app has recent data from RENPHO/Fitbod
- Verify iOS Shortcuts permissions granted
- Run shortcut manually to test

**Script errors:**
- Ensure Python 3 installed: `python3 --version`
- Check workspace path in cron job
- Verify file permissions on iCloud folder

**Missing workouts:**
- Complete workout in Fitbod app
- Check if appears in Health app → Activity
- Re-run shortcut after workout

**No weight data:**
- RENPHO app → Settings → Apple Health → Enable sync
- Weigh yourself and check Health app updates
- Wait 5-10 minutes for Bluetooth sync

---

## 🚀 Advanced Features

### Weekly Trend Analysis
After 7+ days of data, the system automatically detects:
- Weight loss/gain trends and rates
- Workout frequency patterns  
- Activity level consistency
- Coaching recommendations

### Integration with Existing Nutrition System
- Reports include manual food entry sections
- Links to existing food database in `nutrition/food-database.md`
- Combines health metrics with nutrition tracking

### Extensible Design
- Easy to add more HealthKit data (sleep, heart rate, etc.)
- Modular processing for custom insights
- JSON export format for integration with other tools

---

## ✅ Success Checklist

**After setup, you should have:**
- ✅ iOS Shortcut running daily at 8 AM
- ✅ Health data exporting to iCloud automatically  
- ✅ Daily reports generating in `health-sync/reports/`
- ✅ Weight, steps, and workout data from Apple Health
- ✅ Integration with nutrition tracking workflow

**Daily workflow:**
1. **8:00 AM:** iOS automatically exports health data
2. **8:30 AM:** OpenClaw processes data and generates report
3. **Morning:** Review daily report with health + nutrition insights
4. **Throughout day:** Add meals to nutrition section manually

---

**Total setup time: 15 minutes**  
**Result: Automated health + nutrition coaching system**

*Next: Add your meals to today's report and start tracking!* 🎉