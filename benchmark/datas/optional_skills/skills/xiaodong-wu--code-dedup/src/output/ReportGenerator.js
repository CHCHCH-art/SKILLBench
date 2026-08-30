import { JSONFormatter } from './formatters/JSONFormatter.js';
import { ConsoleFormatter } from './formatters/ConsoleFormatter.js';
import { writeFile } from 'fs/promises';

/**
 * Generates analysis reports in various formats
 */
export class ReportGenerator {
  constructor(options = {}) {
    this.format = options.format || 'json';
    this.outputFile = options.outputFile || null;
    this.formatterOptions = {
      useColors: options.useColors !== false,
      verbose: options.verbose || false,
      indent: options.indent !== false ? 2 : 0
    };
  }

  /**
   * Generate report from analysis result
   * @param {Object} result - Analysis result
   * @returns {Promise<string>}
   */
  async generate(result) {
    const formatter = this._getFormatter();
    const report = formatter.format(result);

    // Write to file if specified
    if (this.outputFile) {
      await this._writeReport(report);
    }

    return report;
  }

  /**
   * Get appropriate formatter
   * @private
   */
  _getFormatter() {
    switch (this.format) {
      case 'json':
        return new JSONFormatter(this.formatterOptions);
      case 'console':
        return new ConsoleFormatter(this.formatterOptions);
      default:
        return new JSONFormatter(this.formatterOptions);
    }
  }

  /**
   * Write report to file
   * @private
   */
  async _writeReport(content) {
    try {
      await writeFile(this.outputFile, content, 'utf8');
      return true;
    } catch (error) {
      console.error(`Failed to write report to ${this.outputFile}:`, error.message);
      return false;
    }
  }

  /**
   * Generate HTML report
   * @param {Object} result - Analysis result
   * @returns {string}
   */
  generateHTML(result) {
    const html = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Code Analysis Report</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
        }
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .summary-card {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .summary-card h3 {
            margin: 0 0 10px 0;
            color: #666;
            font-size: 14px;
            text-transform: uppercase;
        }
        .summary-card .value {
            font-size: 32px;
            font-weight: bold;
            color: #333;
        }
        .section {
            background: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .section h2 {
            margin-top: 0;
            color: #333;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        .recommendation {
            padding: 15px;
            margin: 10px 0;
            border-left: 4px solid #667eea;
            background: #f8f9fa;
            border-radius: 4px;
        }
        .recommendation.high {
            border-left-color: #e53e3e;
        }
        .recommendation.medium {
            border-left-color: #dd6b20;
        }
        .recommendation.low {
            border-left-color: #38a169;
        }
        .priority-badge {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: bold;
            color: white;
            margin-right: 10px;
        }
        .priority-high { background: #e53e3e; }
        .priority-medium { background: #dd6b20; }
        .priority-low { background: #38a169; }
        .file-list {
            color: #666;
            font-size: 14px;
            margin-top: 5px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>Code Analysis Report</h1>
        <p>Generated: ${new Date().toLocaleString()}</p>
    </div>

    <div class="summary">
        <div class="summary-card">
            <h3>Files Analyzed</h3>
            <div class="value">${result.summary?.filesAnalyzed || 0}</div>
        </div>
        <div class="summary-card">
            <h3>Issues Found</h3>
            <div class="value">${result.summary?.issuesFound || 0}</div>
        </div>
        <div class="summary-card">
            <h3>Duration</h3>
            <div class="value">${((result.summary?.durationMs || 0) / 1000).toFixed(2)}s</div>
        </div>
        <div class="summary-card">
            <h3>Status</h3>
            <div class="value">${result.summary?.status || 'unknown'}</div>
        </div>
    </div>

    ${result.recommendations && result.recommendations.length > 0 ? `
    <div class="section">
        <h2>Recommendations</h2>
        ${result.recommendations.map(rec => `
            <div class="recommendation ${rec.priority}">
                <span class="priority-badge priority-${rec.priority}">${rec.priority?.toUpperCase()}</span>
                <strong>${rec.description}</strong>
                <p>${rec.suggestion}</p>
                ${rec.files && rec.files.length > 0 ? `<div class="file-list">Files: ${rec.files.join(', ')}</div>` : ''}
            </div>
        `).join('')}
    </div>
    ` : ''}

    ${result.results && result.results.dedup ? `
    <div class="section">
        <h2>Duplication Analysis</h2>
        <p>Exact Duplicates: <strong>${result.results.dedup.summary?.exact?.duplicateGroups || 0}</strong></p>
        <p>Similar Code Pairs: <strong>${result.results.dedup.summary?.approximate?.similarPairs || 0}</strong></p>
    </div>
    ` : ''}

    ${result.results && result.results.deadCode ? `
    <div class="section">
        <h2>Dead Code Detection</h2>
        <p>Unused Functions: <strong>${result.results.deadCode.byType?.functions?.length || 0}</strong></p>
        <p>Unused Variables: <strong>${result.results.deadCode.byType?.variables?.length || 0}</strong></p>
        <p>Unused Imports: <strong>${result.results.deadCode.byType?.imports?.length || 0}</strong></p>
    </div>
    ` : ''}

    ${result.results && result.results.structure ? `
    <div class="section">
        <h2>Structure Analysis</h2>
        <p>Complex Functions: <strong>${result.results.structure.summary?.complexFunctions || 0}</strong></p>
        <p>Long Files: <strong>${result.results.structure.summary?.longFiles || 0}</strong></p>
        <p>Total Functions: <strong>${result.results.structure.summary?.totalFunctions || 0}</strong></p>
    </div>
    ` : ''}
</body>
</html>
    `;

    return html.trim();
  }
}
