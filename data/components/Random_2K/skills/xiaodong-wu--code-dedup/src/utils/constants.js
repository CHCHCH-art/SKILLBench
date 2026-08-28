/**
 * Constants and magic numbers
 * This file documents all hardcoded values used throughout the codebase
 * with explanations for their choices
 */

// ============================================================================
// FILE SIZE LIMITS
// ============================================================================

/**
 * Maximum file size for processing (10 MB)
 * @constant {number}
 * @description
 * Limits file size to prevent Denial of Service (DoS) attacks and memory issues.
 * - Large files can cause excessive memory usage during parsing
 * - Most source files are < 1 MB
 * - Binary files should never be this large in a source repo
 * - 10 MB is large enough for any legitimate source file but small enough to prevent abuse
 */
export const MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024;

/**
 * Maximum file size for structure analysis (500 lines)
 * @constant {number}
 * @description
 * Files larger than this are skipped for structure analysis because:
 * - Generated files or minified bundles are often larger
 * - Structure metrics on very large files are not meaningful
 * - Performance considerations for large file analysis
 */
export const MAX_FILE_SIZE_LINES = 500;

// ============================================================================
// DUPLICATE DETECTION THRESHOLDS
// ============================================================================

/**
 * Minimum lines of code for duplicate detection
 * @constant {number}
 * @description
 * Code blocks shorter than this are ignored for duplicate detection because:
 * - Short snippets (e.g., "return true;") are naturally common
 * - False positive rate is high for short blocks
 * - 5 lines is roughly the minimum for a meaningful code block
 * - Matches typical code review practices
 */
export const MIN_LINES_FOR_DEDUP = 5;

/**
 * Default similarity threshold for approximate duplicate detection
 * @constant {number}
 * @description
 * Minimum Jaccard similarity (0-1 scale) to flag code as duplicate:
 * - 0.85 = 85% similarity
 * - Balances false positives vs false negatives
 * - Industry standard for code clone detection
 * - Lower values catch more clones but increase false positives
 * - Higher values reduce false positives but miss subtle clones
 *
 * @see [研究表明 85-90% 是最佳阈值范围](https://doi.org/10.1109/TSE.2016.2623696)
 */
export const DEFAULT_SIMILARITY_THRESHOLD = 0.85;

/**
 * Similarity threshold for "very high" confidence duplicates
 * @constant {number}
 * @description
 * Used when you want to be more conservative:
 * - 0.95 = 95% similarity
 * - Almost exact copies with minor formatting changes
 * - Very low false positive rate
 * - May miss Type-3 clones (statements with modifications)
 */
export const HIGH_SIMILARITY_THRESHOLD = 0.95;

// ============================================================================
// MINHASH LSH PARAMETERS
// ============================================================================

/**
 * Number of hash functions for MinHash signature
 * @constant {number}
 * @description
 * Number of permutation hashes used to create document signatures:
 * - 100 hashes provides good accuracy for code similarity
 * - Larger values improve accuracy but increase computation time
 * - Research shows 100-200 is optimal for most applications
 * - Must be evenly divisible by numBands
 *
 * Trade-off:
 * - Too small: High false positive rate
 * - Too large: Diminishing returns, slower performance
 */
export const DEFAULT_NUM_HASHES = 100;

/**
 * Number of bands for LSH
 * @constant {number}
 * @description
 * Splits signature into bands to find candidate pairs:
 * - 20 bands means 20 hash tables
 * - More bands = higher recall (find more candidates) but lower precision
 * - LSH threshold formula: (1/numBands)^(1/rowsPerBand)
 * - With 100 hashes and 20 bands: threshold ≈ 0.73
 * - This is below our 0.85 similarity threshold, which is correct
 *
 * The band threshold should be LOWER than the final similarity threshold
 * to ensure we don't miss valid candidates during the candidate generation phase.
 */
export const DEFAULT_NUM_BANDS = 20;

/**
 * Size of n-grams for shingling
 * @constant {number}
 * @description
 * Number of tokens in each shingle (overlapping window):
 * - 5 tokens captures short code patterns
 * - Larger values are more specific but less flexible
 * - For code, 3-7 is typical range
 * - 5 is a good balance for catching Type-2 clones (renamed variables)
 *
 * Examples with ngramSize=5:
 * - "if (x > 0) {" → captures the pattern
 * - Variable names are normalized, so "if (y > 0) {" is same shingle
 */
export const DEFAULT_NGRAM_SIZE = 5;

/**
 * Minimum numHashes for MinHash
 * @constant {number}
 * @description
 * Lower bound for numHashes parameter:
 * - Fewer than 10 hashes produces poor estimates
 * - Variance of MinHash estimate is too high
 * - Recommendation from LSH literature
 */
export const MIN_NUM_HASHES = 10;

/**
 * Maximum numHashes for MinHash
 * @constant {number}
 * @description
 * Upper bound for numHashes parameter:
 * - Beyond 1000 hashes, performance degrades significantly
 * - Diminishing returns on accuracy
 * - Memory usage becomes prohibitive
 */
export const MAX_NUM_HASHES = 1000;

/**
 * Valid range for n-gram size
 * @constant {number}
 * @description
 * Minimum and maximum ngram size:
 * - Min (1): Single token, too granular, high noise
 * - Max (10): Too specific, misses shorter patterns
 * - Optimal range: 3-7 for code
 */
export const MIN_NGRAM_SIZE = 1;
export const MAX_NGRAM_SIZE = 10;

// ============================================================================
// STRUCTURE ANALYSIS LIMITS
// ============================================================================

/**
 * Maximum function length (lines)
 * @constant {number}
 * @description
 * Functions longer than this are flagged as too complex:
 * - 50 lines is a common threshold in style guides
 * - Google Style Guide recommends < 40 lines
 * - Clean Code by Robert Martin suggests < 20 lines
 * - 50 is a reasonable compromise for real-world codebases
 *
 * Rationale:
 * - Longer functions are harder to understand and test
 * - Correlates with higher cyclomatic complexity
 * - Often indicates violation of Single Responsibility Principle
 */
export const MAX_FUNCTION_LENGTH_LINES = 50;

/**
 * Maximum number of function parameters
 * @constant {number}
 * @description
 * Functions with more parameters than this are flagged:
 * - More than 5 parameters is hard to use and remember
 * - Suggests need for parameter object or data structure
 * - Clean Code suggests max 3 parameters
 * - 5 allows for some flexibility while still flagging abuse
 *
 * Better alternatives:
 * - Use an options object
 * - Create a data transfer object
 * - Split the function
 */
export const MAX_FUNCTION_PARAMETERS = 5;

// ============================================================================
// CYCLOMATIC COMPLEXITY THRESHOLDS
// ============================================================================

/**
 * Maximum acceptable cyclomatic complexity
 * @constant {number}
 * @description
 * Functions with complexity above this need refactoring:
 * - Complexity = number of decision points + 1
 * - Complexity 10 means up to 9 if/switch/loop statements
 * - McCabe's original research suggested 10 as upper limit
 * - Values > 10 correlate strongly with defects
 *
 * Complexity ranges:
 * - 1-10: Simple, low risk
 * - 11-20: Moderate complexity, medium risk
 * - 21-50: High complexity, high risk
 * - 50+: Extreme complexity, very high risk
 */
export const MAX_CYCLOMATIC_COMPLEXITY = 10;

// ============================================================================
// PARALLEL PROCESSING
// ============================================================================

/**
 * Default concurrency for parallel file processing
 * @constant {number}
 * @description
 * Maximum number of files to process simultaneously:
 * - Based on CPU cores (typically 4-8 on modern machines)
 * - Too low: Underutilizes CPU
 * - Too high: Context switching overhead, memory pressure
 * - 10 is a safe default for most systems
 *
 * Adjust based on:
 * - Available CPU cores
 * - Memory constraints
 * - I/O vs CPU bound operations
 */
export const DEFAULT_CONCURRENCY = 10;

// ============================================================================
// CACHE SETTINGS
// ============================================================================

/**
 * Default cache TTL (24 hours in milliseconds)
 * @constant {number}
 * @description
 * How long cached analysis results remain valid:
 * - 24 hours = 86400000 ms
 * - Balances freshness with performance
 * - Source code doesn't change that frequently in development
 * - Forces re-analysis after a work day
 *
 * Trade-off:
 * - Shorter TTL: More up-to-date results, slower performance
 * - Longer TTL: Better performance, but may use stale results
 */
export const DEFAULT_CACHE_TTL_MS = 24 * 60 * 60 * 1000;

/**
 * Cache key version
 * @constant {string}
 * @description
 * Version identifier for cache invalidation:
 * - Increment when analysis logic changes significantly
 * - Prevents using stale cache from older versions
 * - Format: "v{major}.{minor}"
 * - Major: Breaking changes to analysis algorithms
 * - Minor: Non-breaking improvements or bug fixes
 */
export const CACHE_VERSION = 'v2.0';

// ============================================================================
// FORMATTING
// ============================================================================

/**
 * Maximum line length for console output
 * @constant {number}
 * @description
 * Wraps console output at this column for readability:
 * - 100 columns is wider than traditional 80 but fits modern screens
 * - GitHub PR comments typically show ~120 columns
 * - Terminal windows are commonly sized 100-120 columns
 */
export const MAX_LINE_LENGTH = 100;

/**
 * Indentation size (spaces)
 * @constant {number}
 * @description
 * Number of spaces for indentation in formatted output:
 * - 2 spaces is standard for JavaScript/TypeScript
 * - Matches ESLint default for JS projects
 * - More compact than 4 spaces
 */
export const INDENT_SIZE = 2;

// ============================================================================
// MISC
// ============================================================================

/**
 * Maximum memory for mock function extraction (5 KB)
 * @constant {number}
 * @description
 * Fallback parser limits function extraction to prevent OOM:
 * - Used when tree-sitter is unavailable
 * - Prevents runaway string operations
 * - 5 KB is enough for any reasonable function
 */
export const MAX_FUNCTION_SIZE_BYTES = 5 * 1024;

/**
 * Minimum file size to analyze (1 byte)
 * @constant {number}
 * @description
 * Empty files are skipped during analysis:
 * - Cannot contain meaningful code
 * - Would cause parse errors
 */
export const MIN_FILE_SIZE_BYTES = 1;
