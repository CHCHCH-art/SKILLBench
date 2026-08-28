/**
 * AST (Abstract Syntax Tree) utility functions
 * Provides helper functions for working with tree-sitter syntax trees
 */

/**
 * Get node text from source code
 * @param {Object} node - tree-sitter node
 * @param {string} source - Source code
 * @returns {string}
 */
export function getNodeText(node, source) {
  return source.substring(node.startIndex, node.endIndex);
}

/**
 * Get all nodes of a specific type
 * @param {Object} root - Root node
 * @param {string} type - Node type to find
 * @returns {Array<Object>}
 */
export function getNodesByType(root, type) {
  const nodes = [];

  function walk(node) {
    if (node.type === type) {
      nodes.push(node);
    }

    for (const child of node.children || []) {
      walk(child);
    }
  }

  walk(root);
  return nodes;
}

/**
 * Get node ancestors
 * @param {Object} node - tree-sitter node
 * @returns {Array<Object>}
 */
export function getAncestors(node) {
  const ancestors = [];
  let current = node.parent;

  while (current) {
    ancestors.push(current);
    current = current.parent;
  }

  return ancestors;
}

/**
 * Get node at a specific position
 * @param {Object} root - Root node
 * @param {number} row - Row (0-indexed)
 * @param {number} column - Column (0-indexed)
 * @returns {Object|null}
 */
export function getNodeAtPosition(root, row, column) {
  function walk(node) {
    if (!node) return null;

    const { startPosition, endPosition } = node;

    if (row < startPosition.row || (row === startPosition.row && column < startPosition.column)) {
      return null;
    }

    if (row > endPosition.row || (row === endPosition.row && column > endPosition.column)) {
      return null;
    }

    // Check children first (more specific)
    for (const child of node.children || []) {
      const result = walk(child);
      if (result) return result;
    }

    return node;
  }

  return walk(root);
}

/**
 * Extract function declarations from AST
 * @param {Object} root - Root node
 * @param {string} source - Source code
 * @returns {Array<Object>}
 */
export function extractFunctions(root, source) {
  const functions = [];

  function walk(node, parent = null) {
    const functionTypes = [
      'function_declaration',
      'function_expression',
      'arrow_function',
      'method_definition'
    ];

    if (functionTypes.includes(node.type)) {
      // Extract function name
      let name = 'anonymous';
      const nameNode = node.childForFieldName('name');
      if (nameNode) {
        name = getNodeText(nameNode, source);
      }

      functions.push({
        name,
        type: node.type,
        node,
        parent,
        text: getNodeText(node, source),
        startPosition: node.startPosition,
        endPosition: node.endPosition
      });
    }

    for (const child of node.children || []) {
      walk(child, node);
    }
  }

  walk(root);
  return functions;
}

/**
 * Extract variable declarations from AST
 * @param {Object} root - Root node
 * @param {string} source - Source code
 * @returns {Array<Object>}
 */
export function extractVariables(root, source) {
  const variables = [];

  function walk(node) {
    if (node.type === 'variable_declaration' || node.type === 'lexical_declaration') {
      for (const child of node.children) {
        if (child.type === 'variable_declarator') {
          const nameNode = child.childForFieldName('name');
          if (nameNode) {
            variables.push({
              name: getNodeText(nameNode, source),
              node: child,
              text: getNodeText(child, source)
            });
          }
        }
      }
    }

    for (const child of node.children || []) {
      walk(child);
    }
  }

  walk(root);
  return variables;
}

/**
 * Extract import statements from AST
 * @param {Object} root - Root node
 * @param {string} source - Source code
 * @returns {Array<Object>}
 */
export function extractImports(root, source) {
  const imports = [];

  function walk(node) {
    if (node.type === 'import_statement') {
      const sourceNode = node.childForFieldName('source');
      if (sourceNode) {
        imports.push({
          module: getNodeText(sourceNode, source).replace(/['"]/g, ''),
          node,
          text: getNodeText(node, source)
        });
      }
    }

    if (node.type === 'import_require') {
      // CommonJS require
      const args = node.children.filter(c => c.type === 'string');
      for (const arg of args) {
        imports.push({
          module: getNodeText(arg, source).replace(/['"]/g, ''),
          node,
          text: getNodeText(node, source)
        });
      }
    }

    for (const child of node.children || []) {
      walk(child);
    }
  }

  walk(root);
  return imports;
}

/**
 * Extract export declarations from AST
 * @param {Object} root - Root node
 * @param {string} source - Source code
 * @returns {Array<Object>}
 */
export function extractExports(root, source) {
  const exports = [];

  function walk(node) {
    if (node.type === 'export_statement') {
      exports.push({
        node,
        text: getNodeText(node, source)
      });
    }

    for (const child of node.children || []) {
      walk(child);
    }
  }

  walk(root);
  return exports;
}

/**
 * Find all references to a symbol
 * @param {Object} root - Root node
 * @param {string} symbolName - Symbol name to find
 * @returns {Array<Object>}
 */
export function findReferences(root, symbolName) {
  const references = [];

  function walk(node) {
    if (node.type === 'identifier' && node.text === symbolName) {
      references.push({
        node,
        position: node.startPosition
      });
    }

    for (const child of node.children || []) {
      walk(child);
    }
  }

  walk(root);
  return references;
}

/**
 * Calculate cyclomatic complexity
 * @param {Object} node - Function node
 * @returns {number}
 */
export function calculateComplexity(node) {
  let complexity = 1; // Base complexity

  function walk(n) {
    const decisionTypes = [
      'if_statement',
      'else_clause',
      'conditional_expression',
      'for_statement',
      'for_in_statement',
      'while_statement',
      'do_statement',
      'switch_case',
      'catch_clause',
      'logical_and',
      'logical_or'
    ];

    if (decisionTypes.includes(n.type)) {
      complexity++;
    }

    for (const child of n.children || []) {
      walk(child);
    }
  }

  walk(node);
  return complexity;
}

/**
 * Get function length in lines
 * @param {Object} node - Function node
 * @returns {number}
 */
export function getFunctionLength(node) {
  return node.endPosition.row - node.startPosition.row + 1;
}

/**
 * Get maximum nesting depth
 * @param {Object} node - Root node
 * @returns {number}
 */
export function getMaxNestingDepth(node) {
  let maxDepth = 0;

  function walk(n, depth = 0) {
    const nestingTypes = [
      'if_statement',
      'for_statement',
      'for_in_statement',
      'while_statement',
      'do_statement',
      'switch_statement',
      'try_statement',
      'catch_clause'
    ];

    if (nestingTypes.includes(n.type)) {
      depth++;
      maxDepth = Math.max(maxDepth, depth);
    }

    for (const child of n.children || []) {
      walk(child, depth);
    }
  }

  walk(node);
  return maxDepth;
}

/**
 * Normalize code by removing identifiers (for semantic comparison)
 * @param {string} code - Source code
 * @returns {string}
 */
export function normalizeCode(code) {
  // Replace identifiers with placeholder
  return code
    .replace(/\b[a-zA-Z_$][a-zA-Z0-9_$]*\b/g, 'ID')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Compare two AST nodes semantically
 * @param {Object} node1 - First node
 * @param {Object} node2 - Second node
 * @param {string} source1 - First source code
 * @param {string} source2 - Second source code
 * @returns {boolean}
 */
export function areSemanticallySimilar(node1, node2, source1, source2) {
  if (node1.type !== node2.type) {
    return false;
  }

  const normalized1 = normalizeCode(getNodeText(node1, source1));
  const normalized2 = normalizeCode(getNodeText(node2, source2));

  return normalized1 === normalized2;
}

/**
 * Extract comments from source
 * @param {Object} root - Root node
 * @param {string} source - Source code
 * @returns {Array<Object>}
 */
export function extractComments(root, source) {
  const comments = [];

  // Note: tree-sitter doesn't include comments by default
  // This would require extra handling with the tree
  // Placeholder for future implementation

  return comments;
}
