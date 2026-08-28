import { calculateComplexity, getFunctionLength, getMaxNestingDepth } from '../../utils/astUtils.js';
import {
  MAX_CYCLOMATIC_COMPLEXITY,
  MAX_FUNCTION_LENGTH_LINES,
  MAX_FUNCTION_PARAMETERS
} from '../../utils/constants.js';

/**
 * Calculates various code complexity metrics
 */
export class ComplexityCalculator {
  constructor(config = {}) {
    this.maxComplexity = config.maxComplexity ?? MAX_CYCLOMATIC_COMPLEXITY;
    this.maxFunctionLength = config.maxFunctionLength ?? MAX_FUNCTION_LENGTH_LINES;
    this.maxNestingDepth = config.maxNestingDepth ?? 4;
    this.maxParameters = config.maxParameters ?? MAX_FUNCTION_PARAMETERS;
  }

  /**
   * Calculate metrics for a function
   * @param {Object} funcNode - Function AST node
   * @param {string} source - Source code
   * @returns {Object}
   */
  calculateFunctionMetrics(funcNode, source) {
    return {
      complexity: calculateComplexity(funcNode),
      length: getFunctionLength(funcNode),
      nestingDepth: getMaxNestingDepth(funcNode),
      parameterCount: this._countParameters(funcNode, source),
      name: this._extractFunctionName(funcNode, source)
    };
  }

  /**
   * Check if function exceeds thresholds
   * @param {Object} metrics
   * @returns {Object}
   */
  checkThresholds(metrics) {
    const issues = [];

    if (metrics.complexity > this.maxComplexity) {
      issues.push({
        type: 'high-complexity',
        severity: 'high',
        metric: 'complexity',
        value: metrics.complexity,
        threshold: this.maxComplexity,
        message: `Function has cyclomatic complexity of ${metrics.complexity} (threshold: ${this.maxComplexity})`
      });
    }

    if (metrics.length > this.maxFunctionLength) {
      issues.push({
        type: 'long-function',
        severity: 'medium',
        metric: 'length',
        value: metrics.length,
        threshold: this.maxFunctionLength,
        message: `Function is ${metrics.length} lines long (threshold: ${this.maxFunctionLength})`
      });
    }

    if (metrics.nestingDepth > this.maxNestingDepth) {
      issues.push({
        type: 'deep-nesting',
        severity: 'medium',
        metric: 'nestingDepth',
        value: metrics.nestingDepth,
        threshold: this.maxNestingDepth,
        message: `Function has nesting depth of ${metrics.nestingDepth} (threshold: ${this.maxNestingDepth})`
      });
    }

    if (metrics.parameterCount > this.maxParameters) {
      issues.push({
        type: 'too-many-parameters',
        severity: 'low',
        metric: 'parameterCount',
        value: metrics.parameterCount,
        threshold: this.maxParameters,
        message: `Function has ${metrics.parameterCount} parameters (threshold: ${this.maxParameters})`
      });
    }

    return {
      passes: issues.length === 0,
      issues
    };
  }

  /**
   * Calculate file-level metrics
   * @param {Object} tree - Parse tree
   * @param {string} source - Source code
   * @returns {Object}
   */
  calculateFileMetrics(tree, source) {
    if (!tree || !tree.rootNode) {
      return {
        totalLines: source.split('\n').length,
        functionCount: 0,
        avgComplexity: 0,
        maxComplexity: 0
      };
    }

    const functions = this._extractAllFunctions(tree.rootNode, source);

    if (functions.length === 0) {
      return {
        totalLines: source.split('\n').length,
        functionCount: 0,
        avgComplexity: 0,
        maxComplexity: 0
      };
    }

    const complexities = functions.map(f => calculateComplexity(f.node));

    return {
      totalLines: source.split('\n').length,
      functionCount: functions.length,
      avgComplexity: complexities.reduce((a, b) => a + b, 0) / complexities.length,
      maxComplexity: Math.max(...complexities),
      functions: functions.map(f => ({
        name: f.name,
        ...this.calculateFunctionMetrics(f.node, source)
      }))
    };
  }

  /**
   * Extract all functions from tree
   * @private
   */
  _extractAllFunctions(rootNode, source) {
    const functions = [];

    function walk(node) {
      const functionTypes = [
        'function_declaration',
        'function_expression',
        'arrow_function',
        'method_definition'
      ];

      if (functionTypes.includes(node.type)) {
        let name = 'anonymous';
        const nameNode = node.childForFieldName('name');
        if (nameNode) {
          name = source.substring(nameNode.startIndex, nameNode.endIndex);
        }

        functions.push({
          name,
          node
        });
      }

      for (const child of (node.children || [])) {
        walk(child);
      }
    }

    walk(rootNode);
    return functions;
  }

  /**
   * Count function parameters
   * @private
   */
  _countParameters(funcNode, source) {
    const paramsNode = funcNode.childForFieldName('parameters');
    if (!paramsNode) return 0;

    let count = 0;
    for (const child of (paramsNode.children || [])) {
      if (child.type === 'identifier' || child.type === 'parameter') {
        count++;
      }
    }

    return count;
  }

  /**
   * Extract function name
   * @private
   */
  _extractFunctionName(funcNode, source) {
    const nameNode = funcNode.childForFieldName('name');
    if (nameNode) {
      return source.substring(nameNode.startIndex, nameNode.endIndex);
    }

    // Try to find from parent (for methods, etc.)
    if (funcNode.parent) {
      const nameNode = funcNode.parent.childForFieldName('name');
      if (nameNode) {
        return source.substring(nameNode.startIndex, nameNode.endIndex);
      }
    }

    return 'anonymous';
  }
}
