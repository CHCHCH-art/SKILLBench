import chalk from 'chalk';

/**
 * Console formatter for human-readable output
 * Uses colors and formatting for better readability
 */
export class ConsoleFormatter {
  constructor(options = {}) {
    this.useColors = options.useColors !== false;
    this.verbose = options.verbose || false;
  }

  /**
   * Format analysis result for console output
   * @param {Object} result - Analysis result
   * @returns {string}
   */
  format(result) {
    const lines = [];

    // Header
    lines.push(this._formatHeader('Code Analysis Report'));
    lines.push('');

    // Summary
    if (result.summary) {
      lines.push(this._formatSummary(result.summary));
      lines.push('');
    }

    // Results
    if (result.results) {
      lines.push(this._formatResults(result.results));
      lines.push('');
    }

    // Recommendations
    if (result.recommendations && result.recommendations.length > 0) {
      lines.push(this._formatRecommendations(result.recommendations));
      lines.push('');
    }

    // Errors
    if (result.errors && result.errors.length > 0) {
      lines.push(this._formatErrors(result.errors));
      lines.push('');
    }

    return lines.join('\n');
  }

  /**
   * Format header
   * @private
   */
  _formatHeader(title) {
    if (this.useColors) {
      return chalk.bold.cyan('\n' + '='.repeat(50));
      + '\n' + chalk.bold.cyan(title)
      + '\n' + chalk.bold.cyan('='.repeat(50));
    }
    return '\n' + '='.repeat(50) + '\n' + title + '\n' + '='.repeat(50);
  }

  /**
   * Format summary
   * @private
   */
  _formatSummary(summary) {
    const lines = [];

    if (this.useColors) {
      lines.push(chalk.bold('Summary:'));
      lines.push(`  Status: ${this._formatStatus(summary.status)}`);
      lines.push(`  Files Analyzed: ${chalk.yellow(summary.filesAnalyzed || 0)}`);
      lines.push(`  Issues Found: ${chalk.red(summary.issuesFound || 0)}`);
      if (summary.durationMs) {
        lines.push(`  Duration: ${chalk.gray((summary.durationMs / 1000).toFixed(2))}s`);
      }
    } else {
      lines.push('Summary:');
      lines.push(`  Status: ${summary.status || 'unknown'}`);
      lines.push(`  Files Analyzed: ${summary.filesAnalyzed || 0}`);
      lines.push(`  Issues Found: ${summary.issuesFound || 0}`);
      if (summary.durationMs) {
        lines.push(`  Duration: ${(summary.durationMs / 1000).toFixed(2)}s`);
      }
    }

    return lines.join('\n');
  }

  /**
   * Format results
   * @private
   */
  _formatResults(results) {
    const lines = [];

    for (const [analyzer, result] of Object.entries(results)) {
      const title = this._getAnalyzerTitle(analyzer);
      lines.push(this._formatSection(title));
      lines.push(this._formatAnalyzerResult(analyzer, result));
      lines.push('');
    }

    return lines.join('\n');
  }

  /**
   * Format analyzer result
   * @private
   */
  _formatAnalyzerResult(analyzer, result) {
    switch (analyzer) {
      case 'dedup':
        return this._formatDedupResult(result);

      case 'deadCode':
        return this._formatDeadCodeResult(result);

      case 'structure':
        return this._formatStructureResult(result);

      default:
        return '  ' + JSON.stringify(result, null, 2).split('\n').join('\n  ');
    }
  }

  /**
   * Format deduplication result
   * @private
   */
  _formatDedupResult(result) {
    const lines = [];

    if (result.summary) {
      if (result.summary.exact) {
        const exact = result.summary.exact;
        if (this.useColors) {
          lines.push(`  Exact Duplicates: ${chalk.red(exact.duplicateGroups || 0)} groups`);
          lines.push(`  Total Duplicate Lines: ${chalk.red(exact.totalDuplicateLines || 0)}`);
        } else {
          lines.push(`  Exact Duplicates: ${exact.duplicateGroups || 0} groups`);
          lines.push(`  Total Duplicate Lines: ${exact.totalDuplicateLines || 0}`);
        }
      }

      if (result.summary.approximate) {
        const approx = result.summary.approximate;
        if (this.useColors) {
          lines.push(`  Similar Code Pairs: ${chalk.yellow(approx.similarPairs || 0)}`);
        } else {
          lines.push(`  Similar Code Pairs: ${approx.similarPairs || 0}`);
        }
      }
    }

    if (this.verbose && result.exact && result.exact.length > 0) {
      lines.push('');
      lines.push('  Exact Duplicates:');
      for (const dup of result.exact.slice(0, 10)) { // Limit to 10
        lines.push(`    - ${dup.occurrences[0].file}:${dup.occurrences[0].startLine}`);
        lines.push(`      ${dup.lineCount} lines, ${dup.duplicateCount} occurrences`);
      }
      if (result.exact.length > 10) {
        lines.push(`    ... and ${result.exact.length - 10} more`);
      }
    }

    return lines.join('\n');
  }

  /**
   * Format dead code result
   * @private
   */
  _formatDeadCodeResult(result) {
    const lines = [];

    if (result.byType) {
      if (this.useColors) {
        lines.push(`  Unused Functions: ${chalk.red(result.byType.functions?.length || 0)}`);
        lines.push(`  Unused Variables: ${chalk.yellow(result.byType.variables?.length || 0)}`);
        lines.push(`  Unused Imports: ${chalk.yellow(result.byType.imports?.length || 0)}`);
      } else {
        lines.push(`  Unused Functions: ${result.byType.functions?.length || 0}`);
        lines.push(`  Unused Variables: ${result.byType.variables?.length || 0}`);
        lines.push(`  Unused Imports: ${result.byType.imports?.length || 0}`);
      }
    }

    if (result.summary) {
      const summary = result.summary;
      if (this.useColors) {
        lines.push(`  Total Dead Code: ${chalk.red(summary.totalDead || 0)} items`);
      } else {
        lines.push(`  Total Dead Code: ${summary.totalDead || 0} items`);
      }
    }

    return lines.join('\n');
  }

  /**
   * Format structure result
   * @private
   */
  _formatStructureResult(result) {
    const lines = [];

    if (result.summary) {
      const summary = result.summary;
      if (this.useColors) {
        lines.push(`  Complex Functions: ${chalk.red(summary.complexFunctions || 0)}`);
        lines.push(`  Long Files: ${chalk.yellow(summary.longFiles || 0)}`);
        lines.push(`  Total Functions: ${summary.totalFunctions || 0}`);
      } else {
        lines.push(`  Complex Functions: ${summary.complexFunctions || 0}`);
        lines.push(`  Long Files: ${summary.longFiles || 0}`);
        lines.push(`  Total Functions: ${summary.totalFunctions || 0}`);
      }
    }

    if (this.verbose && result.complexFunctions && result.complexFunctions.length > 0) {
      lines.push('');
      lines.push('  Complex Functions:');
      for (const func of result.complexFunctions.slice(0, 5)) {
        lines.push(`    - ${func.file}:${func.function}`);
        for (const issue of func.issues) {
          lines.push(`      ${issue.message}`);
        }
      }
      if (result.complexFunctions.length > 5) {
        lines.push(`    ... and ${result.complexFunctions.length - 5} more`);
      }
    }

    return lines.join('\n');
  }

  /**
   * Format recommendations
   * @private
   */
  _formatRecommendations(recommendations) {
    const lines = [];

    if (this.useColors) {
      lines.push(chalk.bold('Recommendations:'));
    } else {
      lines.push('Recommendations:');
    }

    for (const rec of recommendations.slice(0, 10)) {
      const priority = rec.priority || 'medium';
      const icon = this._getPriorityIcon(priority);

      if (this.useColors) {
        lines.push(`  ${icon} ${this._formatPriority(priority)}: ${rec.description}`);
        lines.push(`     ${chalk.gray(rec.suggestion)}`);
      } else {
        lines.push(`  ${icon} [${priority.toUpperCase()}]: ${rec.description}`);
        lines.push(`     ${rec.suggestion}`);
      }

      if (rec.files && rec.files.length > 0) {
        lines.push(`     Files: ${rec.files.join(', ')}`);
      }
    }

    if (recommendations.length > 10) {
      lines.push(`  ... and ${recommendations.length - 10} more recommendations`);
    }

    return lines.join('\n');
  }

  /**
   * Format errors
   * @private
   */
  _formatErrors(errors) {
    const lines = [];

    if (this.useColors) {
      lines.push(chalk.bold.red('Errors:'));
    } else {
      lines.push('Errors:');
    }

    for (const error of errors) {
      if (this.useColors) {
        lines.push(`  ${chalk.red('✗')} ${error.message}`);
      } else {
        lines.push(`  ✗ ${error.message}`);
      }
    }

    return lines.join('\n');
  }

  /**
   * Format section header
   * @private
   */
  _formatSection(title) {
    if (this.useColors) {
      return chalk.bold('\n' + title);
    }
    return '\n' + title;
  }

  /**
   * Format status
   * @private
   */
  _formatStatus(status) {
    if (!this.useColors) return status || 'unknown';

    switch (status) {
      case 'success':
        return chalk.green(status);
      case 'warning':
        return chalk.yellow(status);
      case 'error':
        return chalk.red(status);
      default:
        return status;
    }
  }

  /**
   * Format priority
   * @private
   */
  _formatPriority(priority) {
    if (!this.useColors) return (priority || 'medium').toUpperCase();

    switch (priority) {
      case 'high':
        return chalk.red('HIGH');
      case 'medium':
        return chalk.yellow('MEDIUM');
      case 'low':
        return chalk.gray('LOW');
      default:
        return priority.toUpperCase();
    }
  }

  /**
   * Get priority icon
   * @private
   */
  _getPriorityIcon(priority) {
    switch (priority) {
      case 'high':
        return '🔴';
      case 'medium':
        return '🟡';
      case 'low':
        return '🟢';
      default:
        return '⚪';
    }
  }

  /**
   * Get analyzer title
   * @private
   */
  _getAnalyzerTitle(analyzer) {
    const titles = {
      dedup: 'Code Duplication',
      deadCode: 'Dead Code Detection',
      structure: 'Structure Analysis'
    };
    return titles[analyzer] || analyzer;
  }
}
