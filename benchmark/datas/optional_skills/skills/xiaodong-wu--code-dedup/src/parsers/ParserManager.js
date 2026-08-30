import { createParser } from './TreeSitterParser.js';
import { detectLanguage } from '../utils/fileUtils.js';

/**
 * Manages parsers and provides unified parsing interface
 */
export class ParserManager {
  constructor(options = {}) {
    this.parser = createParser(options);
    this.cache = options.cache || null;
    this.defaultLanguage = options.defaultLanguage || 'javascript';
  }

  /**
   * Parse a single file
   * @param {string} filepath - Path to file
   * @param {string} source - Source code content
   * @param {string} language - Language override (optional)
   * @returns {Promise<Object>}
   */
  async parseFile(filepath, source, language = null) {
    const lang = language || detectLanguage(filepath);

    // Check cache
    if (this.cache) {
      const cacheKey = { type: 'parse', filepath, language: lang, source };
      const cached = this.cache.get(cacheKey);
      if (cached) {
        return cached;
      }
    }

    // Parse
    const result = await this.parser.parse(source, lang);

    // Cache result
    if (this.cache && result) {
      const cacheKey = { type: 'parse', filepath, language: lang, source };
      this.cache.set(cacheKey, result);
    }

    return result;
  }

  /**
   * Parse multiple files
   * @param {Map<string, string>} fileContents - filepath -> source mapping
   * @returns {Promise<Map<string, Object>>}
   */
  async parseFiles(fileContents) {
    const results = new Map();

    for (const [filepath, source] of fileContents.entries()) {
      const result = await this.parseFile(filepath, source);
      results.set(filepath, result);
    }

    return results;
  }

  /**
   * Get language for a file
   * @param {string} filepath
   * @returns {string}
   */
  getLanguage(filepath) {
    return detectLanguage(filepath);
  }

  /**
   * Check if language is supported
   * @param {string} language
   * @returns {boolean}
   */
  isLanguageSupported(language) {
    return this.parser.isSupported(language);
  }

  /**
   * Get supported languages
   * @returns {Array<string>}
   */
  getSupportedLanguages() {
    return ['javascript', 'typescript', 'python'];
  }

  /**
   * Clear parser cache
   */
  clearCache() {
    if (this.cache) {
      this.cache.clear();
    }
  }

  /**
   * Get parser statistics
   * @returns {Object}
   */
  getStats() {
    return {
      loadedLanguages: this.parser.getLoadedLanguages(),
      cacheStats: this.cache ? this.cache.getStats() : null
    };
  }
}

/**
 * Create a parser manager instance
 */
export function createParserManager(options) {
  return new ParserManager(options);
}
