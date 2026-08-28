/**
 * Builds and manages analysis results
 * Provides fluent API for constructing structured results
 */
export class AnalysisResult {
  constructor() {
    this.startTime = Date.now();
    this.summary = {
      status: 'success',
      filesAnalyzed: 0,
      issuesFound: 0,
      warnings: 0
    };
    this.results = {};
    this.recommendations = [];
    this.errors = [];
    this.metadata = {
      timestamp: new Date().toISOString(),
      version: '2.0.0'
    };
  }

  /**
   * Set summary status
   * @param {string} status - 'success', 'warning', 'error'
   * @returns {AnalysisResult}
   */
  setStatus(status) {
    this.summary.status = status;
    return this;
  }

  /**
   * Set number of files analyzed
   * @param {number} count
   * @returns {AnalysisResult}
   */
  setFilesAnalyzed(count) {
    this.summary.filesAnalyzed = count;
    return this;
  }

  /**
   * Increment issue count
   * @param {number} count
   * @returns {AnalysisResult}
   */
  addIssues(count) {
    this.summary.issuesFound += count;
    return this;
  }

  /**
   * Add analyzer results
   * @param {string} analyzerName
   * @param {Object} results
   * @returns {AnalysisResult}
   */
  addResult(analyzerName, results) {
    this.results[analyzerName] = results;
    return this;
  }

  /**
   * Add a recommendation
   * @param {Object} recommendation
   * @returns {AnalysisResult}
   */
  addRecommendation(recommendation) {
    this.recommendations.push({
      type: recommendation.type || 'refactor',
      priority: recommendation.priority || 'medium',
      description: recommendation.description,
      files: recommendation.files || [],
      suggestion: recommendation.suggestion,
      line: recommendation.line,
      code: recommendation.code
    });
    return this;
  }

  /**
   * Add multiple recommendations
   * @param {Array} recommendations
   * @returns {AnalysisResult}
   */
  addRecommendations(recommendations) {
    for (const rec of recommendations) {
      this.addRecommendation(rec);
    }
    return this;
  }

  /**
   * Add an error
   * @param {Error|string} error
   * @returns {AnalysisResult}
   */
  addError(error) {
    const errorObj = {
      message: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined
    };
    this.errors.push(errorObj);
    return this;
  }

  /**
   * Add metadata
   * @param {string} key
   * @param {*} value
   * @returns {AnalysisResult}
   */
  addMetadata(key, value) {
    this.metadata[key] = value;
    return this;
  }

  /**
   * Mark result as failed
   * @param {Error|string} error
   * @returns {AnalysisResult}
   */
  markFailed(error) {
    this.setStatus('error');
    this.addError(error);
    return this;
  }

  /**
   * Calculate duration and finalize result
   * @returns {Object}
   */
  build() {
    const endTime = Date.now();
    return {
      summary: {
        ...this.summary,
        durationMs: endTime - this.startTime
      },
      results: this.results,
      recommendations: this.recommendations.sort(this._byPriority),
      errors: this.errors,
      metadata: this.metadata
    };
  }

  /**
   * Sort recommendations by priority
   * @private
   */
  _byPriority(a, b) {
    const priorityOrder = { high: 0, medium: 1, low: 2 };
    return priorityOrder[a.priority] - priorityOrder[b.priority];
  }

  /**
   * Create a successful result
   * @param {Object} data
   * @returns {Object}
   */
  static success(data) {
    return new AnalysisResult()
      .setFilesAnalyzed(data.filesAnalyzed || 0)
      .addIssues(data.issuesFound || 0)
      .build();
  }

  /**
   * Create a failed result
   * @param {Error|string} error
   * @returns {Object}
   */
  static failure(error) {
    return new AnalysisResult()
      .markFailed(error)
      .build();
  }
}
