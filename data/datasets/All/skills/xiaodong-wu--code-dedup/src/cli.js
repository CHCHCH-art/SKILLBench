#!/usr/bin/env node
/**
 * Code Dedup Skills - CLI Interface
 * A comprehensive code analysis platform
 */
import { Command } from 'commander';
import * as path from 'path';
import { fileURLToPath } from 'url';
import { CodeFormatter } from './CodeFormatter.js';
import { SimpleDeduper } from './SimpleDeduper.js';
import { analyzeCode, getDefaultConfig } from './index.js';
import { validateSimilarity, validateMinLines, validateAnalyses } from './cli/validation.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const program = new Command();

program
  .name('code-dedup')
  .description('AI-friendly code analysis platform for deduplication, dead code detection, and structure optimization')
  .version('2.0.0');

// =============================================================================
// New v2.0 Commands
// =============================================================================

// Analyze command - Main analysis command
program
  .command('analyze')
  .description('Comprehensive code analysis (deduplication, dead code, structure)')
  .argument('<path>', 'Path to analyze (file or directory)')
  .option('-a, --analyses <types>', 'Analysis types: dedup, deadCode, structure (comma-separated)', 'dedup,deadCode,structure')
  .option('-f, --format <format>', 'Output format: json, console, html', 'json')
  .option('-o, --output <file>', 'Output file (optional)')
  .option('-v, --verbose', 'Verbose output')
  .option('--no-colors', 'Disable colored output')
  .option('--dedup-min-lines <number>', 'Minimum lines for duplicate detection', '5')
  .option('--dedup-similarity <number>', 'Minimum similarity threshold (0-1)', '0.85')
  .option('--ignore-tests', 'Ignore test files in dead code detection', 'true')
  .action(async (targetPath, options) => {
    try {
      // Validate inputs
      const analyses = validateAnalyses(options.analyses);
      const minLines = validateMinLines(options.dedupMinLines, 'dedup-min-lines');
      const minSimilarity = validateSimilarity(options.dedupSimilarity, 'dedup-similarity');

      const resolvedPath = path.resolve(targetPath);

      // Build config
      const config = {
        analyses,
        dedup: {
          minLines,
          minSimilarity
        },
        deadCode: {
          ignoreTestFiles: options.ignoreTests === 'true'
        },
        output: {
          format: options.format,
          verbose: options.verbose
        }
      };

      console.log(`Analyzing ${resolvedPath}...`);
      console.log(`Analyses: ${analyses.join(', ')}`);
      console.log('');

      const startTime = Date.now();
      const result = await analyzeCode(resolvedPath, {
        config,
        format: options.format,
        useColors: options.colors !== false,
        verbose: options.verbose
      });
      const duration = Date.now() - startTime;

      // Output results
      if (options.format === 'json') {
        console.log(JSON.stringify(result, null, 2));
      } else {
        console.log(result);
      }

      console.log('');
      console.log(`Analysis completed in ${(duration / 1000).toFixed(2)}s`);

      // Write to file if specified
      if (options.output) {
        const fs = await import('fs');
        const content = options.format === 'json'
          ? JSON.stringify(result, null, 2)
          : result;
        await fs.promises.writeFile(options.output, content);
        console.log(`Report saved to: ${options.output}`);
      }

    } catch (error) {
      console.error(`Error: ${error.message}`);
      if (options.verbose) {
        console.error(error.stack);
      }
      process.exit(1);
    }
  });

// Quick dedup check
program
  .command('check-dup')
  .description('Quick duplicate code detection')
  .argument('<path>', 'Path to check')
  .option('-f, --format <format>', 'Output format: json, console', 'console')
  .option('-m, --min-lines <number>', 'Minimum lines for duplicate detection', '5')
  .action(async (targetPath, options) => {
    try {
      const result = await analyzeCode(path.resolve(targetPath), {
        analyses: ['dedup'],
        dedup: { minLines: parseInt(options.minLines) },
        format: options.format
      });

      if (options.format === 'json') {
        console.log(JSON.stringify(result, null, 2));
      } else {
        console.log(result);
      }
    } catch (error) {
      console.error(`Error: ${error.message}`);
      process.exit(1);
    }
  });

// Quick dead code check
program
  .command('check-dead')
  .description('Quick dead code detection')
  .argument('<path>', 'Path to check')
  .option('-f, --format <format>', 'Output format: json, console', 'console')
  .action(async (targetPath, options) => {
    try {
      const result = await analyzeCode(path.resolve(targetPath), {
        analyses: ['deadCode'],
        format: options.format
      });

      if (options.format === 'json') {
        console.log(JSON.stringify(result, null, 2));
      } else {
        console.log(result);
      }
    } catch (error) {
      console.error(`Error: ${error.message}`);
      process.exit(1);
    }
  });

// Quick structure check
program
  .command('check-struct')
  .description('Quick structure analysis')
  .argument('<path>', 'Path to check')
  .option('-f, --format <format>', 'Output format: json, console', 'console')
  .action(async (targetPath, options) => {
    try {
      const result = await analyzeCode(path.resolve(targetPath), {
        analyses: ['structure'],
        format: options.format
      });

      if (options.format === 'json') {
        console.log(JSON.stringify(result, null, 2));
      } else {
        console.log(result);
      }
    } catch (error) {
      console.error(`Error: ${error.message}`);
      process.exit(1);
    }
  });

// Show default configuration
program
  .command('config')
  .description('Show default configuration')
  .action(() => {
    const config = getDefaultConfig();
    console.log(JSON.stringify(config, null, 2));
  });

// =============================================================================
// Legacy v1.0 Commands (for backward compatibility)
// =============================================================================

// Format command
program
  .command('format')
  .description('[Legacy] Format code files')
  .argument('<path>', 'Path to format (file or directory)')
  .option('-i, --indent-size <number>', 'Indent size', '2')
  .option('-t, --indent-type <type>', 'Indent type (space or tab)', 'space')
  .option('--ignore <patterns>', 'Ignore patterns (comma-separated)', '')
  .action(async (targetPath, options) => {
    try {
      const formatter = new CodeFormatter({
        indentSize: parseInt(options.indentSize),
        indentType: options.indentType
      });

      const resolvedPath = path.resolve(targetPath);
      const stats = await import('fs').then(fs => fs.promises.stat(resolvedPath));

      let results;
      if (stats.isFile()) {
        results = await formatter.formatFile(resolvedPath);
        console.log(`\n✓ Formatted: ${results.file}`);
        console.log(`  Language: ${results.language}`);
        console.log(`  Changed: ${results.changed ? 'Yes' : 'No'}`);
      } else {
        results = await formatter.formatDirectory(resolvedPath, {
          ignore: options.ignore ? options.ignore.split(',') : undefined
        });

        console.log(`\nFormatted ${results.length} files:`);
        let changedCount = 0;
        for (const result of results) {
          if (result.error) {
            console.log(`  ✗ Error: ${result.file} - ${result.error}`);
          } else {
            console.log(`  ${result.changed ? '✓' : ' '} ${result.file} (${result.language})${result.changed ? ' - Changed' : ''}`);
            if (result.changed) changedCount++;
          }
        }
        console.log(`\nTotal: ${changedCount} files changed`);
      }
    } catch (error) {
      console.error(`Error: ${error.message}`);
      process.exit(1);
    }
  });

// Dedup command (legacy)
program
  .command('dedup')
  .description('[Legacy] Find duplicate code blocks')
  .argument('<path>', 'Path to scan (file or directory)')
  .option('-m, --min-lines <number>', 'Minimum lines for code block', '3')
  .option('--ignore-whitespace', 'Do not ignore whitespace when comparing')
  .option('--keep-comments', 'Keep comments when comparing')
  .option('-i, --ignore <patterns>', 'Ignore patterns (comma-separated)', '')
  .action(async (targetPath, options) => {
    try {
      const deduper = new SimpleDeduper({
        minLines: parseInt(options.minLines),
        ignoreWhitespace: options.ignoreWhitespace !== true,
        ignoreComments: options.keepComments !== true
      });

      const resolvedPath = path.resolve(targetPath);
      await deduper.scan(resolvedPath, {
        ignore: options.ignore ? options.ignore.split(',') : undefined
      });

      const stats = deduper.getStatistics();
      console.log(deduper.generateReport());
      console.log(`Statistics:`);
      console.log(`  Scanned files: ${stats.scannedFiles}`);
      console.log(`  Duplicate groups: ${stats.duplicateGroups}`);
    } catch (error) {
      console.error(`Error: ${error.message}`);
      process.exit(1);
    }
  });

// Check command (legacy)
program
  .command('check')
  .description('[Legacy] Format and check for duplicate code')
  .argument('<path>', 'Path to check (file or directory)')
  .option('-i, --ignore <patterns>', 'Ignore patterns (comma-separated)', '')
  .action(async (targetPath, options) => {
    try {
      const resolvedPath = path.resolve(targetPath);

      // Format
      console.log('\n=== Code Formatting ===');
      const formatter = new CodeFormatter();
      const formatResults = await formatter.formatDirectory(resolvedPath, {
        ignore: options.ignore ? options.ignore.split(',') : undefined
      });

      const changed = formatResults.filter(r => r.changed && !r.error).length;
      console.log(`Formatted ${formatResults.length} files, ${changed} changed`);

      // Dedup check
      console.log('\n=== Duplicate Code Check ===');
      const deduper = new SimpleDeduper();
      await deduper.scan(resolvedPath, {
        ignore: options.ignore ? options.ignore.split(',') : undefined
      });

      const stats = deduper.getStatistics();
      console.log(`Found ${stats.duplicateGroups} duplicate code groups`);

    } catch (error) {
      console.error(`Error: ${error.message}`);
      process.exit(1);
    }
  });

// Parse command line arguments
program.parse();

// If no command provided, show help
if (!process.argv.slice(2).length) {
  program.outputHelp();
}
