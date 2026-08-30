/**
 * Reference graph for tracking symbol usage
 * Maps declarations to their references
 */
export class ReferenceGraph {
  constructor() {
    this.declarations = new Map(); // symbol -> { file, type, node, exported }
    this.references = new Map();    // symbol -> [{ file, location }]
    this.exports = new Set();       // Set of exported symbols
  }

  /**
   * Add a declaration
   * @param {string} symbol - Symbol name
   * @param {Object} info - Declaration info
   */
  addDeclaration(symbol, info) {
    this.declarations.set(symbol, {
      symbol,
      file: info.file,
      type: info.type || 'unknown',
      line: info.line,
      exported: info.exported || false,
      node: info.node || null
    });

    if (info.exported) {
      this.exports.add(symbol);
    }
  }

  /**
   * Add a reference to a symbol
   * @param {string} symbol - Symbol being referenced
   * @param {Object} info - Reference info
   */
  addReference(symbol, info) {
    if (!this.references.has(symbol)) {
      this.references.set(symbol, []);
    }

    this.references.get(symbol).push({
      file: info.file,
      line: info.line,
      column: info.column
    });
  }

  /**
   * Add multiple references
   * @param {string} symbol
   * @param {Array} refs
   */
  addReferences(symbol, refs) {
    if (!this.references.has(symbol)) {
      this.references.set(symbol, []);
    }

    this.references.get(symbol).push(...refs);
  }

  /**
   * Get declaration info
   * @param {string} symbol
   * @returns {Object|null}
   */
  getDeclaration(symbol) {
    return this.declarations.get(symbol) || null;
  }

  /**
   * Get references for a symbol
   * @param {string} symbol
   * @returns {Array}
   */
  getReferences(symbol) {
    return this.references.get(symbol) || [];
  }

  /**
   * Get reference count for a symbol
   * @param {string} symbol
   * @returns {number}
   */
  getReferenceCount(symbol) {
    return this.getReferences(symbol).length;
  }

  /**
   * Check if symbol is exported
   * @param {string} symbol
   * @returns {boolean}
   */
  isExported(symbol) {
    const decl = this.getDeclaration(symbol);
    return decl ? decl.exported : false;
  }

  /**
   * Find dead code (symbols with no references)
   * @param {Object} options
   * @returns {Array}
   */
  findDeadCode(options = {}) {
    const {
      ignoreExports = true,
      ignoreTestFiles = true,
      whitelist = [],
      testPatterns = []
    } = options;

    const dead = [];

    for (const [symbol, decl] of this.declarations.entries()) {
      // Skip whitelisted symbols
      if (whitelist.includes(symbol)) {
        continue;
      }

      // Skip exported symbols if configured
      if (ignoreExports && decl.exported) {
        continue;
      }

      // Skip test files if configured
      if (ignoreTestFiles && this._isTestFile(decl.file, testPatterns)) {
        continue;
      }

      // Skip special symbols (constructors, lifecycle methods, etc.)
      if (this._isSpecialSymbol(symbol, decl.type)) {
        continue;
      }

      // Check if symbol has no references
      const refs = this.getReferences(symbol);
      if (refs.length === 0) {
        dead.push({
          symbol,
          ...decl,
          referenceCount: 0
        });
      }
    }

    return dead;
  }

  /**
   * Get graph statistics
   * @returns {Object}
   */
  getStats() {
    return {
      totalDeclarations: this.declarations.size,
      totalReferences: Array.from(this.references.values())
        .reduce((sum, refs) => sum + refs.length, 0),
      exportedSymbols: this.exports.size,
      symbolsWithNoRefs: Array.from(this.declarations.entries())
        .filter(([symbol]) => this.getReferenceCount(symbol) === 0)
        .length
    };
  }

  /**
   * Merge another reference graph into this one
   * @param {ReferenceGraph} other
   */
  merge(other) {
    // Merge declarations
    for (const [symbol, decl] of other.declarations.entries()) {
      if (!this.declarations.has(symbol)) {
        this.declarations.set(symbol, decl);
      }
    }

    // Merge references
    for (const [symbol, refs] of other.references.entries()) {
      this.addReferences(symbol, refs);
    }

    // Merge exports
    for (const symbol of other.exports) {
      this.exports.add(symbol);
    }
  }

  /**
   * Clear the graph
   */
  clear() {
    this.declarations.clear();
    this.references.clear();
    this.exports.clear();
  }

  /**
   * Check if file is a test file
   * @private
   */
  _isTestFile(filepath, patterns) {
    const filename = filepath.toLowerCase();

    // Check filename
    if (filename.includes('.test.') || filename.includes('.spec.')) {
      return true;
    }

    // Check patterns
    for (const pattern of patterns) {
      const regex = new RegExp(pattern.replace(/\*/g, '.*'));
      if (regex.test(filepath)) {
        return true;
      }
    }

    return false;
  }

  /**
   * Check if symbol is special (should not be flagged as dead)
   * @private
   */
  _isSpecialSymbol(symbol, type) {
    // Constructor
    if (symbol === 'constructor') return true;

    // Common lifecycle methods
    const lifecycleMethods = [
      'componentDidMount',
      'componentDidUpdate',
      'componentWillUnmount',
      'render',
      'useEffect',
      'useState',
      'useRef',
      'useCallback',
      'useMemo'
    ];

    if (lifecycleMethods.includes(symbol)) return true;

    // Event handlers (on* pattern)
    if (symbol.startsWith('on') && symbol.length > 2) {
      const secondChar = symbol[2];
      if (secondChar === secondChar.toUpperCase()) {
        return true;
      }
    }

    return false;
  }

  /**
   * Export graph as JSON
   * @returns {Object}
   */
  toJSON() {
    return {
      declarations: Array.from(this.declarations.entries()),
      references: Array.from(this.references.entries()),
      exports: Array.from(this.exports),
      stats: this.getStats()
    };
  }
}
