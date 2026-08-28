/**
 * 简单代码去重器
 * 使用哈希比对查找重复代码块
 */
import * as fs from 'fs';
import * as path from 'path';
import crypto from 'crypto';

export class SimpleDeduper {
  constructor(options = {}) {
    this.options = {
      minLines: options.minLines || 3,                    // 代码块最小行数
      ignoreWhitespace: options.ignoreWhitespace !== false,  // 忽略空格差异
      ignoreComments: options.ignoreComments !== false,      // 忽略注释差异
      threshold: options.threshold || 1.0,               // 相似度阈值（1.0 = 完全匹配）
      ...options
    };
    this.results = {
      duplicates: [],
      scannedFiles: []
    };
  }

  /**
   * 标准化代码用于比较
   */
  normalizeCode(code) {
    let normalized = code;

    // 如果启用，删除注释
    if (this.options.ignoreComments) {
      // 删除单行注释
      normalized = normalized.replace(/\/\/.*$/gm, '');
      normalized = normalized.replace(/#.*$/gm, '');
      // 删除多行注释
      normalized = normalized.replace(/\/\*[\s\S]*?\*\//g, '');
    }

    // 如果启用，标准化空格
    if (this.options.ignoreWhitespace) {
      normalized = normalized.replace(/\s+/g, ' ');
      normalized = normalized.trim();
    }

    return normalized;
  }

  /**
   * 计算代码块的哈希值
   */
  calculateHash(code) {
    const normalized = this.normalizeCode(code);
    return crypto
      .createHash('md5')
      .update(normalized)
      .digest('hex');
  }

  /**
   * 计算两个代码块的相似度
   */
  calculateSimilarity(code1, code2) {
    const normalized1 = this.normalizeCode(code1);
    const normalized2 = this.normalizeCode(code2);

    if (normalized1 === normalized2) {
      return 1.0;
    }

    // 使用编辑距离计算部分相似度
    const distance = this.levenshteinDistance(normalized1, normalized2);
    const maxLen = Math.max(normalized1.length, normalized2.length);

    if (maxLen === 0) return 1.0;
    return 1 - (distance / maxLen);
  }

  /**
   * 计算编辑距离（Levenshtein 距离）
   */
  levenshteinDistance(str1, str2) {
    const m = str1.length;
    const n = str2.length;
    const dp = Array(m + 1).fill(null).map(() => Array(n + 1).fill(0));

    for (let i = 0; i <= m; i++) dp[i][0] = i;
    for (let j = 0; j <= n; j++) dp[0][j] = j;

    for (let i = 1; i <= m; i++) {
      for (let j = 1; j <= n; j++) {
        if (str1[i - 1] === str2[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 + Math.min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]);
        }
      }
    }

    return dp[m][n];
  }

  /**
   * 将代码拆分成多个代码块
   */
  splitIntoBlocks(code) {
    const lines = code.split('\n');
    const blocks = [];

    for (let i = 0; i < lines.length; i++) {
      for (let size = this.options.minLines; size <= lines.length - i; size++) {
        const block = lines.slice(i, i + size).join('\n');
        blocks.push({
          code: block,
          startLine: i + 1,
          endLine: i + size,
          hash: this.calculateHash(block)
        });
      }
    }

    return blocks;
  }

  /**
   * 查找单个文件内的重复代码
   */
  findDuplicatesInFile(filePath) {
    const code = fs.readFileSync(filePath, 'utf8');
    const blocks = this.splitIntoBlocks(code);
    const duplicates = [];
    const seen = new Map();

    for (const block of blocks) {
      const key = `${block.hash}_${block.endLine - block.startLine}`;

      if (seen.has(key)) {
        const existing = seen.get(key);
        if (block.startLine !== existing.startLine) {
          duplicates.push({
            block1: {
              startLine: existing.startLine,
              endLine: existing.endLine
            },
            block2: {
              startLine: block.startLine,
              endLine: block.endLine
            },
            lines: block.endLine - block.startLine,
            hash: block.hash
          });
        }
      } else {
        seen.set(key, block);
      }
    }

    return duplicates;
  }

  /**
   * 查找多个文件之间的重复代码
   */
  findDuplicatesAcrossFiles(filePaths) {
    const allBlocks = [];
    const fileMap = new Map();

    // 从所有文件中收集代码块
    for (const filePath of filePaths) {
      const code = fs.readFileSync(filePath, 'utf8');
      const blocks = this.splitIntoBlocks(code);
      const language = this.getLanguageFromFile(filePath);

      for (const block of blocks) {
        const key = `${block.hash}_${block.endLine - block.startLine}`;
        if (!fileMap.has(key)) {
          fileMap.set(key, []);
        }
        fileMap.get(key).push({
          file: filePath,
          language,
          startLine: block.startLine,
          endLine: block.endLine
        });
      }
    }

    // 查找重复
    const duplicates = [];
    for (const [key, occurrences] of fileMap) {
      if (occurrences.length > 1) {
        duplicates.push({
          hash: key,
          occurrences,
          count: occurrences.length
        });
      }
    }

    return duplicates;
  }

  /**
   * 扫描目录查找重复代码
   */
  async scan(targetPath, options = {}) {
    const { glob } = await import('glob');
    const stats = await fs.promises.stat(targetPath);

    if (stats.isFile()) {
      return this.scanFile(targetPath);
    }

    // 扫描目录
    const pattern = options.pattern || '**/*.{js,jsx,ts,tsx,py,java,go}';
    const ignore = options.ignore || ['node_modules/**', 'dist/**', 'build/**'];

    const files = await glob(path.join(targetPath, pattern), {
      ignore,
      absolute: true
    });

    this.results.scannedFiles = files;

    // 查找跨文件重复
    const duplicates = this.findDuplicatesAcrossFiles(files);

    this.results.duplicates = duplicates.filter(d => d.count >= 2);
    return this.results;
  }

  /**
   * 扫描单个文件
   */
  scanFile(filePath) {
    const duplicates = this.findDuplicatesInFile(filePath);
    this.results.scannedFiles = [filePath];
    this.results.duplicates = [{
      file: filePath,
      duplicates
    }];
    return this.results;
  }

  /**
   * 根据文件扩展名检测编程语言
   */
  getLanguageFromFile(filePath) {
    const ext = path.extname(filePath).slice(1).toLowerCase();
    const langMap = {
      'js': 'javascript',
      'jsx': 'javascript',
      'ts': 'typescript',
      'tsx': 'typescript',
      'py': 'python',
      'java': 'java',
      'go': 'go'
    };
    return langMap[ext] || 'unknown';
  }

  /**
   * 生成控制台报告（中文）
   */
  generateReport() {
    let report = '\n=== 代码去重报告 ===\n';
    report += `扫描文件数: ${this.results.scannedFiles.length}\n`;
    report += `发现重复代码组: ${this.results.duplicates.length}\n\n`;

    for (const dup of this.results.duplicates) {
      if (dup.occurrences) {
        report += `重复代码组（出现 ${dup.count} 次）:\n`;
        for (const occ of dup.occurrences) {
          report += `  - ${occ.file}:${occ.startLine}-${occ.endLine}\n`;
        }
        report += '\n';
      } else if (dup.duplicates && dup.duplicates.length > 0) {
        report += `文件: ${dup.file}\n`;
        report += `内部重复代码: ${dup.duplicates.length} 处\n\n`;
      }
    }

    return report;
  }

  /**
   * 获取结果
   */
  getResults() {
    return this.results;
  }

  /**
   * 获取统计信息
   */
  getStatistics() {
    return {
      scannedFiles: this.results.scannedFiles.length,
      duplicateGroups: this.results.duplicates.length,
      totalDuplicates: this.results.duplicates.reduce((sum, d) => sum + (d.count || d.duplicates?.length || 0), 0)
    };
  }

  /**
   * 重置结果
   */
  reset() {
    this.results = {
      duplicates: [],
      scannedFiles: []
    };
  }
}
