/**
 * Base class for all code analyzers
 * Provides common functionality and enforces interface consistency
 */
export class BaseAnalyzer {
  constructor(config = {}) {
    this.config = {
      enabled: true,
      ...config
    };
    this.name = this.constructor.name;
  }

  /**
   * Main analysis method - must be implemented by subclasses
   * @param {Array} files - Array of file paths to analyze
   * @param {Object} context - Analysis context (parsers, cache, etc.)
   * @returns {Promise<Object>} Analysis results
   */
  async analyze(files, context) {
    throw new Error(`${this.name}.analyze() must be implemented by subclass`);
  }

  /**
   * Check if this analyzer is enabled
   * @returns {boolean}
   */
  isEnabled() {
    return this.config.enabled !== false;
  }

  /**
   * Get analyzer name
   * @returns {string}
   */
  getName() {
    return this.name;
  }

  /**
   * Validate that required context is available
   * @param {Object} context - Analysis context
   * @param {Array} required - Array of required context keys
   * @throws {Error} If required context is missing
   */
  validateContext(context, required = []) {
    const missing = required.filter(key => !(key in context));
    if (missing.length > 0) {
      throw new Error(`${this.name} requires context: ${missing.join(', ')}`);
    }
  }

  /**
   * Filter files based on analyzer-specific criteria
   * @param {Array} files - Array of file paths
   * @param {Object} context - Analysis context
   * @returns {Array} Filtered file paths
   */
  filterFiles(files, context) {
    // Default implementation returns all files
    return files;
  }

  /**
   * Get default configuration for this analyzer
   * @returns {Object}
   */
  static getDefaultConfig() {
    return {
      enabled: true
    };
  }
}
