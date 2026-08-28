/**
 * 简单代码格式化器
 * 支持常见编程语言的基础代码格式化
 */
import * as fs from 'fs';
import * as path from 'path';

export class CodeFormatter {
  constructor(options = {}) {
    this.options = {
      indentSize: options.indentSize || 2,           // 缩进大小
      indentType: options.indentType || 'space',     // 缩进类型：space 或 tab
      trimTrailingWhitespace: options.trimTrailingWhitespace !== false,  // 删除行尾空格
      insertFinalNewline: options.insertFinalNewline !== false,          // 文件末尾添加换行
      ...options
    };
  }

  /**
   * 格式化代码内容
   */
  format(code, language = 'javascript') {
    let formatted = code;

    // 所有语言的通用格式化
    if (this.options.trimTrailingWhitespace) {
      formatted = this.trimTrailingWhitespace(formatted);
    }

    if (this.options.insertFinalNewline) {
      formatted = this.ensureFinalNewline(formatted);
    }

    // 特定语言的格式化
    switch (language.toLowerCase()) {
      case 'javascript':
      case 'js':
      case 'jsx':
      case 'typescript':
      case 'ts':
      case 'tsx':
        formatted = this.formatJavaScript(formatted);
        break;
      case 'python':
      case 'py':
        formatted = this.formatPython(formatted);
        break;
      case 'json':
        formatted = this.formatJSON(formatted);
        break;
    }

    return formatted;
  }

  /**
   * 格式化 JavaScript/TypeScript 代码
   */
  formatJavaScript(code) {
    let formatted = code;

    // 统一换行符
    formatted = formatted.replace(/\r\n/g, '\n');

    // 删除多个连续空行（最多保留 1 个）
    formatted = formatted.replace(/\n{3,}/g, '\n\n');

    // 在关键字后添加空格
    const keywords = ['if', 'else', 'for', 'while', 'switch', 'catch', 'function'];
    keywords.forEach(keyword => {
      const regex = new RegExp(`(${keyword})\\(`, 'g');
      formatted = formatted.replace(regex, '$1 (');
    });

    // 规范化运算符周围的空格
    formatted = formatted
      .replace(/([^=!<>])=([^=!<>])/g, '$1 = $2')
      .replace(/([^=!<>])==([^=!<>])/g, '$1 == $2')
      .replace(/([^=!<>])!==([^=!<>])/g, '$1 !== $2')
      .replace(/([^=!<>])<([^=!<>])/g, '$1 < $2')
      .replace(/([^=!<>])>([^=!<>])/g, '$1 > $2');

    return formatted;
  }

  /**
   * 格式化 Python 代码
   */
  formatPython(code) {
    let formatted = code;

    // 统一换行符
    formatted = formatted.replace(/\r\n/g, '\n');

    // 删除多个连续空行（Python 最多保留 2 个）
    formatted = formatted.replace(/\n{4,}/g, '\n\n\n');

    return formatted;
  }

  /**
   * 格式化 JSON 代码
   */
  formatJSON(code) {
    try {
      const parsed = JSON.parse(code);
      return JSON.stringify(parsed, null, this.options.indentSize);
    } catch {
      return code;
    }
  }

  /**
   * 删除每行末尾的空格
   */
  trimTrailingWhitespace(code) {
    return code.split('\n')
      .map(line => line.trimEnd())
      .join('\n');
  }

  /**
   * 确保文件以换行符结尾
   */
  ensureFinalNewline(code) {
    if (code && !code.endsWith('\n')) {
      return code + '\n';
    }
    return code;
  }

  /**
   * 格式化单个文件
   */
  async formatFile(filePath) {
    const code = await fs.promises.readFile(filePath, 'utf8');
    const language = this.getLanguageFromFile(filePath);
    const formatted = this.format(code, language);

    await fs.promises.writeFile(filePath, formatted, 'utf8');
    return {
      file: filePath,
      language,
      changed: code !== formatted
    };
  }

  /**
   * 格式化目录中的所有文件
   */
  async formatDirectory(dirPath, options = {}) {
    const { pattern = '**/*.{js,jsx,ts,tsx,py,json}' } = options;
    const { glob } = await import('glob');

    const files = await glob(path.join(dirPath, pattern), {
      ignore: options.ignore || ['node_modules/**', 'dist/**', 'build/**'],
      absolute: true
    });

    const results = [];
    for (const file of files) {
      try {
        const result = await this.formatFile(file);
        results.push(result);
      } catch (error) {
        results.push({
          file,
          error: error.message
        });
      }
    }

    return results;
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
      'json': 'json'
    };
    return langMap[ext] || 'text';
  }
}
