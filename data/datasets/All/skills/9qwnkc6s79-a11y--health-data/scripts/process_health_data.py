#!/usr/bin/env python3
"""
Health Data Processor for OpenClaw Nutrition Tracking

Processes daily health data exported from iOS Shortcuts and integrates
with nutrition tracking system. Generates daily insights and coaching.

Usage: python process_health_data.py [--date YYYY-MM-DD] [--generate-report]
"""

import json
import os
import sys
import argparse
from datetime import datetime, timedelta
from pathlib import Path

class HealthDataProcessor:
    def __init__(self, workspace_path="."):
        self.workspace = Path(workspace_path)
        self.health_export_path = Path.home() / "Library/Mobile Documents/com~apple~CloudDocs/Health-Export"
        self.data_dir = self.workspace / "health-sync" / "data"
        self.reports_dir = self.workspace / "health-sync" / "reports"
        self.nutrition_dir = self.workspace / "nutrition"
        
        # Create directories
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.reports_dir.mkdir(parents=True, exist_ok=True)

    def load_daily_export(self, date_str=None):
        """Load health data from iOS Shortcuts export"""
        if date_str is None:
            date_str = datetime.now().strftime("%Y-%m-%d")
        
        # Try iCloud export location first, then sample data
        export_file = self.health_export_path / "daily-health-export.json"
        
        # Fallback to sample data for testing
        if not export_file.exists():
            sample_file = self.workspace / "health-sync" / "sample-data" / "daily-health-export.json"
            if sample_file.exists():
                export_file = sample_file
                print(f"📝 Using sample data for testing: {export_file}")
            else:
                print(f"📝 Also checked sample data location: {sample_file}")
        
        if export_file.exists():
            print(f"📱 Loading health data from iCloud export...")
            with open(export_file, 'r') as f:
                data = json.load(f)
            
            # Validate data has today's date
            if data.get('date') == date_str:
                return data
            else:
                print(f"⚠️ Export file date ({data.get('date')}) doesn't match target date ({date_str})")
                return None
        else:
            print(f"❌ Health export file not found: {export_file}")
            print("Make sure iOS Shortcuts automation is running and iCloud sync is enabled")
            return None

    def store_health_data(self, health_data):
        """Store health data in local database"""
        date_str = health_data.get('date')
        if not date_str:
            print("❌ No date in health data")
            return False
        
        # Load existing data
        data_file = self.data_dir / "health_history.json"
        if data_file.exists():
            with open(data_file, 'r') as f:
                history = json.load(f)
        else:
            history = []
        
        # Check if date already exists
        existing_entry = next((entry for entry in history if entry['date'] == date_str), None)
        
        if existing_entry:
            # Update existing entry
            existing_entry.update(health_data)
            print(f"📝 Updated health data for {date_str}")
        else:
            # Add new entry
            history.append(health_data)
            history.sort(key=lambda x: x['date'])
            print(f"✅ Added new health data for {date_str}")
        
        # Save updated history
        with open(data_file, 'w') as f:
            json.dump(history, f, indent=2)
        
        return True

    def calculate_trends(self, days=7):
        """Calculate health trends over specified period"""
        data_file = self.data_dir / "health_history.json"
        if not data_file.exists():
            return None
        
        with open(data_file, 'r') as f:
            history = json.load(f)
        
        # Get recent entries
        recent_entries = history[-days:] if len(history) >= days else history
        
        if len(recent_entries) < 2:
            return None
        
        trends = {}
        
        # Weight trend
        weights = [entry.get('weight_lbs') for entry in recent_entries if entry.get('weight_lbs')]
        if len(weights) >= 2:
            weight_change = weights[-1] - weights[0]
            daily_rate = weight_change / len(weights)
            weekly_rate = daily_rate * 7
            
            trends['weight'] = {
                'current': weights[-1],
                'change_total': weight_change,
                'change_weekly': weekly_rate,
                'trend': 'decreasing' if weekly_rate < -0.1 else 'increasing' if weekly_rate > 0.1 else 'stable'
            }
        
        # Activity trend
        daily_steps = [entry.get('steps') for entry in recent_entries if entry.get('steps')]
        if daily_steps:
            avg_steps = sum(daily_steps) / len(daily_steps)
            trends['activity'] = {
                'avg_steps': avg_steps,
                'latest_steps': daily_steps[-1],
                'meets_goal': avg_steps >= 8000
            }
        
        # Workout frequency
        workout_days = sum(1 for entry in recent_entries if entry.get('workouts'))
        trends['workouts'] = {
            'frequency': workout_days / len(recent_entries),
            'days_per_week': (workout_days / len(recent_entries)) * 7,
            'total_days': workout_days
        }
        
        return trends

    def generate_coaching_insights(self, health_data, trends):
        """Generate personalized coaching insights"""
        insights = []
        
        if trends:
            # Weight insights
            if 'weight' in trends:
                weight_trend = trends['weight']
                if weight_trend['trend'] == 'decreasing' and abs(weight_trend['change_weekly']) > 2:
                    insights.append({
                        'type': 'warning',
                        'category': 'Weight',
                        'message': f"Rapid weight loss ({abs(weight_trend['change_weekly']):.1f} lbs/week). Consider slowing to 1-2 lbs/week.",
                        'action': 'Increase caloric intake by 100-200 calories/day'
                    })
                elif weight_trend['trend'] == 'decreasing':
                    insights.append({
                        'type': 'positive', 
                        'category': 'Weight',
                        'message': f"Healthy weight loss rate ({abs(weight_trend['change_weekly']):.1f} lbs/week).",
                        'action': 'Continue current approach'
                    })
                elif weight_trend['trend'] == 'increasing':
                    insights.append({
                        'type': 'alert',
                        'category': 'Weight', 
                        'message': f"Weight increasing ({weight_trend['change_weekly']:.1f} lbs/week).",
                        'action': 'Review caloric intake and portion sizes'
                    })
            
            # Activity insights  
            if 'activity' in trends:
                activity = trends['activity']
                if activity['latest_steps'] < 6000:
                    insights.append({
                        'type': 'alert',
                        'category': 'Activity',
                        'message': f"Low daily activity ({activity['latest_steps']:,} steps).",
                        'action': 'Add 10-15 minute walks between meals'
                    })
                elif activity['latest_steps'] >= 10000:
                    insights.append({
                        'type': 'positive',
                        'category': 'Activity', 
                        'message': f"Excellent daily activity ({activity['latest_steps']:,} steps)!",
                        'action': 'Keep up the great work'
                    })
            
            # Workout insights
            if 'workouts' in trends:
                workout_freq = trends['workouts']['frequency']
                if workout_freq < 0.4:  # Less than 40% of days
                    insights.append({
                        'type': 'alert',
                        'category': 'Exercise',
                        'message': f"Low workout frequency ({workout_freq:.0%} of days).",
                        'action': 'Schedule 3-4 workout sessions per week'
                    })
        
        # Daily workout feedback
        workouts = health_data.get('workouts', [])
        if workouts:
            total_workout_time = sum(w.get('duration', 0) for w in workouts) / 60  # Convert to minutes
            if total_workout_time > 60:
                insights.append({
                    'type': 'info',
                    'category': 'Recovery',
                    'message': f"Long workout session today ({total_workout_time:.0f} minutes).",
                    'action': 'Focus on post-workout nutrition and hydration'
                })
        
        return insights

    def create_daily_report(self, date_str=None):
        """Create comprehensive daily health and nutrition report"""
        if date_str is None:
            date_str = datetime.now().strftime("%Y-%m-%d")
        
        print(f"📊 Generating daily report for {date_str}...")
        
        # Load health data
        health_data = self.load_daily_export(date_str)
        if not health_data:
            return None
        
        # Store in database
        self.store_health_data(health_data)
        
        # Calculate trends
        trends = self.calculate_trends()
        
        # Generate insights
        insights = self.generate_coaching_insights(health_data, trends)
        
        # Create report content
        report = self.format_daily_report(date_str, health_data, trends, insights)
        
        # Save report
        report_file = self.reports_dir / f"{date_str}.md"
        with open(report_file, 'w') as f:
            f.write(report)
        
        print(f"✅ Daily report saved: {report_file}")
        return report

    def format_daily_report(self, date_str, health_data, trends, insights):
        """Format daily report as markdown"""
        
        report = f"""# Daily Health Report - {date_str}

## 📊 Health Metrics (Auto-synced from Apple Health)

"""
        
        # Current day metrics
        weight = health_data.get('weight_lbs')
        if weight:
            weight_change = ""
            if trends and 'weight' in trends:
                change = trends['weight']['change_total'] / 7  # Daily average
                if change > 0.1:
                    weight_change = f" (↑ +{change:.1f} lbs trend)"
                elif change < -0.1:
                    weight_change = f" (↓ {change:.1f} lbs trend)"
            report += f"- **Weight:** {weight:.1f} lbs{weight_change}\n"
        
        steps = health_data.get('steps')
        if steps:
            report += f"- **Steps:** {steps:,}\n"
        
        calories = health_data.get('active_calories')
        if calories:
            report += f"- **Active Calories:** {calories:.0f} cal\n"
        
        # Workouts
        workouts = health_data.get('workouts', [])
        if workouts:
            report += f"\n## 🏋️ Workouts\n\n"
            total_duration = 0
            total_calories = 0
            
            for workout in workouts:
                name = workout.get('name', 'Unknown Exercise')
                duration = workout.get('duration', 0) / 60  # Convert to minutes
                workout_calories = workout.get('totalEnergyBurned', 0)
                
                total_duration += duration
                total_calories += workout_calories
                
                report += f"- **{name}:** {duration:.0f} min, {workout_calories:.0f} cal\n"
            
            report += f"\n**Total:** {total_duration:.0f} minutes, {total_calories:.0f} calories\n"
        else:
            report += f"\n## 🏋️ Workouts\n\nNo workouts recorded today.\n"
        
        # Coaching insights
        if insights:
            report += f"\n## 🎯 Coaching Insights\n\n"
            
            for insight in insights:
                emoji = {
                    'positive': '✅',
                    'info': 'ℹ️',
                    'warning': '⚠️',
                    'alert': '🚨'
                }.get(insight['type'], 'ℹ️')
                
                report += f"{emoji} **{insight['category']}:** {insight['message']}\n"
                report += f"   *Action:* {insight['action']}\n\n"
        
        # Food tracking section (manual entry)
        report += f"""
## 🍽️ Nutrition Tracking

### Meals (Manual Entry)
- **Breakfast:** 
- **Lunch:** 
- **Dinner:** 
- **Snacks:** 

### Daily Targets
- **Protein:** ___ g
- **Calories:** ___ cal
- **Carbs:** ___ g
- **Fat:** ___ g

---
*Health data auto-synced from Apple Health via iOS Shortcuts*
"""
        
        return report

def main():
    parser = argparse.ArgumentParser(description="Process Apple Health data for nutrition tracking")
    parser.add_argument("--date", help="Date to process (YYYY-MM-DD)")
    parser.add_argument("--generate-report", action="store_true", help="Generate daily report")
    parser.add_argument("--sync", action="store_true", help="Sync data from export")
    
    args = parser.parse_args()
    
    processor = HealthDataProcessor()
    
    # Default action if no arguments provided
    if not any([args.generate_report, args.sync]):
        args.generate_report = True
    
    if args.generate_report:
        report = processor.create_daily_report(args.date)
        if report:
            print("📋 Daily report generated successfully")
        else:
            print("❌ Could not generate report - check health data export")

if __name__ == "__main__":
    main()