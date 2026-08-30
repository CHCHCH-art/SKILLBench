import { describe, it } from 'node:test';
import assert from 'node:assert';
import { AnalysisResult } from '../../src/core/AnalysisResult.js';

describe('AnalysisResult', () => {
  it('should create with default values', () => {
    const result = new AnalysisResult();
    assert.strictEqual(result.summary.status, 'success');
    assert.strictEqual(result.summary.filesAnalyzed, 0);
    assert.strictEqual(result.summary.issuesFound, 0);
    assert.deepStrictEqual(result.results, {});
    assert.deepStrictEqual(result.recommendations, []);
  });

  it('should set status', () => {
    const result = new AnalysisResult();
    result.setStatus('warning');
    assert.strictEqual(result.summary.status, 'warning');
  });

  it('should set files analyzed', () => {
    const result = new AnalysisResult();
    result.setFilesAnalyzed(42);
    assert.strictEqual(result.summary.filesAnalyzed, 42);
  });

  it('should add issues', () => {
    const result = new AnalysisResult();
    result.addIssues(5);
    assert.strictEqual(result.summary.issuesFound, 5);
    result.addIssues(3);
    assert.strictEqual(result.summary.issuesFound, 8);
  });

  it('should add result', () => {
    const result = new AnalysisResult();
    result.addResult('dedup', { duplicates: [] });
    assert.ok(result.results.dedup);
    assert.deepStrictEqual(result.results.dedup, { duplicates: [] });
  });

  it('should add recommendation', () => {
    const result = new AnalysisResult();
    result.addRecommendation({
      type: 'refactor',
      priority: 'high',
      description: 'Test recommendation',
      suggestion: 'Fix this'
    });
    assert.strictEqual(result.recommendations.length, 1);
    assert.strictEqual(result.recommendations[0].priority, 'high');
  });

  it('should sort recommendations by priority', () => {
    const result = new AnalysisResult();
    result.addRecommendation({
      type: 'test',
      priority: 'low',
      description: 'Low priority'
    });
    result.addRecommendation({
      type: 'test',
      priority: 'high',
      description: 'High priority'
    });
    result.addRecommendation({
      type: 'test',
      priority: 'medium',
      description: 'Medium priority'
    });

    const built = result.build();
    assert.strictEqual(built.recommendations[0].priority, 'high');
    assert.strictEqual(built.recommendations[1].priority, 'medium');
    assert.strictEqual(built.recommendations[2].priority, 'low');
  });

  it('should build result with duration', () => {
    const result = new AnalysisResult();
    result.setFilesAnalyzed(10).addIssues(5);
    const built = result.build();
    assert.ok(built.summary.durationMs >= 0);
    assert.strictEqual(built.summary.filesAnalyzed, 10);
    assert.strictEqual(built.summary.issuesFound, 5);
  });

  it('should mark as failed', () => {
    const result = new AnalysisResult();
    result.markFailed('Test error');
    const built = result.build();
    assert.strictEqual(built.summary.status, 'error');
    assert.strictEqual(built.errors.length, 1);
  });

  it('should create success statically', () => {
    const result = AnalysisResult.success({
      filesAnalyzed: 100,
      issuesFound: 25
    });
    assert.strictEqual(result.summary.status, 'success');
    assert.strictEqual(result.summary.filesAnalyzed, 100);
    assert.strictEqual(result.summary.issuesFound, 25);
  });

  it('should create failure statically', () => {
    const error = new Error('Test error');
    const result = AnalysisResult.failure(error);
    assert.strictEqual(result.summary.status, 'error');
    assert.strictEqual(result.errors.length, 1);
    assert.ok(result.errors[0].stack);
  });
});
