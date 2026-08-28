import { describe, it } from 'node:test';
import assert from 'node:assert';
import {
  getExtension,
  detectLanguage,
  shouldExclude,
  isTestFile,
  countLines,
  normalizeLineEndings,
  getRelativePath
} from '../../src/utils/fileUtils.js';

describe('fileUtils', () => {
  describe('getExtension', () => {
    it('should extract extension', () => {
      assert.strictEqual(getExtension('test.js'), 'js');
      assert.strictEqual(getExtension('test.ts'), 'ts');
      assert.strictEqual(getExtension('test.py'), 'py');
    });

    it('should handle files without extension', () => {
      assert.strictEqual(getExtension('Makefile'), '');
      assert.strictEqual(getExtension('README'), '');
    });
  });

  describe('detectLanguage', () => {
    it('should detect JavaScript', () => {
      assert.strictEqual(detectLanguage('test.js'), 'javascript');
      assert.strictEqual(detectLanguage('test.jsx'), 'javascript');
    });

    it('should detect TypeScript', () => {
      assert.strictEqual(detectLanguage('test.ts'), 'typescript');
      assert.strictEqual(detectLanguage('test.tsx'), 'typescript');
    });

    it('should detect Python', () => {
      assert.strictEqual(detectLanguage('test.py'), 'python');
    });

    it('should default to JavaScript', () => {
      assert.strictEqual(detectLanguage('test.unknown'), 'javascript');
    });
  });

  describe('shouldExclude', () => {
    it('should exclude node_modules', () => {
      assert.strictEqual(shouldExclude('path/to/node_modules/file.js', ['**/node_modules/**']), true);
    });

    it('should not exclude regular files', () => {
      assert.strictEqual(shouldExclude('src/index.js', ['**/node_modules/**']), false);
    });

    it('should handle multiple patterns', () => {
      const patterns = ['**/node_modules/**', '**/dist/**', '**/.git/**'];
      assert.strictEqual(shouldExclude('node_modules/pkg/file.js', patterns), true);
      assert.strictEqual(shouldExclude('dist/build.js', patterns), true);
      assert.strictEqual(shouldExclude('.git/config', patterns), true);
      assert.strictEqual(shouldExclude('src/index.js', patterns), false);
    });
  });

  describe('isTestFile', () => {
    it('should detect .test. files', () => {
      assert.strictEqual(isTestFile('app.test.js'), true);
      assert.strictEqual(isTestFile('app.test.ts'), true);
    });

    it('should detect .spec. files', () => {
      assert.strictEqual(isTestFile('app.spec.js'), true);
      assert.strictEqual(isTestFile('app.spec.ts'), true);
    });

    it('should detect files in test directories', () => {
      assert.strictEqual(isTestFile('test/app.js', ['**/test/**']), true);
      assert.strictEqual(isTestFile('tests/app.js', ['**/tests/**']), true);
    });

    it('should not detect regular files', () => {
      assert.strictEqual(isTestFile('app.js'), false);
      assert.strictEqual(isTestFile('src/index.js'), false);
    });
  });

  describe('countLines', () => {
    it('should count lines correctly', () => {
      const code = 'function test() {\n  return true;\n}';
      const lines = countLines(code);
      assert.strictEqual(lines.total, 3);
    });

    it('should count blank lines', () => {
      const code = 'function test() {\n\n  return true;\n}';
      const lines = countLines(code);
      assert.strictEqual(lines.blank, 1);
      assert.strictEqual(lines.code, 3);
    });

    it('should count comment lines', () => {
      const code = '// This is a comment\nfunction test() {\n  return true;\n}';
      const lines = countLines(code, 'javascript');
      assert.strictEqual(lines.comment, 1);
    });

    it('should count code lines', () => {
      const code = 'function test() {\n  return true;\n}';
      const lines = countLines(code);
      assert.strictEqual(lines.code, 3);
    });
  });

  describe('normalizeLineEndings', () => {
    it('should convert CRLF to LF', () => {
      const code = 'line1\r\nline2\r\nline3';
      const normalized = normalizeLineEndings(code);
      assert.strictEqual(normalized, 'line1\nline2\nline3');
    });

    it('should convert CR to LF', () => {
      const code = 'line1\rline2\rline3';
      const normalized = normalizeLineEndings(code);
      assert.strictEqual(normalized, 'line1\nline2\nline3');
    });

    it('should leave LF as is', () => {
      const code = 'line1\nline2\nline3';
      const normalized = normalizeLineEndings(code);
      assert.strictEqual(normalized, code);
    });
  });
});
