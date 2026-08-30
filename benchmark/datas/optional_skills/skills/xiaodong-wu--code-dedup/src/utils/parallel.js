/**
 * Parallel processing utilities
 * Handles concurrent execution with rate limiting
 */

/**
 * Process items in parallel with concurrency limit
 * @param {Array} items - Items to process
 * @param {Function} processor - Async function to process each item
 * @param {Object} options - { concurrency: number }
 * @returns {Promise<Array>}
 */
export async function parallel(items, processor, options = {}) {
  const concurrency = options.concurrency || 4;
  const results = [];
  const errors = [];

  // Process in batches
  for (let i = 0; i < items.length; i += concurrency) {
    const batch = items.slice(i, i + concurrency);
    const batchResults = await Promise.allSettled(
      batch.map(item => processor(item))
    );

    for (const result of batchResults) {
      if (result.status === 'fulfilled') {
        results.push(result.value);
      } else {
        errors.push(result.reason);
      }
    }
  }

  if (errors.length > 0) {
    console.warn(`${errors.length} items failed to process`);
  }

  return results;
}

/**
 * Map items in parallel with concurrency limit
 * @param {Array} items - Items to map
 * @param {Function} mapper - Async function to map each item
 * @param {Object} options - { concurrency: number }
 * @returns {Promise<Array>}
 */
export async function parallelMap(items, mapper, options = {}) {
  const concurrency = options.concurrency || 4;
  const results = new Array(items.length);

  // Process in batches
  for (let i = 0; i < items.length; i += concurrency) {
    const batchStart = i;
    const batchEnd = Math.min(i + concurrency, items.length);
    const batch = items.slice(batchStart, batchEnd);

    const batchResults = await Promise.all(
      batch.map((item, idx) => mapper(item, batchStart + idx))
    );

    // Place results in correct positions
    for (let j = 0; j < batchResults.length; j++) {
      results[batchStart + j] = batchResults[j];
    }
  }

  return results;
}

/**
 * Filter items in parallel with concurrency limit
 * @param {Array} items - Items to filter
 * @param {Function} predicate - Async predicate function
 * @param {Object} options - { concurrency: number }
 * @returns {Promise<Array>}
 */
export async function parallelFilter(items, predicate, options = {}) {
  const concurrency = options.concurrency || 4;
  const results = await parallelMap(
    items,
    async (item) => ({ item, pass: await predicate(item) }),
    { concurrency }
  );

  return results.filter(r => r.pass).map(r => r.item);
}

/**
 * Process items with progress tracking
 * @param {Array} items - Items to process
 * @param {Function} processor - Async processor function
 * @param {Function} onProgress - Progress callback (completed, total)
 * @param {Object} options - { concurrency: number }
 * @returns {Promise<Array>}
 */
export async function parallelWithProgress(items, processor, onProgress, options = {}) {
  const concurrency = options.concurrency || 4;
  const results = [];
  let completed = 0;

  const wrappedProcessor = async (item) => {
    try {
      const result = await processor(item);
      completed++;
      if (onProgress) {
        onProgress(completed, items.length);
      }
      return result;
    } catch (error) {
      completed++;
      if (onProgress) {
        onProgress(completed, items.length);
      }
      throw error;
    }
  };

  return await parallel(items, wrappedProcessor, { concurrency });
}

/**
 * Execute tasks with dependency management
 * @param {Array} tasks - Array of { id, fn, deps: [] }
 * @param {Object} options - { concurrency: number }
 * @returns {Promise<Object>} Map of id -> result
 */
export async function parallelWithDependencies(tasks, options = {}) {
  const results = {};
  const running = new Set();
  const completed = new Set();
  const taskMap = new Map(tasks.map(t => [t.id, t]));
  const concurrency = options.concurrency || 4;

  const canRun = (task) => {
    if (completed.has(task.id)) return false;
    if (running.has(task.id)) return false;
    return (task.deps || []).every(dep => completed.has(dep));
  };

  const getReadyTasks = () => {
    return tasks.filter(task => canRun(task));
  };

  while (completed.size < tasks.length) {
    const readyTasks = getReadyTasks();

    if (readyTasks.length === 0 && running.size === 0) {
      throw new Error('Circular dependency detected');
    }

    const batch = readyTasks.slice(0, concurrency);
    const batchPromises = batch.map(async task => {
      running.add(task.id);
      try {
        results[task.id] = await task.fn();
        completed.add(task.id);
      } finally {
        running.delete(task.id);
      }
    });

    await Promise.all(batchPromises);
  }

  return results;
}

/**
 * Create a worker pool for CPU-intensive tasks
 * @param {number} poolSize - Number of workers
 * @returns {Object} Worker pool interface
 */
export function createWorkerPool(poolSize = 4) {
  const queue = [];
  let activeWorkers = 0;

  return {
    /**
     * Execute a task in the pool
     * @param {Function} task - Async task function
     * @returns {Promise<*>}
     */
    async execute(task) {
      if (activeWorkers < poolSize) {
        activeWorkers++;
        try {
          return await task();
        } finally {
          activeWorkers--;
          this._processQueue();
        }
      } else {
        return new Promise((resolve, reject) => {
          queue.push({ task, resolve, reject });
        });
      }
    },

    /**
     * Process queued tasks
     * @private
     */
    _processQueue() {
      while (queue.length > 0 && activeWorkers < poolSize) {
        const { task, resolve, reject } = queue.shift();
        activeWorkers++;
        task()
          .then(resolve)
          .catch(reject)
          .finally(() => {
            activeWorkers--;
            this._processQueue();
          });
      }
    },

    /**
     * Get pool status
     */
    getStatus() {
      return {
        poolSize,
        activeWorkers,
        queuedTasks: queue.length
      };
    }
  };
}
