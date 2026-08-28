import { mkdir, writeFile, readFile, readdir, unlink } from 'fs/promises';
import { existsSync } from 'fs';
import { resolve, join } from 'path';
import { createHash } from 'crypto';

/**
 * Simple in-memory cache with optional disk persistence
 */
export class Cache {
  constructor(options = {}) {
    this.memoryCache = new Map();
    this.enabled = options.enabled !== false;
    // Disable disk caching if explicitly set to null or false
    this.diskCacheEnabled = options.cacheDir !== null && options.cacheDir !== false;
    // Set cacheDir (only used if diskCacheEnabled is true)
    this.cacheDir = this.diskCacheEnabled && options.cacheDir !== undefined
      ? options.cacheDir
      : '.cache/code-dedup';
    this.maxSize = options.maxSize || 1000;
    this.ttl = options.ttl || 3600000; // 1 hour default
  }

  /**
   * Generate cache key from input
   * @param {*} input
   * @returns {string}
   */
  generateKey(input) {
    const str = typeof input === 'string' ? input : JSON.stringify(input);
    return createHash('md5').update(str).digest('hex');
  }

  /**
   * Get value from cache
   * @param {string} key
   * @returns {Promise<*>}
   */
  async get(key) {
    if (!this.enabled) return null;

    const cacheKey = this.generateKey(key);

    // Check memory cache first
    const memEntry = this.memoryCache.get(cacheKey);
    if (memEntry) {
      if (Date.now() - memEntry.timestamp < this.ttl) {
        return memEntry.value;
      } else {
        this.memoryCache.delete(cacheKey);
      }
    }

    // Check disk cache only if enabled
    if (this.diskCacheEnabled && existsSync(join(this.cacheDir, cacheKey))) {
      try {
        const content = await readFile(join(this.cacheDir, cacheKey), 'utf8');
        const data = JSON.parse(content);
        if (Date.now() - data.timestamp < this.ttl) {
          // Store in memory for faster access next time
          this.memoryCache.set(cacheKey, data);
          return data.value;
        } else {
          // Expired, remove from disk
          unlink(join(this.cacheDir, cacheKey)).catch(() => {});
        }
      } catch (error) {
        // Invalid cache file, ignore
      }
    }

    return null;
  }

  /**
   * Set value in cache
   * @param {string} key
   * @param {*} value
   * @returns {boolean}
   */
  set(key, value) {
    if (!this.enabled) return false;

    const cacheKey = this.generateKey(key);

    // Check memory cache size
    if (this.memoryCache.size >= this.maxSize) {
      this._evictOldest();
    }

    // Store in memory
    this.memoryCache.set(cacheKey, {
      value,
      timestamp: Date.now()
    });

    // Persist to disk only if enabled
    if (this.diskCacheEnabled) {
      this._persistToDisk(cacheKey, value).catch(err => {
        console.warn(`Failed to persist cache to disk: ${err.message}`);
      });
    }

    return true;
  }

  /**
   * Check if key exists in cache
   * @param {string} key
   * @returns {Promise<boolean>}
   */
  async has(key) {
    const result = await this.get(key);
    return result !== null;
  }

  /**
   * Delete entry from cache
   * @param {string} key
   */
  delete(key) {
    const cacheKey = this.generateKey(key);
    this.memoryCache.delete(cacheKey);

    if (this.diskCacheEnabled) {
      const diskPath = join(this.cacheDir, cacheKey);
      if (existsSync(diskPath)) {
        unlink(diskPath).catch(() => {});
      }
    }
  }

  /**
   * Clear all cache entries
   */
  async clear() {
    this.memoryCache.clear();

    if (this.diskCacheEnabled && existsSync(this.cacheDir)) {
      try {
        const files = await readdir(this.cacheDir);
        await Promise.all(
          files.map(f => unlink(join(this.cacheDir, f)))
        );
      } catch (error) {
        console.warn(`Failed to clear disk cache: ${error.message}`);
      }
    }
  }

  /**
   * Get cache statistics
   * @returns {Object}
   */
  getStats() {
    return {
      memorySize: this.memoryCache.size,
      maxSize: this.maxSize,
      enabled: this.enabled
    };
  }

  /**
   * Evict oldest entry from memory cache
   * @private
   */
  _evictOldest() {
    let oldestKey = null;
    let oldestTime = Infinity;

    for (const [key, entry] of this.memoryCache.entries()) {
      if (entry.timestamp < oldestTime) {
        oldestTime = entry.timestamp;
        oldestKey = key;
      }
    }

    if (oldestKey) {
      this.memoryCache.delete(oldestKey);
    }
  }

  /**
   * Persist cache entry to disk
   * @private
   */
  async _persistToDisk(cacheKey, value) {
    try {
      if (!existsSync(this.cacheDir)) {
        await mkdir(this.cacheDir, { recursive: true });
      }

      const data = {
        value,
        timestamp: Date.now()
      };

      await writeFile(
        join(this.cacheDir, cacheKey),
        JSON.stringify(data),
        'utf8'
      );
    } catch (error) {
      // Disk cache is optional, fail silently
    }
  }

  /**
   * Warm up cache with existing disk entries
   */
  async warmup() {
    if (!existsSync(this.cacheDir)) return;

    try {
      const files = await readdir(this.cacheDir);

      for (const file of files) {
        try {
          const data = JSON.parse(
            await readFile(join(this.cacheDir, file), 'utf8')
          );

          // Check if not expired
          if (Date.now() - data.timestamp < this.ttl) {
            this.memoryCache.set(file, data);
          }
        } catch (error) {
          // Skip invalid files
        }
      }
    } catch (error) {
      console.warn(`Cache warmup failed: ${error.message}`);
    }
  }
}

/**
 * Create a default cache instance
 */
export function createCache(options) {
  return new Cache(options);
}
