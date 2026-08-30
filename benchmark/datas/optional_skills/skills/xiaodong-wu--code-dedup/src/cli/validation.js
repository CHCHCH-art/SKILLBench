/**
 * CLI validation utilities
 */

import { ValidationError, createValidationError } from '../utils/errors.js';

/**
 * Validate and parse a number parameter
 * @param {string} value - String value to parse
 * @param {string} paramName - Parameter name for error messages
 * @param {Object} options - Validation options
 * @returns {number} Parsed and validated number
 * @throws {ValidationError} If validation fails
 */
export function validateNumber(value, paramName, options = {}) {
  const {
    min = -Infinity,
    max = Infinity,
    integer = false,
    required = false
  } = options;

  if (value === undefined || value === null) {
    if (required) {
      throw createValidationError(paramName, 'parameter is required', value);
    }
    return undefined;
  }

  const num = parseFloat(value);

  if (isNaN(num)) {
    throw createValidationError(paramName, 'must be a valid number', value);
  }

  if (integer && !Number.isInteger(num)) {
    throw createValidationError(paramName, 'must be an integer', value);
  }

  if (num < min) {
    throw createValidationError(paramName, `must be at least ${min}`, num, { minimum: min });
  }

  if (num > max) {
    throw createValidationError(paramName, `must be at most ${max}`, num, { maximum: max });
  }

  return num;
}

/**
 * Validate similarity threshold (0-1)
 * @param {string} value - Similarity value
 * @param {string} paramName - Parameter name
 * @returns {number} Validated similarity
 */
export function validateSimilarity(value, paramName = 'similarity') {
  return validateNumber(value, paramName, {
    min: 0,
    max: 1,
    required: true
  });
}

/**
 * Validate minLines parameter
 * @param {string} value - Min lines value
 * @param {string} paramName - Parameter name
 * @returns {number} Validated minLines
 */
export function validateMinLines(value, paramName = 'minLines') {
  return validateNumber(value, paramName, {
    min: 1,
    max: 10000,
    integer: true,
    required: true
  });
}

/**
 * Validate analyses list
 * @param {string} value - Comma-separated analyses
 * @returns {Array<string>} Validated analyses
 */
export function validateAnalyses(value) {
  const validAnalyses = ['dedup', 'deadCode', 'structure'];
  const analyses = value.split(',').map(a => a.trim());

  for (const analysis of analyses) {
    if (!validAnalyses.includes(analysis)) {
      throw new ValidationError(
        `Invalid analysis: ${analysis}. Must be one of: ${validAnalyses.join(', ')}`,
        { parameter: 'analyses', value: analysis, validOptions: validAnalyses }
      );
    }
  }

  return analyses;
}

/**
 * Validate file path exists
 * @param {string} filepath - Path to validate
 * @param {boolean} mustExist - Whether path must exist
 * @returns {string} Validated path
 */
export async function validatePath(filepath, mustExist = true) {
  const { resolve } = await import('path');
  const { stat } = await import('fs/promises');

  const resolved = resolve(filepath);

  if (mustExist) {
    try {
      await stat(resolved);
    } catch (error) {
      if (error.code === 'ENOENT') {
        throw new ValidationError(
          `Path does not exist: ${filepath}`,
          { filepath: resolved, originalPath: filepath, errorCode: error.code }
        );
      }
      throw error;
    }
  }

  return resolved;
}
