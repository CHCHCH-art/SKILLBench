/**
 * JSON formatter for AI-friendly output
 * Returns structured JSON data
 */
export class JSONFormatter {
  constructor(options = {}) {
    this.indent = options.indent !== false ? 2 : 0;
    this.includeMetadata = options.includeMetadata !== false;
  }

  /**
   * Format analysis result as JSON
   * @param {Object} result - Analysis result
   * @returns {string}
   */
  format(result) {
    const formatted = {
      summary: this._formatSummary(result.summary),
      results: this._formatResults(result.results),
      recommendations: result.recommendations || []
    };

    if (this.includeMetadata) {
      formatted.metadata = result.metadata || {};
    }

    if (result.errors && result.errors.length > 0) {
      formatted.errors = result.errors;
    }

    return JSON.stringify(formatted, null, this.indent);
  }

  /**
   * Format summary section
   * @private
   */
  _formatSummary(summary) {
    return {
      status: summary.status || 'success',
      filesAnalyzed: summary.filesAnalyzed || 0,
      issuesFound: summary.issuesFound || 0,
      warnings: summary.warnings || 0,
      durationMs: summary.durationMs || 0
    };
  }

  /**
   * Format results section
   * @private
   */
  _formatResults(results) {
    const formatted = {};

    for (const [analyzer, result] of Object.entries(results)) {
      formatted[analyzer] = this._formatAnalyzerResult(result);
    }

    return formatted;
  }

  /**
   * Format individual analyzer result
   * @private
   */
  _formatAnalyzerResult(result) {
    // Handle different result types
    if (result.exact !== undefined || result.approximate !== undefined) {
      // Deduplication result
      return {
        exact: result.exact || [],
        approximate: result.approximate || [],
        summary: result.summary || {}
      };
    }

    if (result.deadCode !== undefined) {
      // Dead code result
      return {
        deadCode: result.deadCode || [],
        byType: result.byType || {},
        summary: result.summary || {}
      };
    }

    if (result.complexFunctions !== undefined || result.longFiles !== undefined) {
      // Structure result
      return {
        complexFunctions: result.complexFunctions || [],
        longFiles: result.longFiles || [],
        fileMetrics: result.fileMetrics || {},
        summary: result.summary || {}
      };
    }

    // Generic result
    return result;
  }

  /**
   * Format a single result item
   * @param {string} type - Result type
   * @param {Object} item - Result item
   * @returns {Object}
   */
  formatItem(type, item) {
    switch (type) {
      case 'duplicate':
        return {
          type: item.type || 'exact',
          similarity: item.similarity || 1.0,
          occurrences: item.occurrences || [],
          lineCount: item.lineCount || 0
        };

      case 'dead-code':
        return {
          symbol: item.symbol,
          itemType: item.itemType,
          file: item.file,
          line: item.line
        };

      case 'structure':
        return {
          file: item.file,
          function: item.function,
          metrics: item.metrics,
          issues: item.issues
        };

      default:
        return item;
    }
  }
}
