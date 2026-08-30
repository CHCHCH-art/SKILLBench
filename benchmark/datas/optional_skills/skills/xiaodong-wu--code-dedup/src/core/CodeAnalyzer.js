import { resolve, join } from 'path';
import { ConfigManager } from './ConfigManager.js';
import { AnalysisResult } from './AnalysisResult.js';
import { createParserManager } from '../parsers/ParserManager.js';
import { DedupAnalyzer } from '../analyzers/dedup/DedupAnalyzer.js';
import { DeadCodeAnalyzer } from '../analyzers/deadcode/DeadCodeAnalyzer.js';
import { StructureAnalyzer } from '../analyzers/structure/StructureAnalyzer.js';
import { ReportGenerator } from '../output/ReportGenerator.js';
import { scanFiles, readFiles, getRelativePath } from '../utils/fileUtils.js';
import { createCache } from '../utils/cache.js';
import { parallel } from '../utils/parallel.js';

/**
 * Main code analyzer facade
 * Provides simple API for AI agents and CLI tools
 */
export class CodeAnalyzer {
  constructor(config = {}) {
    this.config = new ConfigManager(config);
    this.parser = null;
    this.cache = null;
    this.analyzers = new Map();

    this._initialize();
  }

  /**
   * Initialize components
   * @private
   */
  _initialize() {
    // Create cache
    if (this.config.get('performance.cacheEnabled')) {
      this.cache = createCache({
        enabled: true,
        cacheDir: this.config.get('performance.cacheDir'),
        ttl: 3600000 // 1 hour
      });
    }

    // Create parser manager
    this.parser = createParserManager({
      cache: this.cache,
      defaultLanguage: this.config.get('parser.language')
    });

    // Initialize analyzers
    this._initializeAnalyzers();
  }

  /**
   * Initialize analyzers based on config
   * @private
   */
  _initializeAnalyzers() {
    const analyses = this.config.get('analyses', []);

    // Deduplication analyzer
    if (analyses.includes('dedup') && this.config.isAnalyzerEnabled('dedup')) {
      this.analyzers.set('dedup', new DedupAnalyzer(
        this.config.getAnalyzerConfig('dedup')
      ));
    }

    // Dead code analyzer
    if (analyses.includes('deadCode') && this.config.isAnalyzerEnabled('deadCode')) {
      this.analyzers.set('deadCode', new DeadCodeAnalyzer(
        this.config.getAnalyzerConfig('deadCode')
      ));
    }

    // Structure analyzer
    if (analyses.includes('structure') && this.config.isAnalyzerEnabled('structure')) {
      this.analyzers.set('structure', new StructureAnalyzer(
        this.config.getAnalyzerConfig('structure')
      ));
    }
  }

  /**
   * Analyze code at the given path
   * @param {string} targetPath - Path to analyze (file or directory)
   * @param {Object} options - Override options
   * @returns {Promise<Object>}
   */
  async analyze(targetPath, options = {}) {
    const result = new AnalysisResult();

    try {
      // Merge options with config
      const config = options.config
        ? new ConfigManager({ ...this.config.getAll(), ...options.config })
        : this.config;

      // Scan files
      const files = await this._scanFiles(targetPath, config);

      if (files.length === 0) {
        return result
          .setStatus('warning')
          .setFilesAnalyzed(0)
          .build();
      }

      result.setFilesAnalyzed(files.length);

      // Read file contents
      const fileContents = await this._readFileContents(files, config);

      // Parse files
      const parseTrees = await this._parseFiles(fileContents);

      // Create analysis context
      const baseDir = resolve(targetPath);
      const context = {
        files,
        fileContents,
        parseTrees,
        baseDir,
        config,
        cache: this.cache
      };

      // Run analyzers
      const analysisResults = await this._runAnalyzers(files, context);

      // Collect results
      for (const [name, analyzerResult] of Object.entries(analysisResults)) {
        result.addResult(name, analyzerResult);
        result.addIssues(this._countIssues(analyzerResult));

        // Generate recommendations
        const analyzer = this.analyzers.get(name);
        if (analyzer && analyzer.generateRecommendations) {
          const recommendations = analyzer.generateRecommendations(analyzerResult);
          result.addRecommendations(recommendations);
        }
      }

      return result.build();

    } catch (error) {
      return result.markFailed(error).build();
    }
  }

  /**
   * Scan files for analysis
   * @private
   */
  async _scanFiles(targetPath, config) {
    const options = {
      include: config.get('files.include'),
      exclude: config.get('files.exclude'),
      ignoreTests: config.get('deadCode.ignoreTestFiles'),
      testPatterns: config.get('deadCode.testPatterns')
    };

    return await scanFiles(targetPath, options);
  }

  /**
   * Read file contents
   * @private
   */
  async _readFileContents(files, config) {
    const maxParallel = config.get('performance.maxParallel');
    return await readFiles(files);
  }

  /**
   * Parse files
   * @private
   */
  async _parseFiles(fileContents) {
    return await this.parser.parseFiles(fileContents);
  }

  /**
   * Run all analyzers
   * @private
   */
  async _runAnalyzers(files, context) {
    const results = {};
    const maxParallel = this.config.get('performance.maxParallel');

    // Run analyzers in parallel if configured
    if (this.config.get('performance.parallel')) {
      const analyzerEntries = Array.from(this.analyzers.entries());

      const analysisResults = await parallel(
        analyzerEntries,
        async ([name, analyzer]) => {
          try {
            const result = await analyzer.analyze(files, context);
            return [name, result];
          } catch (error) {
            console.error(`Analyzer ${name} failed:`, error.message);
            return [name, { error: error.message }];
          }
        },
        { concurrency: maxParallel }
      );

      for (const [name, result] of analysisResults) {
        results[name] = result;
      }
    } else {
      // Run sequentially
      for (const [name, analyzer] of this.analyzers.entries()) {
        try {
          results[name] = await analyzer.analyze(files, context);
        } catch (error) {
          console.error(`Analyzer ${name} failed:`, error.message);
          results[name] = { error: error.message };
        }
      }
    }

    return results;
  }

  /**
   * Count issues in analysis result
   * @private
   */
  _countIssues(result) {
    let count = 0;

    if (result.summary) {
      if (result.summary.total) {
        count += result.summary.total.totalIssues || 0;
      } else if (result.summary.totalDead !== undefined) {
        count += result.summary.totalDead || 0;
      } else if (result.summary.complexFunctions !== undefined) {
        count += (result.summary.complexFunctions || 0) +
                 (result.summary.longFiles || 0);
      }
    }

    return count;
  }

  /**
   * Generate report
   * @param {Object} analysisResult - Result from analyze()
   * @param {Object} options - Report options
   * @returns {Promise<string>}
   */
  async generateReport(analysisResult, options = {}) {
    const generator = new ReportGenerator({
      format: options.format || this.config.get('output.format'),
      outputFile: options.outputFile || null,
      useColors: options.useColors !== false,
      verbose: options.verbose || this.config.get('output.verbose')
    });

    // If HTML format requested
    if (options.format === 'html') {
      return generator.generateHTML(analysisResult);
    }

    return await generator.generate(analysisResult);
  }

  /**
   * Get configuration
   * @returns {Object}
   */
  getConfig() {
    return this.config.getAll();
  }

  /**
   * Update configuration
   * @param {Object} updates - Configuration updates
   */
  updateConfig(updates) {
    for (const [key, value] of Object.entries(updates)) {
      this.config.set(key, value);
    }

    // Re-initialize analyzers with new config
    this.analyzers.clear();
    this._initializeAnalyzers();
  }

  /**
   * Get analyzer statistics
   * @returns {Object}
   */
  getStats() {
    return {
      config: this.config.getAll(),
      parser: this.parser.getStats(),
      cache: this.cache ? this.cache.getStats() : null,
      analyzers: Array.from(this.analyzers.keys())
    };
  }

  /**
   * Clear cache
   */
  async clearCache() {
    if (this.cache) {
      await this.cache.clear();
    }
    this.parser.clearCache();
  }
}

/**
 * Create a code analyzer instance
 * @param {Object} config
 * @returns {CodeAnalyzer}
 */
export function createAnalyzer(config = {}) {
  return new CodeAnalyzer(config);
}
