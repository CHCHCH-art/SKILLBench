# JSDoc Tags Reference

## Contents

- [Block Tags](#block-tags)
- [Inline Tags](#inline-tags)
- [Type Expressions](#type-expressions)

---

## Block Tags

### General Documentation

| Tag            | Synonyms                     | Description                  | Example                          |
| -------------- | ---------------------------- | ---------------------------- | -------------------------------- |
| `@description` | `@desc`                      | Symbol description           | `@description Calculates total.` |
| `@summary`     | -                            | Short version of description | `@summary Gets user.`            |
| `@author`      | -                            | Code author                  | `@author John <john@email.com>`  |
| `@version`     | -                            | Element version              | `@version 1.2.0`                 |
| `@since`       | -                            | Version since it exists      | `@since 2.0.0`                   |
| `@deprecated`  | -                            | Mark as obsolete             | `@deprecated Use newMethod()`    |
| `@todo`        | -                            | Pending tasks                | `@todo Add validation`           |
| `@see`         | -                            | Reference to documentation   | `@see {@link OtherClass}`        |
| `@license`     | -                            | Code license                 | `@license MIT`                   |
| `@copyright`   | -                            | Copyright information        | `@copyright 2026 MyCompany`      |
| `@file`        | `@fileoverview`, `@overview` | File description             | `@file Date utilities`           |
| `@ignore`      | -                            | Omit from documentation      | `@ignore`                        |

### Functions and Methods

| Tag          | Synonyms            | Description                | Example                                     |
| ------------ | ------------------- | -------------------------- | ------------------------------------------- |
| `@param`     | `@arg`, `@argument` | Function parameter         | `@param {string} name - The user name.`     |
| `@returns`   | `@return`           | Return value               | `@returns {boolean} True if valid.`         |
| `@throws`    | `@exception`        | Error that may be thrown   | `@throws {TypeError} If type is incorrect.` |
| `@async`     | -                   | Async function             | `@async`                                    |
| `@generator` | -                   | Generator function         | `@generator`                                |
| `@yields`    | `@yield`            | Value yielded by generator | `@yields {number} Next number.`             |
| `@callback`  | -                   | Defines callback type      | See example below                           |
| `@function`  | `@func`, `@method`  | Documents a function       | `@function myFunc`                          |
| `@this`      | -                   | Type of `this` in function | `@this {MyClass}`                           |
| `@fires`     | `@emits`            | Events it may emit         | `@fires MyClass#event`                      |
| `@listens`   | -                   | Events it listens to       | `@listens MyClass#event`                    |
| `@example`   | -                   | Usage example              | See example below                           |

### Types and Properties

| Tag         | Synonyms        | Description            | Example                           |
| ----------- | --------------- | ---------------------- | --------------------------------- |
| `@type`     | -               | Variable type          | `@type {string}`                  |
| `@typedef`  | -               | Defines custom type    | See example below                 |
| `@property` | `@prop`         | Object property        | `@property {string} name - Name.` |
| `@member`   | `@var`          | Documents a member     | `@member {number} count`          |
| `@constant` | `@const`        | Documents constant     | `@constant {number}`              |
| `@default`  | `@defaultvalue` | Default value          | `@default 42`                     |
| `@enum`     | -               | Collection of props    | `@enum {number}`                  |
| `@readonly` | -               | Read-only property     | `@readonly`                       |
| `@template` | -               | Generic type parameter | `@template T`                     |

### Classes and Objects

| Tag                | Synonyms       | Description               | Example                           |
| ------------------ | -------------- | ------------------------- | --------------------------------- |
| `@class`           | `@constructor` | Marks as class            | `@class`                          |
| `@classdesc`       | -              | Class description         | `@classdesc Handles connections.` |
| `@constructs`      | -              | Indicates constructor     | `@constructs MyClass`             |
| `@hideconstructor` | -              | Hides constructor in docs | `@hideconstructor`                |
| `@extends`         | `@augments`    | Class inheritance         | `@extends {BaseClass}`            |
| `@implements`      | -              | Implements interface      | `@implements {Serializable}`      |
| `@interface`       | -              | Defines interface         | `@interface`                      |
| `@mixin`           | -              | Documents mixin           | `@mixin`                          |
| `@mixes`           | -              | Uses members from another | `@mixes OtherObject`              |
| `@abstract`        | `@virtual`     | Must be implemented       | `@abstract`                       |
| `@override`        | -              | Overrides parent          | `@override`                       |
| `@inheritdoc`      | -              | Inherits parent docs      | `@inheritdoc`                     |

### Access and Visibility

| Tag          | Synonyms | Description      | Example           |
| ------------ | -------- | ---------------- | ----------------- |
| `@access`    | -        | Access level     | `@access private` |
| `@private`   | -        | Private member   | `@private`        |
| `@protected` | -        | Protected member | `@protected`      |
| `@public`    | -        | Public member    | `@public`         |
| `@package`   | -        | Package-private  | `@package`        |

### Modules and Namespaces

| Tag          | Synonyms | Description              | Example                   |
| ------------ | -------- | ------------------------ | ------------------------- |
| `@module`    | -        | Documents JS module      | `@module utils/string`    |
| `@exports`   | -        | Exported member          | `@exports formatDate`     |
| `@namespace` | -        | Documents namespace      | `@namespace MyApp`        |
| `@memberof`  | -        | Belongs to parent symbol | `@memberof MyClass`       |
| `@global`    | -        | Global object            | `@global`                 |
| `@inner`     | -        | Inner member             | `@inner`                  |
| `@instance`  | -        | Instance member          | `@instance`               |
| `@static`    | -        | Static member            | `@static`                 |
| `@external`  | `@host`  | External class/namespace | `@external jQuery`        |
| `@requires`  | -        | Required dependency      | `@requires module:lodash` |

### Other

| Tag          | Synonyms | Description                     | Example                           |
| ------------ | -------- | ------------------------------- | --------------------------------- |
| `@alias`     | -        | Alternative name                | `@alias realName`                 |
| `@name`      | -        | Object name                     | `@name myObject`                  |
| `@kind`      | -        | Symbol type                     | `@kind function`                  |
| `@variation` | -        | Distinguishes same-name objects | `@variation 2`                    |
| `@borrows`   | -        | Uses something from another     | `@borrows other#method as method` |
| `@lends`     | -        | Lends properties to symbol      | `@lends MyClass.prototype`        |
| `@event`     | -        | Documents event                 | `@event MyClass#change`           |
| `@tutorial`  | -        | Link to tutorial                | `@tutorial getting-started`       |

---

## Inline Tags

Used within descriptions.

| Tag         | Synonyms                  | Description          | Example                                      |
| ----------- | ------------------------- | -------------------- | -------------------------------------------- |
| `@link`     | `@linkcode`, `@linkplain` | Link to another item | `{@link MyClass}` or `{@link MyClass\|text}` |
| `@tutorial` | -                         | Link to tutorial     | `{@tutorial getting-started}`                |

```javascript
/**
 * Gets configuration. See {@link ConfigManager} for more details.
 * Also check {@link https://example.com|external documentation}.
 */
```

---

## Type Expressions

### Basic Types

```javascript
/** @type {string} */
/** @type {number} */
/** @type {boolean} */
/** @type {null} */
/** @type {undefined} */
/** @type {symbol} */
/** @type {bigint} */
/** @type {Object} */ // Generic object
/** @type {object} */ // Object alias
/** @type {Function} */ // Generic function
/** @type {Array} */ // Generic array
/** @type {*} */ // Any type
/** @type {?} */ // Unknown type
```

### Arrays

```javascript
/** @type {Array} */ // Generic array
/** @type {Array<string>} */ // Array of strings
/** @type {string[]} */ // Array of strings (short syntax)
/** @type {Array.<string>} */ // Array of strings (Closure Compiler)
/** @type {Array<Array<number>>} */ // 2D array
```

### Unions and Nullable

```javascript
/** @type {(string|number)} */ // String OR number
/** @type {string|number|null} */ // String, number or null
/** @type {?string} */ // String or null (nullable)
/** @type {!string} */ // String, never null
```

### Functions

```javascript
/** @type {Function} */ // Generic function
/** @type {function} */ // Generic function
/** @type {function(): void} */ // No params, no return
/** @type {function(string): boolean} */ // With param and return
/** @type {function(string, number): void} */ // Multiple params
/** @type {function(...number): number} */ // Rest params
/** @type {function(string=): void} */ // Optional param
```

### Objects and Records

```javascript
/** @type {Object<string, number>} */ // Object with string keys and number values
/** @type {{name: string, age: number}} */ // Specific record/shape
/** @type {{name: string, age?: number}} */ // With optional property
```

### Generics

```javascript
/** @type {Promise<User>} */
/** @type {Map<string, User>} */
/** @type {Set<number>} */
/** @type {WeakMap<Object, string>} */
/** @type {IterableIterator<number>} */
```

### Import Types (TypeScript/JS with checkJs)

```javascript
/** @type {import('./types').Config} */
/** @type {import('express').Request} */
/** @param {import('./user').User} user */
```

---

## Complete Examples

### @param with Object Properties

```javascript
/**
 * Creates an HTTP request.
 * @param {Object} options - Request options.
 * @param {string} options.url - Target URL.
 * @param {('GET'|'POST'|'PUT'|'DELETE')} [options.method='GET'] - HTTP method.
 * @param {Object.<string, string>} [options.headers] - HTTP headers.
 * @param {*} [options.body] - Request body.
 * @returns {Promise<Response>}
 */
function request(options) {}
```

### Complete @typedef

```javascript
/**
 * Application configuration.
 * @typedef {Object} AppConfig
 * @property {string} name - App name.
 * @property {number} port - Server port.
 * @property {boolean} [debug=false] - Debug mode.
 * @property {DatabaseConfig} database - DB config.
 */

/**
 * Database configuration.
 * @typedef {Object} DatabaseConfig
 * @property {string} host
 * @property {number} port
 * @property {string} username
 * @property {string} password
 */
```

### Complete @callback

```javascript
/**
 * Callback for processing search results.
 * @callback SearchCallback
 * @param {Error|null} error - Error if occurred, null if success.
 * @param {SearchResult[]} results - Found results.
 * @param {Object} metadata - Search metadata.
 * @param {number} metadata.total - Total results.
 * @param {number} metadata.page - Current page.
 * @returns {void}
 */
```

### @example with Multiple Cases

```javascript
/**
 * Formats a number as currency.
 * @param {number} value - Value to format.
 * @param {string} [currency='USD'] - ISO currency code.
 * @returns {string} Formatted value.
 * @example
 * // Default format (USD)
 * formatCurrency(1234.56);
 * // => "$1,234.56"
 *
 * @example
 * // With specific currency
 * formatCurrency(1234.56, 'EUR');
 * // => "€1,234.56"
 *
 * @example
 * // Negative values
 * formatCurrency(-500, 'USD');
 * // => "-$500.00"
 */
```

### Documented Class

```javascript
/**
 * HTTP client with automatic retry.
 * @class
 * @implements {Disposable}
 * @example
 * const client = new HttpClient({ timeout: 5000 });
 * const data = await client.get('/api/users');
 */
class HttpClient {
	/**
	 * Creates a client instance.
	 * @param {Object} [options={}] - Configuration options.
	 * @param {number} [options.timeout=30000] - Timeout in ms.
	 * @param {number} [options.retries=3] - Number of retries.
	 */
	constructor(options = {}) {
		/**
		 * Configured timeout.
		 * @type {number}
		 * @readonly
		 */
		this.timeout = options.timeout ?? 30000;

		/**
		 * Number of retries.
		 * @type {number}
		 * @private
		 */
		this._retries = options.retries ?? 3;
	}

	/**
	 * Performs a GET request.
	 * @param {string} url - URL to query.
	 * @param {Object.<string, string>} [headers] - Additional headers.
	 * @returns {Promise<*>} Parsed response.
	 * @throws {HttpError} If response is not successful.
	 * @async
	 */
	async get(url, headers) {}

	/**
	 * Releases client resources.
	 * @returns {void}
	 * @override
	 */
	dispose() {}
}
```
