import { describe, it } from 'node:test';
import assert from 'node:assert';
import { MinHashLSH } from '../../src/analyzers/dedup/MinHashLSH.js';

describe('MinHashLSH', () => {
  it('should validate correct parameters', () => {
    const lsh = new MinHashLSH({
      numHashes: 100,
      numBands: 20,
      ngramSize: 5,
      minSimilarity: 0.85
    });
    assert.strictEqual(lsh.numHashes, 100);
    assert.strictEqual(lsh.numBands, 20);
    assert.strictEqual(lsh.rowsPerBand, 5);
  });

  it('should throw on invalid band configuration', () => {
    assert.throws(() => {
      new MinHashLSH({
        numHashes: 100,
        numBands: 15, // 15 * 6 != 100
        ngramSize: 5
      });
    }, /Invalid LSH parameters/);
  });

  it('should throw on invalid similarity threshold', () => {
    assert.throws(() => {
      new MinHashLSH({
        minSimilarity: 1.5
      });
    }, /minSimilarity must be between 0 and 1/);
  });

  it('should throw on invalid ngramSize', () => {
    assert.throws(() => {
      new MinHashLSH({
        ngramSize: 0
      });
    }, /ngramSize must be between 1 and 10/);

    assert.throws(() => {
      new MinHashLSH({
        ngramSize: 11
      });
    }, /ngramSize must be between 1 and 10/);
  });

  it('should detect similar code', () => {
    const lsh = new MinHashLSH({
      numHashes: 50, // Smaller for tests
      ngramSize: 3,
      numBands: 10,
      minSimilarity: 0.8
    });

    const fileContents = new Map([
      ['file1.js', 'function test() { return true; }'],
      ['file2.js', 'function test() { return false; }']  // Similar structure
    ]);

    const results = lsh.findSimilar(fileContents);
    assert.ok(results.length > 0);
    assert.ok(results[0].similarity >= 0.8, `Expected similarity >= 0.8, got ${results[0].similarity}`);
  });

  it('should not detect dissimilar code', () => {
    const lsh = new MinHashLSH({
      numHashes: 50,
      ngramSize: 3,
      numBands: 10,
      minSimilarity: 0.95  // Higher threshold
    });

    const fileContents = new Map([
      ['file1.js', 'function test() { return true; }'],
      ['file2.js', 'const x = 42; console.log(x);']  // Completely different structure
    ]);

    const results = lsh.findSimilar(fileContents);
    // Should not find highly similar pairs at 0.95 threshold
    const highSimilarity = results.filter(r => r.similarity >= 0.95);
    assert.strictEqual(highSimilarity.length, 0);
  });

  it('should generate stats', () => {
    const lsh = new MinHashLSH({
      numHashes: 50,
      ngramSize: 3,
      numBands: 10,
      minSimilarity: 0.85
    });

    const fileContents = new Map([
      ['file1.js', 'function test() { return true; }'],
      ['file2.js', 'function test() { return false; }']
    ]);

    const results = lsh.findSimilar(fileContents);
    const stats = lsh.getStats(results);
    assert.ok(stats.similarPairs >= 0);
    assert.ok(stats.avgSimilarity >= 0);
    assert.ok(stats.maxSimilarity <= 1);
  });

  it('should handle empty input', () => {
    const lsh = new MinHashLSH();
    const fileContents = new Map();

    const results = lsh.findSimilar(fileContents);
    assert.strictEqual(results.length, 0);

    const stats = lsh.getStats(results);
    assert.strictEqual(stats.similarPairs, 0);
  });

  it('should provide valid bands for common numHashes', () => {
    const lsh = new MinHashLSH();

    // Test helper method
    const bands100 = lsh._getValidBands(100);
    assert.ok(bands100.includes(20));
    assert.ok(bands100.includes(10));
    assert.ok(bands100.includes(25));
  });
});
