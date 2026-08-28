import { BaseAnalyzer } from '../base/BaseAnalyzer.js';
import { ReferenceGraph } from './ReferenceGraph.js';
import { extractFunctions, extractVariables, extractImports, extractExports, findReferences } from '../../utils/astUtils.js';
import { getRelativePath } from '../../utils/fileUtils.js';

/**
 * Dead code detection analyzer
 * Finds unused functions, variables, and imports
 */
export class DeadCodeAnalyzer extends BaseAnalyzer {
  constructor(config = {}) {
    super(config);
  }

  /**
   * Analyze files for dead code
   * @param {Array} files - Array of file paths
   * @param {Object} context - Analysis context
   * @returns {Promise<Object>}
   */
  async analyze(files, context) {
    this.validateContext(context, ['parseTrees', 'baseDir']);

    const parseTrees = context.parseTrees;
    const baseDir = context.baseDir;
    const graph = new ReferenceGraph();

    // Phase 1: Extract all declarations
    for (const [filepath, tree] of parseTrees.entries()) {
      const relativePath = getRelativePath(filepath, baseDir);
      await this._extractDeclarations(tree, relativePath, graph);
    }

    // Phase 2: Extract all references
    for (const [filepath, tree] of parseTrees.entries()) {
      const relativePath = getRelativePath(filepath, baseDir);
      this._extractReferences(tree, relativePath, graph);
    }

    // Phase 3: Find dead code
    const deadCode = graph.findDeadCode({
      ignoreExports: this.config.ignoreExports !== false,
      ignoreTestFiles: this.config.ignoreTestFiles !== false,
      whitelist: this.config.whitelistPatterns || [],
      testPatterns: this.config.testPatterns || []
    });

    // Group by type
    const byType = this._groupByType(deadCode);

    return {
      deadCode,
      byType,
      summary: {
        totalDead: deadCode.length,
        ...byType,
        stats: graph.getStats()
      }
    };
  }

  /**
   * Extract declarations from parse tree
   * @private
   */
  async _extractDeclarations(tree, filepath, graph) {
    if (!tree || !tree.rootNode) return;

    const { rootNode, source } = tree;

    // Extract exports
    const exports = extractExports(rootNode, source);
    const exportedSymbols = new Set();

    for (const exp of exports) {
      // Extract symbol names from export
      const matches = exp.text.match(/export\s+(?:(?:const|let|var|function|class)\s+)?(\w+)/);
      if (matches) {
        exportedSymbols.add(matches[1]);
      }
    }

    // Extract functions
    const functions = extractFunctions(rootNode, source);
    for (const func of functions) {
      graph.addDeclaration(func.name, {
        file: filepath,
        type: 'function',
        line: func.startPosition.row + 1,
        exported: exportedSymbols.has(func.name) || func.name === 'default',
        node: func.node
      });
    }

    // Extract variables
    const variables = extractVariables(rootNode, source);
    for (const variable of variables) {
      graph.addDeclaration(variable.name, {
        file: filepath,
        type: 'variable',
        line: variable.node?.startPosition?.row + 1 || 0,
        exported: exportedSymbols.has(variable.name),
        node: variable.node
      });
    }

    // Extract imports
    const imports = extractImports(rootNode, source);
    for (const imp of imports) {
      // Extract imported symbols
      const namedImports = imp.text.match(/\{\s*([^}]+)\s*\}/);
      if (namedImports) {
        const symbols = namedImports[1].split(',').map(s => s.trim().split(' as ')[0]);
        for (const symbol of symbols) {
          graph.addDeclaration(symbol, {
            file: filepath,
            type: 'import',
            line: imp.node?.startPosition?.row + 1 || 0,
            exported: false,
            node: imp.node
          });
        }
      }

      // Default imports
      const defaultImport = imp.text.match(/import\s+(\w+)/);
      if (defaultImport) {
        graph.addDeclaration(defaultImport[1], {
          file: filepath,
          type: 'import',
          line: imp.node?.startPosition?.row + 1 || 0,
          exported: false,
          node: imp.node
        });
      }
    }
  }

  /**
   * Extract references from parse tree
   * @private
   */
  _extractReferences(tree, filepath, graph) {
    if (!tree || !tree.rootNode) return;

    const { rootNode, source } = tree;

    // Find all identifier references
    function walk(node) {
      if (node.type === 'identifier') {
        const symbol = source.substring(node.startIndex, node.endIndex);

        // Skip if this is a declaration (the identifier itself)
        const parent = node.parent;
        if (parent) {
          const parentType = parent.type;
          // Skip if identifier is being declared
          if (['function_declaration', 'variable_declarator', 'lexical_declaration'].includes(parentType)) {
            const nameNode = parent.childForFieldName('name');
            if (nameNode === node) {
              // This is the declaration, not a reference
              for (const child of (node.children || [])) {
                walk(child);
              }
              return;
            }
          }
        }

        // Add reference
        graph.addReference(symbol, {
          file: filepath,
          line: node.startPosition.row + 1,
          column: node.startPosition.column
        });
      }

      for (const child of (node.children || [])) {
        walk(child);
      }
    }

    walk(rootNode);
  }

  /**
   * Group dead code by type
   * @private
   */
  _groupByType(deadCode) {
    const grouped = {
      functions: [],
      variables: [],
      imports: []
    };

    for (const item of deadCode) {
      if (grouped[item.type]) {
        grouped[item.type].push(item);
      }
    }

    return grouped;
  }

  /**
   * Generate recommendations
   * @param {Object} results
   * @returns {Array}
   */
  generateRecommendations(results) {
    const recommendations = [];

    for (const item of results.deadCode) {
      let priority = 'low';
      let description = '';

      switch (item.type) {
        case 'function':
          priority = 'high';
          description = `Unused function '${item.symbol}' in ${item.file}:${item.line}`;
          break;
        case 'import':
          priority = 'medium';
          description = `Unused import '${item.symbol}' in ${item.file}:${item.line}`;
          break;
        case 'variable':
          priority = 'low';
          description = `Unused variable '${item.symbol}' in ${item.file}:${item.line}`;
          break;
      }

      recommendations.push({
        type: 'dead-code',
        priority,
        description,
        files: [item.file],
        suggestion: `Remove unused ${item.type} '${item.symbol}'`,
        details: {
          symbol: item.symbol,
          itemType: item.type,
          line: item.line
        }
      });
    }

    return recommendations;
  }

  /**
   * Get default configuration
   */
  static getDefaultConfig() {
    return {
      enabled: true,
      ignoreExports: true,
      ignoreTestFiles: true,
      whitelistPatterns: [],
      testPatterns: [
        '**/*.test.js',
        '**/*.spec.js',
        '**/test/**',
        '**/tests/**'
      ]
    };
  }
}
