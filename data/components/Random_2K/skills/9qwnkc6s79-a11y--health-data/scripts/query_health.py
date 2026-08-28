#!/usr/bin/env python3
"""
Health Data Query Interface for OpenClaw

Provides conversational access to health data with natural language queries.
Integrates with existing health sync system.

Usage examples:
  python query_health.py --current
  python query_health.py --question "What's my weight trend this week?"
  python query_health.py --insights --days 7
"""

import json
import sys
import argparse
from datetime import datetime, timedelta
from pathlib import Path
import os

# Import the existing health data processor
sys.path.append(str(Path(__file__).parent))
from process_health_data import HealthDataProcessor

class HealthQueryInterface:
    def __init__(self, workspace_path=".."):
        self.processor = HealthDataProcessor(workspace_path)
        self.workspace = Path(workspace_path)
    
    def get_current_health(self):
        """Get today's health metrics"""
        today = datetime.now().strftime("%Y-%m-%d")
        
        try:
            # Load today's data
            data = self.processor.load_daily_export(today)
            if data:
                return self._format_current_metrics(data)
            else:
                return "No health data available for today. Check iOS Shortcuts sync."
        except Exception as e:
            return f"Error loading health data: {str(e)}"
    
    def get_health_trends(self, days=7):
        """Analyze health trends over specified days"""
        try:
            # Calculate trends using existing method
            trends = self.processor.calculate_trends(days)
            
            return self._format_trends(trends, days)
        except Exception as e:
            return f"Error analyzing trends: {str(e)}"
    
    def get_workout_summary(self, days=7):
        """Get workout summary for specified period"""
        try:
            # For now, just get today's workouts
            # TODO: Add historical workout analysis
            data = self.processor.load_daily_export()
            workouts = data.get('workouts', []) if data else []
            
            return self._format_workouts(workouts, 1)  # Just today for now
        except Exception as e:
            return f"Error loading workouts: {str(e)}"
    
    def generate_health_insights(self, days=7):
        """Generate health insights and coaching recommendations"""
        try:
            # Get current data and trends
            data = self.processor.load_daily_export()
            trends = self.processor.calculate_trends(days)
            insights = self.processor.generate_coaching_insights(data, trends)
            
            return self._format_insights(insights)
        except Exception as e:
            return f"Error generating insights: {str(e)}"
    
    def answer_health_question(self, question):
        """Answer natural language health questions"""
        question = question.lower().strip()
        
        # Weight questions
        if any(word in question for word in ['weight', 'weigh', 'pounds', 'lbs']):
            if any(word in question for word in ['today', 'current', 'now']):
                data = self.processor.load_daily_export()
                weight = data.get('weight_lbs') if data else None
                if weight:
                    return f"Your current weight is {weight:.1f} lbs."
                else:
                    return "No weight data available for today."
            
            elif any(word in question for word in ['trend', 'week', 'pattern', 'change']):
                trends = self.get_health_trends(7)
                return trends
        
        # Steps questions  
        elif any(word in question for word in ['steps', 'walked', 'walking']):
            if any(word in question for word in ['today', 'current']):
                data = self.processor.load_daily_export()
                steps = data.get('steps') if data else None
                if steps:
                    return f"You've taken {steps:,} steps today."
                else:
                    return "No step data available for today."
            
            elif any(word in question for word in ['week', 'average', 'daily']):
                return self.get_health_trends(7)
        
        # Workout questions
        elif any(word in question for word in ['workout', 'exercise', 'training', 'gym']):
            if any(word in question for word in ['today']):
                data = self.processor.load_daily_export()
                workouts = data.get('workouts', []) if data else []
                if workouts:
                    workout_names = [w.get('name', 'Unknown') for w in workouts]
                    return f"Today's workouts: {', '.join(workout_names)}"
                else:
                    return "No workouts recorded today."
            
            elif any(word in question for word in ['week', 'recent']):
                return self.get_workout_summary(7)
        
        # General health questions
        elif any(word in question for word in ['health', 'fitness', 'progress', 'insights']):
            return self.generate_health_insights(7)
        
        # Calorie questions
        elif any(word in question for word in ['calories', 'calorie', 'burned', 'energy']):
            data = self.processor.load_daily_export()
            calories = data.get('active_calories') if data else None
            if calories:
                return f"You've burned {calories:.0f} active calories today."
            else:
                return "No calorie data available for today."
        
        else:
            return "I can help with questions about weight, steps, workouts, calories, and health trends. What would you like to know?"
    
    def _format_current_metrics(self, data):
        """Format current day metrics for display"""
        lines = ["📊 Today's Health Metrics:\n"]
        
        if data.get('weight_lbs'):
            lines.append(f"• Weight: {data['weight_lbs']:.1f} lbs")
        
        if data.get('steps'):
            lines.append(f"• Steps: {data['steps']:,}")
        
        if data.get('active_calories'):
            lines.append(f"• Active Calories: {data['active_calories']:.0f}")
        
        workouts = data.get('workouts', [])
        if workouts:
            lines.append(f"• Workouts: {len(workouts)} sessions")
            for workout in workouts:
                name = workout.get('name', 'Unknown')
                duration = workout.get('duration', 0) / 60
                lines.append(f"  - {name}: {duration:.0f} min")
        
        return "\n".join(lines)
    
    def _format_trends(self, trends, days):
        """Format trend analysis for display"""
        lines = [f"📈 Health Trends ({days} days):\n"]
        
        if trends and 'weight' in trends:
            weight_trend = trends['weight']
            change = weight_trend.get('change_total', 0)
            rate = change / (days / 7)  # Per week
            
            direction = "↑" if change > 0 else "↓" if change < 0 else "→"
            lines.append(f"• Weight: {direction} {abs(change):.1f} lbs ({abs(rate):.1f} lbs/week)")
        
        if trends and 'activity' in trends:
            activity = trends['activity']
            avg_steps = activity.get('avg_steps', 0)
            lines.append(f"• Average Steps: {avg_steps:,.0f}/day")
        
        return "\n".join(lines)
    
    def _format_workouts(self, workouts, days):
        """Format workout summary for display"""
        if not workouts:
            return f"No workouts recorded in the past {days} days."
        
        lines = [f"🏋️ Workouts ({days} days): {len(workouts)} sessions\n"]
        
        total_duration = sum(w.get('duration', 0) for w in workouts) / 60
        total_calories = sum(w.get('totalEnergyBurned', 0) for w in workouts)
        
        lines.append(f"• Total Duration: {total_duration:.0f} minutes")
        lines.append(f"• Total Calories: {total_calories:.0f}")
        lines.append(f"• Frequency: {len(workouts)}/{days} days")
        
        # Group by workout type
        workout_types = {}
        for workout in workouts:
            name = workout.get('name', 'Unknown')
            if name not in workout_types:
                workout_types[name] = 0
            workout_types[name] += 1
        
        lines.append("\n• Workout Types:")
        for name, count in sorted(workout_types.items()):
            lines.append(f"  - {name}: {count}x")
        
        return "\n".join(lines)
    
    def _format_insights(self, insights):
        """Format health insights for display"""
        if not insights:
            return "No specific health insights available. Need more data history."
        
        lines = ["🎯 Health Insights:\n"]
        
        for insight in insights:
            emoji = {
                'positive': '✅',
                'info': 'ℹ️', 
                'warning': '⚠️',
                'alert': '🚨'
            }.get(insight.get('type'), 'ℹ️')
            
            category = insight.get('category', 'Health')
            message = insight.get('message', '')
            action = insight.get('action', '')
            
            lines.append(f"{emoji} **{category}:** {message}")
            if action:
                lines.append(f"   → Action: {action}")
            lines.append("")
        
        return "\n".join(lines)

def main():
    parser = argparse.ArgumentParser(description="Query health data conversationally")
    parser.add_argument("--current", action="store_true", help="Get current day metrics")
    parser.add_argument("--trends", action="store_true", help="Get health trends")
    parser.add_argument("--workouts", action="store_true", help="Get workout summary")
    parser.add_argument("--insights", action="store_true", help="Generate health insights")
    parser.add_argument("--question", help="Ask a natural language health question")
    parser.add_argument("--days", type=int, default=7, help="Days to analyze for trends/workouts")
    
    args = parser.parse_args()
    
    query = HealthQueryInterface()
    
    if args.current:
        print(query.get_current_health())
    elif args.trends:
        print(query.get_health_trends(args.days))
    elif args.workouts:
        print(query.get_workout_summary(args.days))
    elif args.insights:
        print(query.generate_health_insights(args.days))
    elif args.question:
        print(query.answer_health_question(args.question))
    else:
        print("Usage: Specify --current, --trends, --workouts, --insights, or --question")
        print("Example: python query_health.py --question 'What is my weight today?'")

if __name__ == "__main__":
    main()