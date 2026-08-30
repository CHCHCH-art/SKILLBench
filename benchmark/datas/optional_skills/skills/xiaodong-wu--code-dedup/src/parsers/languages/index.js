/**
 * Language definitions for tree-sitter parsers
 */

export const LANGUAGE_DEFINITIONS = {
  javascript: {
    extensions: ['.js', '.jsx', '.mjs'],
    parserModule: 'tree-sitter-javascript',
    nodeTypes: {
      function: ['function_declaration', 'function_expression', 'arrow_function', 'method_definition'],
      class: ['class_declaration', 'class_expression'],
      variable: ['variable_declaration', 'lexical_declaration'],
      import: ['import_statement'],
      export: ['export_statement'],
      comment: ['comment']
    }
  },

  typescript: {
    extensions: ['.ts', '.tsx'],
    parserModule: 'tree-sitter-typescript',
    nodeTypes: {
      function: ['function_declaration', 'function_expression', 'arrow_function', 'method_definition'],
      class: ['class_declaration', 'class_expression', 'interface_declaration', 'type_alias_declaration'],
      variable: ['variable_declaration', 'lexical_declaration'],
      import: ['import_statement'],
      export: ['export_statement'],
      comment: ['comment']
    }
  },

  python: {
    extensions: ['.py'],
    parserModule: 'tree-sitter-python',
    nodeTypes: {
      function: ['function_definition'],
      class: ['class_definition'],
      variable: ['assignment', 'annotated_assignment'],
      import: ['import_statement', 'import_from_statement'],
      export: [], // Python doesn't have explicit exports
      comment: ['comment']
    }
  }
};

/**
 * Get language by file extension
 * @param {string} extension
 * @returns {string|null}
 */
export function getLanguageByExtension(extension) {
  const ext = extension.toLowerCase();
  for (const [lang, def] of Object.entries(LANGUAGE_DEFINITIONS)) {
    if (def.extensions.includes(ext)) {
      return lang;
    }
  }
  return null;
}

/**
 * Get all supported extensions
 * @returns {Array<string>}
 */
export function getAllExtensions() {
  const extensions = [];
  for (const def of Object.values(LANGUAGE_DEFINITIONS)) {
    extensions.push(...def.extensions);
  }
  return extensions;
}
