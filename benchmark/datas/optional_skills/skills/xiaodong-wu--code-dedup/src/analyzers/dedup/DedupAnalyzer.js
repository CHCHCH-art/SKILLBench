import { BaseAnalyzer } from '../base/BaseAnalyzer.js';
import { ExactDedup } from './ExactDedup.js';
import { MinHashLSH } from './MinHashLSH.js';
import {
  MIN_LINES_FOR_DEDUP,
  DEFAULT_SIMILARITY_THRESHOLD,
  DEFAULT_NGRAM_SIZE,
  DEFAULT_NUM_HASHES,
  DEFAULT_NUM_BANDS
} from '../../utils/constants.js';

/**
 * Deduplication analyzer facade
 * Combines exact and approximate duplicate detection
 */
export class DedupAnalyzer extends BaseAnalyzer {
  constructor(config = {}) {
    super(config);

    this.exactDedup = new ExactDedup({
      minLines: config.minLines ?? MIN_LINES_FOR_DEDUP,
      ignoreWhitespace: config.ignoreWhitespace !== false,
      ignoreComments: config.ignoreComments !== false
    });

    this.minHashLSH = config.enableMinHash !== false
      ? new MinHashLSH({
          numHashes: config.numHashes ?? DEFAULT_NUM_HASHES,
          ngramSize: config.ngramSize ?? DEFAULT_NGRAM_SIZE,
          numBands: config.numBands ?? DEFAULT_NUM_BANDS,
          minSimilarity: config.minSimilarity ?? DEFAULT_SIMILARITY_THRESHOLD
        })
      : null;
  }

  /**
   * Analyze files for duplicates
   * @param {Array} files - Array of file paths
   * @param {Object} context - Analysis context
   * @returns {Promise<Object>}
   */
  async analyze(files, context) {
    this.validateContext(context, ['fileContents']);

    const fileContents = context.fileContents;
    const results = {
      exact: [],
      approximate: [],
      summary: {}
    };

    // Phase 1: Exact duplicates (fast)
    if (this.config.exact !== false) {
      results.exact = this.exactDedup.findDuplicates(fileContents);
      results.summary.exact = this.exactDedup.getStats(results.exact);
    }

    // Phase 2: Approximate duplicates (MinHash + LSH)
    if (this.minHashLSH && this.config.approximate !== false) {
      results.approximate = this.minHashLSH.findSimilar(fileContents);
      results.summary.approximate = this.minHashLSH.getStats(results.approximate);
    }

    // Generate summary
    results.summary.total = {
      exactDuplicates: results.summary.exact?.duplicateGroups || 0,
      approximatePairs: results.summary.approximate?.similarPairs || 0,
      totalIssues: (results.summary.exact?.duplicateGroups || 0) +
                   (results.summary.approximate?.similarPairs || 0)
    };

    return results;
  }

  /**
   * Generate recommendations from results
   * @param {Object} results
   * @returns {Array}
   */
  generateRecommendations(results) {
    const recommendations = [];

    // Recommendations for exact duplicates
    for (const dup of results.exact) {
      const files = dup.occurrences.map(o => o.filepath);

      recommendations.push({
        type: 'dedup-exact',
        priority: 'high',
        description: `Exact duplicate code found (${dup.lineCount} lines, ${dup.duplicateCount} occurrences)`,
        files,
        suggestion: 'Extract duplicate code into a shared function or module',
        details: {
          lineCount: dup.lineCount,
          occurrences: dup.duplicateCount
        }
      });
    }

    // Recommendations for approximate duplicates
    for (const sim of results.approximate) {
      recommendations.push({
        type: 'dedup-approximate',
        priority: 'medium',
        description: `Similar code detected (${Math.round(sim.similarity * 100)}% similarity)`,
        files: [sim.file1, sim.file2],
        suggestion: 'Consider refactoring to reduce code duplication',
        details: {
          similarity: sim.similarity
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
      minLines: 5,
      minSimilarity: 0.85,
      enableMinHash: true,
      ignoreWhitespace: true,
      ignoreComments: true,
      ngramSize: 5,
      numBands: 20
    };
  }
}
