/**
 * Custom error classes for consistent error handling
 */

/**
 * Base error class for all code-dedup errors
 */
export class CodeDedupError extends Error {
  constructor(message, code = 'UNKNOWN_ERROR', context = {}) {
    super(message);
    this.name = this.constructor.name;
    this.code = code;
    this.context = context;
    this.timestamp = new Date().toISOString();

    // Maintains proper stack trace for where our error was thrown (only available on V8)
    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, this.constructor);
    }
  }

  /**
   * Get a formatted error message with context
   */
  getFormattedMessage() {
    let msg = `[${this.code}] ${this.message}`;

    if (Object.keys(this.context).length > 0) {
      const contextStr = Object.entries(this.context)
        .map(([key, value]) => `${key}=${JSON.stringify(value)}`)
        .join(', ');
      msg += `\nContext: ${contextStr}`;
    }

    return msg;
  }

  /**
   * Convert to JSON for logging/serialization
   */
  toJSON() {
    return {
      name: this.name,
      code: this.code,
      message: this.message,
      context: this.context,
      timestamp: this.timestamp,
      stack: this.stack
    };
  }
}

/**
 * Validation error - invalid input or parameters
 */
export class ValidationError extends CodeDedupError {
  constructor(message, context = {}) {
    super(message, 'VALIDATION_ERROR', context);
  }
}

/**
 * File system error - problems reading/writing files
 */
export class FileSystemError extends CodeDedupError {
  constructor(message, context = {}) {
    super(message, 'FILESYSTEM_ERROR', context);
  }
}

/**
 * Parse error - problems parsing source code
 */
export class ParseError extends CodeDedupError {
  constructor(message, context = {}) {
    super(message, 'PARSE_ERROR', context);
  }
}

/**
 * Analysis error - problems during code analysis
 */
export class AnalysisError extends CodeDedupError {
  constructor(message, context = {}) {
    super(message, 'ANALYSIS_ERROR', context);
  }
}

/**
 * Configuration error - invalid configuration
 */
export class ConfigurationError extends CodeDedupError {
  constructor(message, context = {}) {
    super(message, 'CONFIGURATION_ERROR', context);
  }
}

/**
 * Security error - security-related issues (path traversal, etc.)
 */
export class SecurityError extends CodeDedupError {
  constructor(message, context = {}) {
    super(message, 'SECURITY_ERROR', context);
  }
}

/**
 * Wrap an existing error with additional context
 * @param {Error} error - Original error
 * @param {string} message - New message
 * @param {string} code - Error code
 * @param {Object} context - Additional context
 * @returns {CodeDedupError}
 */
export function wrapError(error, message, code = 'WRAPPED_ERROR', context = {}) {
  const wrappedError = new CodeDedupError(message, code, {
    ...context,
    originalMessage: error.message,
    originalName: error.name,
    originalStack: error.stack
  });

  // Preserve the original cause
  wrappedError.cause = error;

  return wrappedError;
}

/**
 * Create a validation error with parameter context
 * @param {string} paramName - Parameter name
 * @param {string} reason - Why it's invalid
 * @param {any} value - The invalid value
 * @param {Object} extraContext - Additional context
 * @returns {ValidationError}
 */
export function createValidationError(paramName, reason, value, extraContext = {}) {
  const message = `Invalid parameter '${paramName}': ${reason}`;
  return new ValidationError(message, {
    parameter: paramName,
    value: value,
    ...extraContext
  });
}
