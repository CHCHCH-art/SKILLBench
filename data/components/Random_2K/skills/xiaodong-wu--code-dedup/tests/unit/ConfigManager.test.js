import { describe, it } from 'node:test';
import assert from 'node:assert';
import { ConfigManager } from '../../src/core/ConfigManager.js';

describe('ConfigManager', () => {
  it('should create with default config', () => {
    const config = new ConfigManager();
    assert.strictEqual(config.get('analyses').length, 3);
    assert.strictEqual(config.get('dedup.minLines'), 5);
  });

  it('should merge user config with defaults', () => {
    const config = new ConfigManager({
      dedup: {
        minLines: 10
      }
    });
    assert.strictEqual(config.get('dedup.minLines'), 10);
    assert.strictEqual(config.get('dedup.minSimilarity'), 0.85);
  });

  it('should get nested values', () => {
    const config = new ConfigManager();
    assert.strictEqual(config.get('dedup.minLines'), 5);
    assert.strictEqual(config.get('performance.maxParallel'), 4);
  });

  it('should set nested values', () => {
    const config = new ConfigManager();
    config.set('dedup.minLines', 15);
    assert.strictEqual(config.get('dedup.minLines'), 15);
  });

  it('should check if analyzer is enabled', () => {
    const config = new ConfigManager();
    assert.strictEqual(config.isAnalyzerEnabled('dedup'), true);
    assert.strictEqual(config.isAnalyzerEnabled('deadCode'), true);
    assert.strictEqual(config.isAnalyzerEnabled('structure'), true);
  });

  it('should validate configuration', () => {
    const config = new ConfigManager();
    const validation = config.validate();
    assert.strictEqual(validation.valid, true);
    assert.strictEqual(validation.errors.length, 0);
  });

  it('should detect invalid minSimilarity', () => {
    const config = new ConfigManager({
      dedup: {
        minSimilarity: 1.5
      }
    });
    const validation = config.validate();
    assert.strictEqual(validation.valid, false);
  });

  it('should return default config statically', () => {
    const defaults = ConfigManager.getDefaultConfig();
    assert.ok(defaults.analyses);
    assert.ok(defaults.dedup);
    assert.ok(defaults.deadCode);
    assert.ok(defaults.structure);
  });
});
