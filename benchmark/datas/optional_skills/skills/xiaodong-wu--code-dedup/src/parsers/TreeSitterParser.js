import * as TSLanguage from 'tree-sitter';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * Tree-sitter parser wrapper
 * Handles loading language parsers and parsing source code
 */
export class TreeSitterParser {
  constructor(options = {}) {
    this.languages = new Map();
    this.options = {
      lazyLoad: true,
      ...options
    };
  }

  /**
   * Load a language parser
   * @param {string} language - Language name
   * @returns {Promise<Object>}
   */
  async loadLanguage(language) {
    if (this.languages.has(language)) {
      return this.languages.get(language);
    }

    try {
      let langModule;

      switch (language) {
        case 'javascript':
        case 'typescript':
          // For JS/TS, we need to use the tree-sitter API
          // Note: This is a simplified implementation
          // In production, you'd dynamically import the actual bindings
          const Parser = await import('tree-sitter');
          const parser = new Parser();

          // Try to load language grammar
          try {
            const JavaScript = await import('tree-sitter-javascript');
            parser.setLanguage(JavaScript);
            this.languages.set(language, { parser, language: JavaScript });
            return this.languages.get(language);
          } catch (err) {
            console.warn(`Failed to load ${language} parser: ${err.message}`);
            // Fallback to basic parsing
            return null;
          }

        case 'python':
          // Python parser would be similar
          // For now, return null to indicate not loaded
          return null;

        default:
          console.warn(`Unsupported language: ${language}`);
          return null;
      }
    } catch (error) {
      console.error(`Failed to load ${language} parser:`, error);
      return null;
    }
  }

  /**
   * Parse source code
   * @param {string} source - Source code to parse
   * @param {string} language - Language name
   * @returns {Promise<Object|null>}
   */
  async parse(source, language) {
    const lang = await this.loadLanguage(language);

    if (!lang) {
      // Fallback: return a simple mock tree structure
      return this._createMockTree(source, language);
    }

    try {
      const tree = lang.parser.parse(source);
      return {
        rootNode: tree.rootNode,
        language,
        source,
        valid: true
      };
    } catch (error) {
      console.warn(`Parsing failed for ${language}: ${error.message}`);
      return this._createMockTree(source, language);
    }
  }

  /**
   * Parse multiple files
   * @param {Map<string, string>} fileContents - Map of filepath -> source
   * @param {Function} languageDetector - Function to detect language from filepath
   * @returns {Promise<Map<string, Object>>}
   */
  async parseFiles(fileContents, languageDetector) {
    const results = new Map();

    for (const [filepath, source] of fileContents.entries()) {
      const language = languageDetector(filepath);
      const tree = await this.parse(source, language);
      results.set(filepath, tree);
    }

    return results;
  }

  /**
   * Check if language is supported
   * @param {string} language
   * @returns {boolean}
   */
  isSupported(language) {
    return ['javascript', 'typescript', 'python'].includes(language);
  }

  /**
   * Create a mock tree for when tree-sitter is not available
   *
   * LIMITATIONS:
   * - Only basic function/class detection via regex
   * - No nested structure detection
   * - No scope information
   * - Only works for simple code patterns
   * - Will fail on complex syntax (template strings, object literals, etc.)
   *
   * @private
   */
  _createMockTree(source, language) {
    // Warn about fallback mode limitations
    if (!this._fallbackWarned) {
      console.warn(
        `Using fallback parser for ${language}. ` +
        `AST-based features (dead code, structure analysis) will be limited. ` +
        `Install tree-sitter language parsers for full functionality.`
      );
      this._fallbackWarned = true;
    }

    const lines = source.split('\n');
    const mockNode = {
      type: 'file',
      startPosition: { row: 0, column: 0 },
      endPosition: { row: lines.length - 1, column: lines[lines.length - 1].length },
      startIndex: 0,
      endIndex: source.length,
      children: [],
      text: source,
      childForFieldName: () => null,
      parent: null
    };

    // Improved regex patterns for better detection
    const patterns = [
      // function name(args) { }
      /function\s+([a-zA-Z_$][a-zA-Z0-9_$]*)\s*\([^)]*\)\s*\{/,
      // const name = (args) => { }
      /(?:const|let|var)\s+([a-zA-Z_$][a-zA-Z0-9_$]*)\s*=\s*(?:async\s*)?\([^)]*\)\s*=>?\s*\{/,
      // export function name(args) { }
      /export\s+(?:async\s+)?function\s+([a-zA-Z_$][a-zA-Z0-9_$]*)/,
      // class name { }
      /class\s+([a-zA-Z_$][a-zA-Z0-9_$]*)/,
      // async function name(args) { }
      /async\s+function\s+([a-zA-Z_$][a-zA-Z0-9_$]*)\s*\([^)]*\)\s*\{/
    ];

    let childId = 0;

    for (const pattern of patterns) {
      let match;
      const regex = new RegExp(pattern, 'g');

      while ((match = regex.exec(source)) !== null) {
        const funcName = match[1] || 'anonymous';
        const startPos = this._getLineAndColumn(source, match.index);
        const funcStart = match.index;
        const funcEnd = this._findFunctionEnd(source, funcStart);
        const endPos = this._getLineAndColumn(source, funcEnd);

        // Skip if we've already added this function
        const alreadyAdded = mockNode.children.some(
          child => child.startIndex === funcStart
        );
        if (alreadyAdded) continue;

        mockNode.children.push({
          type: pattern.includes('class') ? 'class_declaration' : 'function_declaration',
          id: childId++,
          name: funcName,
          startPosition: startPos,
          endPosition: endPos,
          startIndex: funcStart,
          endIndex: funcEnd,
          children: [],
          text: source.substring(funcStart, funcEnd),
          childForFieldName: () => null,
          parent: mockNode
        });
      }
    }

    return {
      rootNode: mockNode,
      language,
      source,
      valid: true,
      isMock: true,
      limitations: [
        'Only basic structure detection',
        'No nested scopes',
        'Limited syntax support',
        'AST features are approximated'
      ]
    };
  }

  /**
   * Get line and column from index
   * @private
   */
  _getLineAndColumn(source, index) {
    const before = source.substring(0, index);
    const lines = before.split('\n');
    return {
      row: lines.length - 1,
      column: lines[lines.length - 1].length
    };
  }

  /**
   * Find the end of a function (simple heuristic)
   * @private
   */
  _findFunctionEnd(source, startIndex) {
    let braceCount = 0;
    let inBraces = false;
    const funcBody = source.substring(startIndex);

    for (let i = 0; i < funcBody.length; i++) {
      const char = funcBody[i];

      if (char === '{') {
        braceCount++;
        inBraces = true;
      } else if (char === '}') {
        braceCount--;
        if (inBraces && braceCount === 0) {
          return startIndex + i + 1;
        }
      }
    }

    // If we can't find the end, return the rest of the file (up to 5000 chars max)
    const maxFunctionSize = Math.min(source.length - startIndex, 5000);
    return startIndex + maxFunctionSize;
  }

  /**
   * Get loaded languages
   * @returns {Array<string>}
   */
  getLoadedLanguages() {
    return Array.from(this.languages.keys());
  }
}

/**
 * Create a default parser instance
 */
export function createParser(options) {
  return new TreeSitterParser(options);
}
