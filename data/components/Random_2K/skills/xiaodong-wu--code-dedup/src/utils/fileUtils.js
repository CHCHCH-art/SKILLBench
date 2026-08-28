import { glob } from 'glob';
import { readFile, stat, realpath } from 'fs/promises';
import { resolve, join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { FileSystemError, SecurityError, wrapError } from './errors.js';
import { MAX_FILE_SIZE_BYTES } from './constants.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * Get file extension
 * @param {string} filepath
 * @returns {string}
 */
export function getExtension(filepath) {
  const match = filepath.match(/\.([^.]+)$/);
  return match ? match[1].toLowerCase() : '';
}

/**
 * Detect programming language from file extension
 * @param {string} filepath
 * @returns {string}
 */
export function detectLanguage(filepath) {
  const ext = getExtension(filepath);
  const langMap = {
    'js': 'javascript',
    'jsx': 'javascript',
    'ts': 'typescript',
    'tsx': 'typescript',
    'py': 'python',
    'java': 'java',
    'go': 'go',
    'rs': 'rust',
    'c': 'c',
    'cpp': 'cpp',
    'cc': 'cpp',
    'h': 'c',
    'hpp': 'cpp'
  };
  return langMap[ext] || 'javascript';
}

/**
 * Check if file should be excluded based on patterns
 * @param {string} filepath
 * @param {Array} excludePatterns
 * @returns {boolean}
 */
export function shouldExclude(filepath, excludePatterns = []) {
  const normalizedPath = filepath.replace(/\\/g, '/');

  for (const pattern of excludePatterns) {
    let regexStr = pattern;
    let prefix = '';

    // Handle ** at the beginning specially (matches zero or more path segments)
    if (regexStr.startsWith('**/')) {
      prefix = '(?:.*/)?';
      regexStr = regexStr.substring(3);
    }

    // Use a placeholder for ** to avoid conflict with single *
    regexStr = regexStr.replace(/\*\*/g, '<<<DOUBLESTAR>>>');

    // Escape dots and replace single * (only in the pattern, not in the prefix)
    regexStr = regexStr.replace(/\./g, '\\.').replace(/\*/g, '[^/]*');

    // Replace placeholder with .*
    regexStr = regexStr.replace(/<<<DOUBLESTAR>>>/g, '.*');

    const regex = new RegExp('^' + prefix + regexStr);
    if (regex.test(normalizedPath)) {
      return true;
    }
  }
  return false;
}

/**
 * Check if file is a test file
 * @param {string} filepath
 * @param {Array} testPatterns
 * @returns {boolean}
 */
export function isTestFile(filepath, testPatterns = []) {
  const filename = filepath.split('/').pop().toLowerCase();
  const defaultTestPatterns = [
    '**/*.test.js',
    '**/*.spec.js',
    '**/*.test.ts',
    '**/*.spec.ts',
    '**/test/**',
    '**/tests/**',
    '**/__tests__/**'
  ];

  const allPatterns = [...defaultTestPatterns, ...testPatterns];

  // Check filename first (fast path)
  if (filename.includes('.test.') || filename.includes('.spec.')) {
    return true;
  }

  // Check patterns
  for (const pattern of allPatterns) {
    // Convert glob pattern to regex
    let regexPattern = pattern
      .replace(/\./g, '\\.')  // Escape dots
      .replace(/\*\*/g, '.*')  // ** becomes .*
      .replace(/\*/g, '[^/]*'); // * becomes [^/]* (match within path segment)

    const regex = new RegExp('^' + regexPattern + '$');
    if (regex.test(filepath)) {
      return true;
    }
  }

  // Also check if file is in a test directory
  const segments = filepath.split('/');
  for (const segment of segments) {
    if (segment === 'test' || segment === 'tests' || segment === '__tests__') {
      return true;
    }
  }

  return false;
}

/**
 * Scan directory for files matching patterns
 * @param {string} rootPath
 * @param {Object} options
 * @returns {Promise<Array<string>>}
 */
export async function scanFiles(rootPath, options = {}) {
  const {
    include = ['**/*.js', '**/*.ts', '**/*.jsx', '**/*.tsx'],
    exclude = ['**/node_modules/**', '**/dist/**', '**/build/**', '**/.git/**'],
    ignoreTests = false,
    testPatterns = [],
    maxFileSize = MAX_FILE_SIZE_BYTES,
    validatePaths = true
  } = options;

  // Validate root path
  if (validatePaths) {
    await validatePath(rootPath);
  }

  const files = await glob(include, {
    cwd: rootPath,
    absolute: true,
    ignore: exclude
  });

  // Filter by file size and validity
  const validFiles = [];
  for (const file of files) {
    try {
      await validateFileSize(file, maxFileSize);
      validFiles.push(file);
    } catch (error) {
      console.warn(`Skipping ${file}: ${error.message}`);
    }
  }

  if (ignoreTests) {
    return validFiles.filter(f => !isTestFile(f, testPatterns));
  }

  return validFiles;
}

/**
 * Read file content with encoding detection
 * @param {string} filepath
 * @returns {Promise<string>}
 */
export async function readFileContent(filepath) {
  try {
    return await readFile(filepath, 'utf-8');
  } catch (error) {
    throw wrapError(error, `Failed to read file: ${filepath}`, 'FILE_READ_ERROR', { filepath });
  }
}

/**
 * Read multiple files in parallel
 * @param {Array<string>} filepaths
 * @returns {Promise<Map<string, string>>}
 */
export async function readFiles(filepaths) {
  const contents = new Map();

  await Promise.all(
    filepaths.map(async filepath => {
      try {
        const content = await readFileContent(filepath);
        contents.set(filepath, content);
      } catch (error) {
        // Skip files that can't be read
        console.warn(`Skipping ${filepath}: ${error.message}`);
      }
    })
  );

  return contents;
}

/**
 * Get file stats
 * @param {string} filepath
 * @returns {Promise<Object>}
 */
export async function getFileStats(filepath) {
  try {
    const stats = await stat(filepath);
    return {
      size: stats.size,
      mtime: stats.mtime,
      isFile: stats.isFile()
    };
  } catch (error) {
    return null;
  }
}

/**
 * Count lines in file content
 * @param {string} content
 * @returns {Object} { total, blank, code, comment }
 */
export function countLines(content, language = 'javascript') {
  const lines = content.split('\n');
  const result = {
    total: lines.length,
    blank: 0,
    code: 0,
    comment: 0
  };

  const commentPatterns = {
    javascript: /^\s*\/\//,
    typescript: /^\s*\/\//,
    python: /^\s*#/,
    java: /^\s*\/\//,
    go: /^\s*\/\//
  };

  const commentRegex = commentPatterns[language] || /^\s*\/\//;

  for (const line of lines) {
    if (line.trim() === '') {
      result.blank++;
    } else if (commentRegex.test(line)) {
      result.comment++;
    } else {
      result.code++;
    }
  }

  return result;
}

/**
 * Normalize line endings
 * @param {string} content
 * @returns {string}
 */
export function normalizeLineEndings(content) {
  return content.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
}

/**
 * Get relative path from base
 * @param {string} filepath
 * @param {string} base
 * @returns {string}
 */
export function getRelativePath(filepath, base) {
  // Resolve and validate both paths
  const resolvedFile = resolve(filepath);
  const resolvedBase = resolve(base);

  // Ensure resolvedFile is within resolvedBase (or equal)
  const relative = resolvedFile.replace(resolvedBase + '/', '');
  if (relative.includes('..')) {
    // Path is outside base, return absolute path for safety
    return resolvedFile;
  }

  return relative;
}

/**
 * Validate that a path is safe and within allowed directories
 * @param {string} filepath - Path to validate
 * @param {Array} allowedRoots - Allowed root directories (absolute paths)
 * @returns {Promise<string>} Validated, resolved path
 * @throws {SecurityError} If path is unsafe or outside allowed roots
 */
export async function validatePath(filepath, allowedRoots = []) {
  const resolved = resolve(filepath);

  // Resolve to real path (follow symlinks)
  let realPath;
  try {
    realPath = await realpath(resolved);
  } catch {
    // Path doesn't exist, return the resolved path anyway
    realPath = resolved;
  }

  // If no allowed roots specified, only basic validation
  if (allowedRoots.length === 0) {
    // Don't allow obvious system paths
    const dangerous = [
      '/etc', '/sys', '/proc', '/dev', '/root',
      '/bin', '/sbin', '/usr/bin', '/usr/sbin',
      'C:\\Windows', 'C:\\Program Files'
    ];

    const lowerPath = realPath.toLowerCase();
    for (const danger of dangerous) {
      if (lowerPath.startsWith(danger.toLowerCase())) {
        throw new SecurityError(
          `Access denied: cannot access system directory`,
          { filepath, realPath, systemPath: danger }
        );
      }
    }

    return realPath;
  }

  // Check if path is within allowed roots
  let withinAllowed = false;
  for (const root of allowedRoots) {
    const resolvedRoot = resolve(root);
    if (realPath.startsWith(resolvedRoot + '/') || realPath === resolvedRoot) {
      withinAllowed = true;
      break;
    }
  }

  if (!withinAllowed) {
    throw new SecurityError(
      `Access denied: path is outside allowed directories`,
      { filepath, realPath, allowedRoots }
    );
  }

  return realPath;
}

/**
 * Validate file size to prevent DoS
 * @param {string} filepath - Path to file
 * @param {number} maxSizeBytes - Maximum file size in bytes (default: 10MB)
 * @returns {Promise<Object>} File stats
 * @throws {FileSystemError} If file is too large or not accessible
 */
export async function validateFileSize(filepath, maxSizeBytes = MAX_FILE_SIZE_BYTES) {
  const stats = await getFileStats(filepath);
  if (!stats) {
    throw new FileSystemError(
      `Cannot access file`,
      { filepath, reason: 'File not accessible or does not exist' }
    );
  }

  if (!stats.isFile) {
    throw new FileSystemError(
      `Path is not a file`,
      { filepath, fileType: stats.isDirectory() ? 'directory' : 'unknown' }
    );
  }

  if (stats.size > maxSizeBytes) {
    const sizeMB = (stats.size / 1024 / 1024).toFixed(2);
    const maxMB = (maxSizeBytes / 1024 / 1024).toFixed(2);
    throw new FileSystemError(
      `File too large: ${sizeMB}MB exceeds maximum ${maxMB}MB`,
      { filepath, sizeBytes: stats.size, maxSizeBytes }
    );
  }

  return stats;
}

