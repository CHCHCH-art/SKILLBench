import { createHash } from 'crypto';
import { ConfigurationError } from '../../utils/errors.js';
import {
  DEFAULT_NUM_HASHES,
  DEFAULT_NUM_BANDS,
  DEFAULT_NGRAM_SIZE,
  DEFAULT_SIMILARITY_THRESHOLD,
  MIN_NGRAM_SIZE,
  MAX_NGRAM_SIZE,
  MIN_NUM_HASHES,
  MAX_NUM_HASHES
} from '../../utils/constants.js';

/**
 * MinHash + LSH (Locality Sensitive Hashing) for approximate duplicate detection
 * Optimizes from O(n²) to O(n) by using banding technique
 *
 * Algorithm explanation:
 * - numHashes: Total number of hash functions for MinHash signature
 * - numBands: Number of bands for LSH (splits signature into bands)
 * - rowsPerBand: Number of hash rows per band (numHashes / numBands)
 *
 * LSH threshold formula: (1/numBands)^(1/rowsPerBand)
 * Example: 20 bands, 5 rows/band = threshold ~0.725
 */
export class MinHashLSH {
  constructor(config = {}) {
    // MinHash parameters
    this.numHashes = config.numHashes ?? DEFAULT_NUM_HASHES;
    this.ngramSize = config.ngramSize ?? DEFAULT_NGRAM_SIZE;

    // LSH parameters
    this.numBands = config.numBands ?? DEFAULT_NUM_BANDS;
    this.rowsPerBand = Math.floor(this.numHashes / this.numBands);

    // Similarity threshold
    this.threshold = config.minSimilarity ?? DEFAULT_SIMILARITY_THRESHOLD;

    // Validate and auto-adjust parameters
    this._validateAndAdjust();
  }

  /**
   * Validate and adjust LSH parameters
   * @private
   * @throws {ConfigurationError} If parameters are invalid
   */
  _validateAndAdjust() {
    // Check if numBands * rowsPerBand equals numHashes
    if (this.numBands * this.rowsPerBand !== this.numHashes) {
      throw new ConfigurationError(
        `Invalid LSH parameters: numBands * rowsPerBand must equal numHashes`,
        {
          numBands: this.numBands,
          rowsPerBand: this.rowsPerBand,
          numHashes: this.numHashes,
          validBands: this._getValidBands(this.numHashes)
        }
      );
    }

    // Validate threshold
    if (this.threshold < 0 || this.threshold > 1) {
      throw new ConfigurationError(
        `minSimilarity must be between 0 and 1`,
        { threshold: this.threshold, min: 0, max: 1 }
      );
    }

    // Validate ngramSize
    if (this.ngramSize < MIN_NGRAM_SIZE || this.ngramSize > MAX_NGRAM_SIZE) {
      throw new ConfigurationError(
        `ngramSize must be between ${MIN_NGRAM_SIZE} and ${MAX_NGRAM_SIZE}`,
        { ngramSize: this.ngramSize, min: MIN_NGRAM_SIZE, max: MAX_NGRAM_SIZE }
      );
    }

    // Validate numHashes
    if (this.numHashes < MIN_NUM_HASHES || this.numHashes > MAX_NUM_HASHES) {
      throw new ConfigurationError(
        `numHashes must be between ${MIN_NUM_HASHES} and ${MAX_NUM_HASHES}`,
        { numHashes: this.numHashes, min: MIN_NUM_HASHES, max: MAX_NUM_HASHES }
      );
    }
  }

  /**
   * Get valid numBands values for a given numHashes
   * @private
   */
  _getValidBands(numHashes) {
    const validBands = [];
    for (let bands = 1; bands <= numHashes; bands++) {
      if (numHashes % bands === 0) {
        validBands.push(bands);
      }
    }
    return validBands;
  }

  /**
   * Find similar code blocks using MinHash + LSH
   * @param {Map<string, string>} fileContents - filepath -> source mapping
   * @returns {Array<Object>}
   */
  findSimilar(fileContents) {
    // Step 1: Generate signatures for all files
    const signatures = [];
    const fileMap = []; // To map signature index back to file

    let idx = 0;
    for (const [filepath, source] of fileContents.entries()) {
      const sig = this._generateSignature(source);
      signatures.push(sig);
      fileMap.push({ filepath, source });
      idx++;
    }

    // Step 2: Build LSH bands
    const bands = this._buildBands(signatures);

    // Step 3: Find candidate pairs from LSH bands
    const candidates = this._findCandidates(bands, fileMap);

    // Step 4: Verify candidates with actual Jaccard similarity
    const results = [];

    for (const candidate of candidates) {
      const sig1 = signatures[candidate.idx1];
      const sig2 = signatures[candidate.idx2];
      const estSimilarity = this._estimateSimilarity(sig1, sig2);

      if (estSimilarity >= this.threshold) {
        const file1 = fileMap[candidate.idx1];
        const file2 = fileMap[candidate.idx2];

        // Calculate more precise similarity
        const actualSimilarity = this._calculateJaccardSimilarity(
          file1.source,
          file2.source
        );

        if (actualSimilarity >= this.threshold) {
          results.push({
            file1: file1.filepath,
            file2: file2.filepath,
            similarity: actualSimilarity,
            type: 'approximate',
            method: 'minhash-lsh'
          });
        }
      }
    }

    return results;
  }

  /**
   * Generate MinHash signature for code
   * @private
   */
  _generateSignature(code) {
    // Step 1: Create n-grams (shingles)
    const shingles = this._createShingles(code);

    if (shingles.size === 0) {
      return new Array(this.numHashes).fill(Infinity);
    }

    // Step 2: Compute MinHash signature
    const signature = [];

    for (let i = 0; i < this.numHashes; i++) {
      let minHash = Infinity;

      for (const shingle of shingles) {
        const hash = this._hash(shingle + i);
        if (hash < minHash) {
          minHash = hash;
        }
      }

      signature.push(minHash);
    }

    return signature;
  }

  /**
   * Create n-gram shingles from code
   * @private
   */
  _createShingles(code) {
    const normalized = this._normalizeCode(code);
    const shingles = new Set();

    // Create overlapping n-grams of words
    const words = normalized.split(/\s+/);

    for (let i = 0; i <= words.length - this.ngramSize; i++) {
      const ngram = words.slice(i, i + this.ngramSize).join(' ');
      shingles.add(ngram);
    }

    // Also add character-level n-grams for better precision
    const chars = normalized.replace(/\s/g, '');
    for (let i = 0; i <= chars.length - this.ngramSize; i++) {
      const ngram = chars.substring(i, i + this.ngramSize);
      shingles.add(ngram);
    }

    return shingles;
  }

  /**
   * Normalize code for comparison
   * @private
   */
  _normalizeCode(code) {
    return code
      .toLowerCase()
      .replace(/\s+/g, ' ')           // Normalize whitespace
      .replace(/\/\*[\s\S]*?\*\//g, '') // Remove block comments
      .replace(/\/\/.*$/gm, '')        // Remove line comments
      .replace(/["'`]/g, '')           // Remove quotes
      .replace(/\d+/g, 'NUM')          // Normalize numbers
      .replace(/\b[a-zA-Z_$][a-zA-Z0-9_$]*\b/g, 'ID') // Normalize identifiers
      .trim();
  }

  /**
   * Build LSH bands from signatures
   * @private
   */
  _buildBands(signatures) {
    const bands = [];

    for (let b = 0; b < this.numBands; b++) {
      const band = new Map(); // band hash -> list of signature indices

      for (let i = 0; i < signatures.length; i++) {
        const signature = signatures[i];
        const start = b * this.rowsPerBand;
        const end = start + this.rowsPerBand;
        const bandRows = signature.slice(start, end);

        // Hash the band rows
        const bandHash = this._hashArray(bandRows);

        if (!band.has(bandHash)) {
          band.set(bandHash, []);
        }

        band.get(bandHash).push(i);
      }

      bands.push(band);
    }

    return bands;
  }

  /**
   * Find candidate pairs from LSH bands
   * @private
   */
  _findCandidates(bands, fileMap) {
    const candidateSet = new Set();

    for (const band of bands) {
      for (const [hash, indices] of band.entries()) {
        // Files in same bucket are candidates
        if (indices.length > 1) {
          for (let i = 0; i < indices.length; i++) {
            for (let j = i + 1; j < indices.length; j++) {
              const idx1 = indices[i];
              const idx2 = indices[j];

              // Skip if comparing file to itself
              if (fileMap[idx1].filepath === fileMap[idx2].filepath) {
                continue;
              }

              // Create unique key for pair
              const key = idx1 < idx2 ? `${idx1}-${idx2}` : `${idx2}-${idx1}`;
              candidateSet.add(key);
            }
          }
        }
      }
    }

    // Convert to array of objects
    return Array.from(candidateSet).map(key => {
      const [idx1, idx2] = key.split('-').map(Number);
      return { idx1, idx2 };
    });
  }

  /**
   * Estimate similarity from MinHash signatures
   * @private
   */
  _estimateSimilarity(sig1, sig2) {
    if (sig1.length !== sig2.length) {
      return 0;
    }

    let matchCount = 0;

    for (let i = 0; i < sig1.length; i++) {
      if (sig1[i] === sig2[i]) {
        matchCount++;
      }
    }

    return matchCount / sig1.length;
  }

  /**
   * Calculate actual Jaccard similarity
   * @private
   */
  _calculateJaccardSimilarity(code1, code2) {
    const shingles1 = this._createShingles(code1);
    const shingles2 = this._createShingles(code2);

    if (shingles1.size === 0 && shingles2.size === 0) {
      return 1.0;
    }

    if (shingles1.size === 0 || shingles2.size === 0) {
      return 0.0;
    }

    // Calculate intersection
    let intersection = 0;
    for (const s of shingles1) {
      if (shingles2.has(s)) {
        intersection++;
      }
    }

    // Calculate union
    const union = shingles1.size + shingles2.size - intersection;

    return intersection / union;
  }

  /**
   * Hash a string to a number
   * @private
   */
  _hash(str) {
    const hash = createHash('md5').update(str).digest('hex');
    return parseInt(hash.substring(0, 8), 16);
  }

  /**
   * Hash an array of numbers
   * @private
   */
  _hashArray(arr) {
    return this._hash(arr.join(','));
  }

  /**
   * Get statistics
   * @param {Array} results
   * @returns {Object}
   */
  getStats(results) {
    if (results.length === 0) {
      return {
        similarPairs: 0,
        avgSimilarity: 0,
        maxSimilarity: 0
      };
    }

    const totalSimilarity = results.reduce((sum, r) => sum + r.similarity, 0);
    const maxSimilarity = Math.max(...results.map(r => r.similarity));

    return {
      similarPairs: results.length,
      avgSimilarity: totalSimilarity / results.length,
      maxSimilarity
    };
  }
}
