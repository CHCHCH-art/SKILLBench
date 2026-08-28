import { readFileSync, existsSync } from 'fs';
import { resolve } from 'path';

/**
 * Default configuration for the code analyzer
 */
const DEFAULT_CONFIG = {
  // Which analyzers to run
  analyses: ['dedup', 'deadCode', 'structure'],

  // Parser settings
  parser: {
    language: 'javascript', // Default language
    fallbackLanguages: ['typescript', 'javascript']
  },

  // Deduplication settings
  dedup: {
    enabled: true,
    minLines: 5,
    minSimilarity: 0.85,
    enableMinHash: true,
    enableSemantic: false, // Expensive, disabled by default
    ignoreWhitespace: true,
    ignoreComments: true,
    ngramSize: 5, // For MinHash
    numBands: 20, // LSH bands
    numRows: 5 // LSH rows per band
  },

  // Dead code detection settings
  deadCode: {
    enabled: true,
    ignoreExports: true,
    ignoreTestFiles: true,
    testPatterns: ['**/*.test.js', '**/*.spec.js', '**/test/**', '**/tests/**'],
    whitelistPatterns: [], // Functions/variables to never flag as dead
    includeExtensions: ['.js', '.ts', '.jsx', '.tsx']
  },

  // Structure analysis settings
  structure: {
    enabled: true,
    maxComplexity: 10,
    maxFunctionLength: 50,
    maxNestingDepth: 4,
    maxParameters: 5,
    maxFileSize: 500 // lines
  },

  // Formatting settings
  formatting: {
    enabled: false,
    indentSize: 2,
    indentType: 'space',
    trailingWhitespace: true,
    finalNewline: true
  },

  // Output settings
  output: {
    format: 'json', // 'json' or 'console'
    verbose: false,
    showSummary: true,
    showRecommendations: true
  },

  // Performance settings
  performance: {
    parallel: true,
    maxParallel: 4,
    cacheEnabled: true,
    cacheDir: '.cache/code-dedup'
  },

  // File patterns
  files: {
    include: ['**/*.js', '**/*.ts', '**/*.jsx', '**/*.tsx'],
    exclude: ['**/node_modules/**', '**/dist/**', '**/build/**', '**/.git/**']
  }
};

/**
 * Manages configuration for the code analyzer
 * Handles default values, user overrides, and config file loading
 */
export class ConfigManager {
  constructor(userConfig = {}) {
    this.config = this.mergeConfig(DEFAULT_CONFIG, userConfig);
    this.loadConfigFile();
  }

  /**
   * Get configuration value by path
   * @param {string} path - Dot-notation path (e.g., 'dedup.minLines')
   * @param {*} defaultValue - Default value if path not found
   * @returns {*}
   */
  get(path, defaultValue = undefined) {
    const keys = path.split('.');
    let value = this.config;

    for (const key of keys) {
      if (value && typeof value === 'object' && key in value) {
        value = value[key];
      } else {
        return defaultValue;
      }
    }

    return value;
  }

  /**
   * Set configuration value by path
   * @param {string} path - Dot-notation path
   * @param {*} value - Value to set
   */
  set(path, value) {
    const keys = path.split('.');
    let current = this.config;

    for (let i = 0; i < keys.length - 1; i++) {
      const key = keys[i];
      if (!(key in current) || typeof current[key] !== 'object') {
        current[key] = {};
      }
      current = current[key];
    }

    current[keys[keys.length - 1]] = value;
  }

  /**
   * Get entire configuration object
   * @returns {Object}
   */
  getAll() {
    return { ...this.config };
  }

  /**
   * Merge user config with default config
   * @param {Object} defaults - Default configuration
   * @param {Object} user - User configuration
   * @returns {Object} Merged configuration
   */
  mergeConfig(defaults, user) {
    const merged = { ...defaults };

    for (const key in user) {
      if (user[key] && typeof user[key] === 'object' && !Array.isArray(user[key])) {
        merged[key] = this.mergeConfig(
          defaults[key] || {},
          user[key]
        );
      } else {
        merged[key] = user[key];
      }
    }

    return merged;
  }

  /**
   * Load config file if it exists
   * Checks for .codededuprc.json and package.json config
   */
  loadConfigFile() {
    const configPaths = [
      '.codededuprc.json',
      '.code-dedup.json',
      'codededup.config.json'
    ];

    for (const filename of configPaths) {
      const filepath = resolve(process.cwd(), filename);
      if (existsSync(filepath)) {
        try {
          const fileConfig = JSON.parse(readFileSync(filepath, 'utf-8'));
          this.config = this.mergeConfig(this.config, fileConfig);
          return;
        } catch (error) {
          console.warn(`Failed to load config file ${filename}: ${error.message}`);
        }
      }
    }

    // Try loading from package.json
    const packageJsonPath = resolve(process.cwd(), 'package.json');
    if (existsSync(packageJsonPath)) {
      try {
        const packageJson = JSON.parse(readFileSync(packageJsonPath, 'utf-8'));
        if (packageJson['code-dedup']) {
          this.config = this.mergeConfig(this.config, packageJson['code-dedup']);
        }
      } catch (error) {
        // Ignore package.json errors
      }
    }
  }

  /**
   * Get configuration for a specific analyzer
   * @param {string} analyzerName - Name of the analyzer
   * @returns {Object}
   */
  getAnalyzerConfig(analyzerName) {
    return this.get(analyzerName, {});
  }

  /**
   * Check if an analyzer is enabled
   * @param {string} analyzerName - Name of the analyzer
   * @returns {boolean}
   */
  isAnalyzerEnabled(analyzerName) {
    const config = this.getAnalyzerConfig(analyzerName);
    return config.enabled !== false;
  }

  /**
   * Validate configuration
   * @returns {Object} { valid: boolean, errors: Array }
   */
  validate() {
    const errors = [];

    // Validate analyses array
    if (!Array.isArray(this.config.analyses)) {
      errors.push('analyses must be an array');
    }

    // Validate dedup similarity threshold
    const minSimilarity = this.get('dedup.minSimilarity');
    if (typeof minSimilarity !== 'number' || minSimilarity < 0 || minSimilarity > 1) {
      errors.push('dedup.minSimilarity must be a number between 0 and 1');
    }

    // Validate parallel settings
    const maxParallel = this.get('performance.maxParallel');
    if (typeof maxParallel !== 'number' || maxParallel < 1) {
      errors.push('performance.maxParallel must be a positive number');
    }

    return {
      valid: errors.length === 0,
      errors
    };
  }

  /**
   * Get default configuration (static method)
   * @returns {Object}
   */
  static getDefaultConfig() {
    return JSON.parse(JSON.stringify(DEFAULT_CONFIG));
  }
}
