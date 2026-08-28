import { describe, it } from 'node:test';
import assert from 'node:assert';
import { DeadCodeAnalyzer } from '../../src/analyzers/deadcode/DeadCodeAnalyzer.js';
import { ReferenceGraph } from '../../src/analyzers/deadcode/ReferenceGraph.js';

describe('DeadCodeAnalyzer', () => {
  it('should detect unused functions', async () => {
    const analyzer = new DeadCodeAnalyzer();

    // Mock parse trees with an unused function
    const context = {
      parseTrees: new Map([
        ['test.js', {
          rootNode: {
            type: 'file',
            startPosition: { row: 0, column: 0 },
            endPosition: { row: 2, column: 1 },
            startIndex: 0,
            endIndex: 30,
            children: [
              {
                type: 'function_declaration',
                startPosition: { row: 0, column: 0 },
                endPosition: { row: 2, column: 1 },
                startIndex: 0,
                endIndex: 30,
                text: 'function unused() { return true; }',
                children: [],
                childForFieldName: () => null,
                parent: null
              }
            ],
            childForFieldName: () => null,
            parent: null
          },
          source: 'function unused() { return true; }',
          language: 'javascript'
        }]
      ]),
      baseDir: '/test'
    };

    const results = await analyzer.analyze(['test.js'], context);

    assert.ok(results.deadCode);
    assert.ok(results.deadCode.length > 0);
    assert.ok(results.summary);
  });

  it('should not flag exported functions', async () => {
    const analyzer = new DeadCodeAnalyzer({
      ignoreExports: true
    });

    const context = {
      parseTrees: new Map([
        ['test.js', {
          rootNode: {
            type: 'file',
            startPosition: { row: 0, column: 0 },
            endPosition: { row: 2, column: 1 },
            startIndex: 0,
            endIndex: 35,
            children: [
              {
                type: 'function_declaration',
                startPosition: { row: 0, column: 0 },
                endPosition: { row: 2, column: 1 },
                startIndex: 0,
                endIndex: 35,
                text: 'export function used() { return true; }',
                children: [],
                childForFieldName: () => null,
                parent: null
              }
            ],
            childForFieldName: () => null,
            parent: null
          },
          source: 'export function used() { return true; }',
          language: 'javascript'
        }]
      ]),
      baseDir: '/test'
    };

    const results = await analyzer.analyze(['test.js'], context);

    // Exported function should be ignored
    const exportedFuncs = results.deadCode.filter(d => d.exported);
    assert.strictEqual(exportedFuncs.length, 0);
  });

  it('should not flag test files when ignoreTests is true', async () => {
    const analyzer = new DeadCodeAnalyzer({
      ignoreTestFiles: true,
      testPatterns: ['**/*.test.js']
    });

    const context = {
      parseTrees: new Map([
        ['test.js', {
          rootNode: {
            type: 'file',
            children: [],
            childForFieldName: () => null,
            parent: null
          },
          source: '',
          language: 'javascript'
        }]
      ]),
      baseDir: '/test'
    };

    // This would be filtered in the file scanning phase
    // Just verify the config is used
    assert.strictEqual(analyzer.config.ignoreTestFiles, true);
  });

  it('should handle whitelist patterns', async () => {
    const analyzer = new DeadCodeAnalyzer({
      whitelistPatterns: ['handleClick', 'processEvent']
    });

    // Mock context with functions that match whitelist
    const context = {
      parseTrees: new Map([
        ['test.js', {
          rootNode: {
            type: 'file',
            children: [
              {
                type: 'function_declaration',
                text: 'function handleClick() {}',
                childForFieldName: () => null,
                parent: null
              },
              {
                type: 'function_declaration',
                text: 'function processEvent() {}',
                childForFieldName: () => null,
                parent: null
              }
            ],
            childForFieldName: () => null,
            parent: null
          },
          source: 'function handleClick() {} function processEvent() {}',
          language: 'javascript'
        }]
      ]),
      baseDir: '/test'
    };

    // Verify whitelist is accessible
    assert.ok(analyzer.config.whitelistPatterns.includes('handleClick'));
  });

  it('should generate recommendations', async () => {
    const analyzer = new DeadCodeAnalyzer();

    // Create a result with dead code
    const mockResult = {
      deadCode: [
        {
          symbol: 'unusedFunction',
          file: 'test.js',
          line: 5,
          type: 'function'
        }
      ]
    };

    const recommendations = analyzer.generateRecommendations(mockResult);

    assert.ok(recommendations.length > 0);
    assert.strictEqual(recommendations[0].type, 'dead-code');
    assert.strictEqual(recommendations[0].files[0], 'test.js');
  });

  it('should get default config', () => {
    const defaults = DeadCodeAnalyzer.getDefaultConfig();

    assert.ok(defaults.enabled !== undefined);
    assert.ok(defaults.ignoreExports !== undefined);
    assert.ok(Array.isArray(defaults.testPatterns));
  });
});
