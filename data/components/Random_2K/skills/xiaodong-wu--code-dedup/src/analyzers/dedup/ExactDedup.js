import { createHash } from 'crypto';
import { countLines } from '../../utils/fileUtils.js';
import { MIN_LINES_FOR_DEDUP } from '../../utils/constants.js';

/**
 * Exact duplicate code detector using MD5 hashing
 * Fast O(n) detection of identical code blocks
 */
export class ExactDedup {
  constructor(config = {}) {
    this.minLines = config.minLines ?? MIN_LINES_FOR_DEDUP;
    this.ignoreWhitespace = config.ignoreWhitespace !== false;
    this.ignoreComments = config.ignoreComments !== false;
  }

  /**
   * Find exact duplicates across files
   * @param {Map<string, string>} fileContents - filepath -> source mapping
   * @returns {Array<Object>}
   */
  findDuplicates(fileContents) {
    const hashGroups = new Map();

    // Process each file
    for (const [filepath, source] of fileContents.entries()) {
      const blocks = this._extractCodeBlocks(filepath, source);

      for (const block of blocks) {
        const hash = this._computeHash(block.code);

        if (!hashGroups.has(hash)) {
          hashGroups.set(hash, []);
        }

        hashGroups.get(hash).push({
          filepath,
          ...block
        });
      }
    }

    // Filter for actual duplicates (hashes with >1 occurrence)
    const duplicates = [];

    for (const [hash, occurrences] of hashGroups.entries()) {
      if (occurrences.length > 1) {
        // Group by file
        const byFile = new Map();
        for (const occ of occurrences) {
          const key = occ.filepath;
          if (!byFile.has(key)) {
            byFile.set(key, []);
          }
          byFile.get(key).push(occ);
        }

        duplicates.push({
          hash,
          similarity: 1.0, // Exact match = 100%
          occurrences: occurrences.map(o => ({
            filepath: o.filepath,
            startLine: o.startLine,
            endLine: o.endLine,
            code: o.code
          })),
          duplicateCount: occurrences.length,
          lineCount: occurrences[0].endLine - occurrences[0].startLine + 1,
          type: 'exact'
        });
      }
    }

    return duplicates;
  }

  /**
   * Extract code blocks from source
   * @private
   */
  _extractCodeBlocks(filepath, source) {
    const blocks = [];
    const lines = source.split('\n');

    let currentBlock = [];
    let startLine = 0;

    for (let i = 0; i < lines.length; i++) {
      let line = lines[i];

      // Apply normalization
      if (this.ignoreWhitespace) {
        line = line.trim();
      }

      if (this.ignoreComments) {
        line = this._removeComments(line);
      }

      // Check if line is empty (after normalization)
      if (line === '') {
        // End current block if it's large enough
        if (currentBlock.length >= this.minLines) {
          blocks.push({
            startLine,
            endLine: i - 1,
            code: currentBlock.join('\n')
          });
        }
        currentBlock = [];
        startLine = i + 1;
      } else {
        currentBlock.push(line);
      }
    }

    // Don't forget the last block
    if (currentBlock.length >= this.minLines) {
      blocks.push({
        startLine,
        endLine: lines.length - 1,
        code: currentBlock.join('\n')
      });
    }

    return blocks;
  }

  /**
   * Compute MD5 hash of code
   * @private
   */
  _computeHash(code) {
    return createHash('md5').update(code).digest('hex');
  }

  /**
   * Remove comments from line
   * @private
   */
  _removeComments(line) {
    // Single-line comments
    line = line.replace(/\/\/.*$/g, '');
    line = line.replace(/#.*$/g, '');

    // Multi-line comments (start/end on same line)
    line = line.replace(/\/\*.*?\*\//g, '');

    return line;
  }

  /**
   * Get duplicate statistics
   * @param {Array} duplicates
   * @returns {Object}
   */
  getStats(duplicates) {
    let totalDuplicates = 0;
    let totalDuplicateLines = 0;

    for (const dup of duplicates) {
      totalDuplicates += dup.duplicateCount - 1; // Subtract 1 for original
      totalDuplicateLines += (dup.duplicateCount - 1) * dup.lineCount;
    }

    return {
      duplicateGroups: duplicates.length,
      totalDuplicates,
      totalDuplicateLines,
      avgSimilarity: 1.0 // All exact matches
    };
  }
}
