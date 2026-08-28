/**
 * Code Dedup Skills - Main API Entry Point
 * A comprehensive code analysis platform for deduplication, dead code detection, and structure optimization
 */

// New v2.0 API
export { CodeAnalyzer, createAnalyzer } from './core/CodeAnalyzer.js';
export { ConfigManager } from './core/ConfigManager.js';
export { AnalysisResult } from './core/AnalysisResult.js';

// Legacy v1.0 API (for backward compatibility)
export { CodeFormatter } from './CodeFormatter.js';
export { SimpleDeduper } from './SimpleDeduper.js';

/**
 * Main API function - analyze code
 * @param {string} targetPath - Path to analyze (file or directory)
 * @param {Object} options - Analysis options
 * @returns {Promise<Object>} Analysis results
 *
 * @example
 * // Simple usage
 * const result = await analyzeCode('./src', {
 *   analyses: ['dedup', 'deadCode', 'structure'],
 *   format: 'json'
 * });
 *
 * @example
 * // With custom configuration
 * const result = await analyzeCode('./src', {
 *   analyses: ['dedup'],
 *   dedup: {
 *     minLines: 10,
 *     minSimilarity: 0.9
 *   },
 *   format: 'console'
 * });
 */
export async function analyzeCode(targetPath, options = {}) {
  const { createAnalyzer } = await import('./core/CodeAnalyzer.js');
  const { ReportGenerator } = await import('./output/ReportGenerator.js');

  const analyzer = createAnalyzer(options.config);

  // Perform analysis
  const result = await analyzer.analyze(targetPath, options);

  // Generate report in requested format
  const format = options.format || 'json';
  const generator = new ReportGenerator({ format, useColors: options.useColors });

  if (format === 'json') {
    // Return parsed JSON for programmatic use
    return JSON.parse(generator.format(result));
  } else {
    // Return formatted string
    return generator.format(result);
  }
}

/**
 * Quick deduplication check
 * @param {string} targetPath - Path to check
 * @param {Object} options - Options
 * @returns {Promise<Object>}
 */
export async function checkDuplicates(targetPath, options = {}) {
  return analyzeCode(targetPath, {
    ...options,
    analyses: ['dedup']
  });
}

/**
 * Quick dead code detection
 * @param {string} targetPath - Path to check
 * @param {Object} options - Options
 * @returns {Promise<Object>}
 */
export async function checkDeadCode(targetPath, options = {}) {
  return analyzeCode(targetPath, {
    ...options,
    analyses: ['deadCode']
  });
}

/**
 * Quick structure analysis
 * @param {string} targetPath - Path to analyze
 * @param {Object} options - Options
 * @returns {Promise<Object>}
 */
export async function checkStructure(targetPath, options = {}) {
  return analyzeCode(targetPath, {
    ...options,
    analyses: ['structure']
  });
}

/**
 * Get default configuration
 * @returns {Object}
 */
export function getDefaultConfig() {
  return ConfigManager.getDefaultConfig();
}

// Default export
export default {
  // New v2.0 API
  CodeAnalyzer,
  createAnalyzer,
  ConfigManager,
  AnalysisResult,
  analyzeCode,
  checkDuplicates,
  checkDeadCode,
  checkStructure,
  getDefaultConfig,

  // Legacy v1.0 API
  CodeFormatter,
  SimpleDeduper
};
