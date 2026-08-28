import { BaseAnalyzer } from '../base/BaseAnalyzer.js';
import { ComplexityCalculator } from './ComplexityCalculator.js';
import { getRelativePath, countLines } from '../../utils/fileUtils.js';
import {
  MAX_CYCLOMATIC_COMPLEXITY,
  MAX_FUNCTION_LENGTH_LINES,
  MAX_FUNCTION_PARAMETERS,
  MAX_FILE_SIZE_LINES
} from '../../utils/constants.js';

/**
 * Structure analysis analyzer
 * Detects complex functions, long files, and provides refactoring suggestions
 */
export class StructureAnalyzer extends BaseAnalyzer {
  constructor(config = {}) {
    super(config);
    this.calculator = new ComplexityCalculator({
      maxComplexity: config.maxComplexity ?? MAX_CYCLOMATIC_COMPLEXITY,
      maxFunctionLength: config.maxFunctionLength ?? MAX_FUNCTION_LENGTH_LINES,
      maxNestingDepth: config.maxNestingDepth ?? 4,
      maxParameters: config.maxParameters ?? MAX_FUNCTION_PARAMETERS
    });
    this.maxFileSize = config.maxFileSize ?? MAX_FILE_SIZE_LINES;
  }

  /**
   * Analyze code structure
   * @param {Array} files - Array of file paths
   * @param {Object} context - Analysis context
   * @returns {Promise<Object>}
   */
  async analyze(files, context) {
    this.validateContext(context, ['parseTrees', 'fileContents', 'baseDir']);

    const parseTrees = context.parseTrees;
    const fileContents = context.fileContents;
    const baseDir = context.baseDir;

    const results = {
      complexFunctions: [],
      longFiles: [],
      fileMetrics: {},
      summary: {
        totalFiles: files.length,
        totalFunctions: 0,
        complexFunctions: 0,
        longFiles: 0
      }
    };

    // Analyze each file
    for (const [filepath, tree] of parseTrees.entries()) {
      const source = fileContents.get(filepath);
      const relativePath = getRelativePath(filepath, baseDir);

      // Calculate file metrics
      const metrics = this.calculator.calculateFileMetrics(tree, source);
      results.fileMetrics[relativePath] = metrics;

      // Check file length
      const lineCount = source.split('\n').length;
      if (lineCount > this.maxFileSize) {
        results.longFiles.push({
          file: relativePath,
          lines: lineCount,
          threshold: this.maxFileSize
        });
        results.summary.longFiles++;
      }

      // Check each function
      if (metrics.functions) {
        results.summary.totalFunctions += metrics.functions.length;

        for (const func of metrics.functions) {
          const check = this.calculator.checkThresholds(func);

          if (!check.passes) {
            results.complexFunctions.push({
              file: relativePath,
              function: func.name,
              metrics: func,
              issues: check.issues
            });
            results.summary.complexFunctions++;
          }
        }
      }
    }

    return results;
  }

  /**
   * Generate recommendations
   * @param {Object} results
   * @returns {Array}
   */
  generateRecommendations(results) {
    const recommendations = [];

    // Recommendations for complex functions
    for (const func of results.complexFunctions) {
      const primaryIssue = func.issues[0]; // Most severe

      let suggestion = '';
      let priority = 'medium';

      switch (primaryIssue.type) {
        case 'high-complexity':
          suggestion = `Extract complex logic into smaller functions or use early returns to reduce cyclomatic complexity`;
          priority = 'high';
          break;
        case 'long-function':
          suggestion = `Split this function into smaller, more focused functions`;
          priority = 'medium';
          break;
        case 'deep-nesting':
          suggestion = `Reduce nesting by using guard clauses or extracting nested logic`;
          priority = 'medium';
          break;
        case 'too-many-parameters':
          suggestion = `Consider using an options object or splitting the function`;
          priority = 'low';
          break;
      }

      recommendations.push({
        type: 'structure',
        priority,
        description: primaryIssue.message,
        files: [func.file],
        suggestion,
        details: {
          function: func.function,
          metrics: func.metrics,
          issues: func.issues
        }
      });
    }

    // Recommendations for long files
    for (const file of results.longFiles) {
      recommendations.push({
        type: 'structure',
        priority: 'low',
        description: `File is ${file.lines} lines long (threshold: ${file.threshold})`,
        files: [file.file],
        suggestion: 'Consider splitting this file into smaller modules',
        details: {
          lines: file.lines,
          threshold: file.threshold
        }
      });
    }

    return recommendations;
  }

  /**
   * Get default configuration
   */
  static getDefaultConfig() {
    return {
      enabled: true,
      maxComplexity: 10,
      maxFunctionLength: 50,
      maxNestingDepth: 4,
      maxParameters: 5,
      maxFileSize: 500
    };
  }
}
