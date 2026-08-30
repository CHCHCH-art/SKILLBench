import { describe, it } from 'node:test';
import assert from 'node:assert';
import { ExactDedup } from '../../src/analyzers/dedup/ExactDedup.js';

describe('ExactDedup', () => {
  it('should find exact duplicates', () => {
    const dedup = new ExactDedup({ minLines: 3 });
    const fileContents = new Map([
      ['file1.js', 'function test() {\n  return true;\n}\n'],
      ['file2.js', 'function test() {\n  return true;\n}\n'],
      ['file3.js', 'function different() {\n  return false;\n}\n']
    ]);

    const duplicates = dedup.findDuplicates(fileContents);
    assert.strictEqual(duplicates.length, 1);
    assert.strictEqual(duplicates[0].duplicateCount, 2);
    assert.strictEqual(duplicates[0].similarity, 1.0);
  });

  it('should ignore code blocks below minLines', () => {
    const dedup = new ExactDedup({ minLines: 5 });
    const fileContents = new Map([
      ['file1.js', 'function test() {\n  return true;\n}\n']
    ]);

    const duplicates = dedup.findDuplicates(fileContents);
    assert.strictEqual(duplicates.length, 0);
  });

  it('should ignore whitespace when configured', () => {
    const dedup = new ExactDedup({
      minLines: 3,
      ignoreWhitespace: true
    });
    const fileContents = new Map([
      ['file1.js', 'function test() {\n    return true;\n}\n'],
      ['file2.js', 'function test() {\n  return true;\n}\n']
    ]);

    const duplicates = dedup.findDuplicates(fileContents);
    assert.strictEqual(duplicates.length, 1);
  });

  it('should get stats', () => {
    const dedup = new ExactDedup({ minLines: 3 });
    const fileContents = new Map([
      ['file1.js', 'function test() {\n  return true;\n}\n'],
      ['file2.js', 'function test() {\n  return true;\n}\n']
    ]);

    const duplicates = dedup.findDuplicates(fileContents);
    const stats = dedup.getStats(duplicates);

    assert.strictEqual(stats.duplicateGroups, 1);
    assert.strictEqual(stats.totalDuplicates, 1);
    assert.strictEqual(stats.totalDuplicateLines, 3);
  });

  it('should handle empty input', () => {
    const dedup = new ExactDedup({ minLines: 3 });
    const fileContents = new Map();
    const duplicates = dedup.findDuplicates(fileContents);
    assert.strictEqual(duplicates.length, 0);
  });

  it('should not flag single occurrences', () => {
    const dedup = new ExactDedup({ minLines: 3 });
    const fileContents = new Map([
      ['file1.js', 'function test1() {\n  return true;\n}\n'],
      ['file2.js', 'function test2() {\n  return false;\n}\n']
    ]);

    const duplicates = dedup.findDuplicates(fileContents);
    assert.strictEqual(duplicates.length, 0);
  });

  it('should find multiple duplicate groups', () => {
    const dedup = new ExactDedup({ minLines: 2 });
    const fileContents = new Map([
      ['file1.js', 'function test1() {\n  return true;\n}\n\nfunction test2() {\n  return false;\n}\n'],
      ['file2.js', 'function test1() {\n  return true;\n}\n\nfunction test3() {\n  return null;\n}\n'],
      ['file3.js', 'function test2() {\n  return false;\n}\n\nfunction test3() {\n  return null;\n}\n']
    ]);

    const duplicates = dedup.findDuplicates(fileContents);
    assert.ok(duplicates.length >= 2);
  });
});
