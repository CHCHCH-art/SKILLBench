import { describe, it } from 'node:test';
import assert from 'node:assert';
import { Cache } from '../../src/utils/cache.js';

describe('Cache', () => {
  // Create cache with disk caching disabled to avoid async cleanup issues in tests
  it('should set and get values', async () => {
    const cache = new Cache({ enabled: true, cacheDir: null });
    cache.set('test-key', { value: 'test-data' });
    const result = await cache.get('test-key');
    assert.deepStrictEqual(result, { value: 'test-data' });
  });

  it('should return null for missing keys', async () => {
    const cache = new Cache({ enabled: true, cacheDir: null });
    const result = await cache.get('non-existent-key');
    assert.strictEqual(result, null);
  });

  it('should check if key exists', async () => {
    const cache = new Cache({ enabled: true, cacheDir: null });
    cache.set('exists-key', 'data');
    assert.strictEqual(await cache.has('exists-key'), true);
    assert.strictEqual(await cache.has('non-existent'), false);
  });

  it('should delete entries', async () => {
    const cache = new Cache({ enabled: true, cacheDir: null });
    cache.set('delete-key', 'data');
    assert.strictEqual(await cache.has('delete-key'), true);
    cache.delete('delete-key');
    assert.strictEqual(await cache.has('delete-key'), false);
  });

  it('should clear all entries', async () => {
    const cache = new Cache({ enabled: true, cacheDir: null });
    cache.set('key1', 'data1');
    cache.set('key2', 'data2');
    cache.set('key3', 'data3');
    assert.ok(await cache.has('key1'));
    assert.ok(await cache.has('key2'));
    assert.ok(await cache.has('key3'));

    cache.clear();
    assert.strictEqual(await cache.has('key1'), false);
    assert.strictEqual(await cache.has('key2'), false);
    assert.strictEqual(await cache.has('key3'), false);
  });

  it('should generate consistent keys', () => {
    const cache = new Cache({ enabled: true, cacheDir: null });
    const key1 = cache.generateKey('test-input');
    const key2 = cache.generateKey('test-input');
    const key3 = cache.generateKey('different-input');
    assert.strictEqual(key1, key2);
    assert.notStrictEqual(key1, key3);
  });

  it('should get stats', () => {
    const cache = new Cache({ enabled: true, cacheDir: null });
    const stats = cache.getStats();
    assert.ok(stats.enabled);
    assert.strictEqual(typeof stats.memorySize, 'number');
    assert.ok(stats.maxSize > 0);
  });

  it('should handle complex objects', async () => {
    const cache = new Cache({ enabled: true, cacheDir: null });
    const complex = {
      nested: {
        array: [1, 2, 3],
        string: 'test'
      }
    };
    cache.set('complex-key', complex);
    const result = await cache.get('complex-key');
    assert.deepStrictEqual(result, complex);
  });

  it('should be disabled when configured', async () => {
    const disabledCache = new Cache({ enabled: false, cacheDir: null });
    disabledCache.set('key', 'value');
    assert.strictEqual(await disabledCache.get('key'), null);
  });
});
