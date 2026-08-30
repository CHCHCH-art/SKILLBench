# JSDoc Best Practices

Detailed guide with examples of correct and incorrect JSDoc usage.

## Contents

- [Describe What and Why, Not How](#describe-what-and-why-not-how)
- [Document Optional Parameters Correctly](#document-optional-parameters-correctly)
- [Use @example Effectively](#use-example-effectively)
- [Deprecation Done Right](#deprecation-done-right)
- [TypeScript-Specific Practices](#typescript-specific-practices)
- [Keep Documentation in Sync](#keep-documentation-in-sync)
- [Avoid Common Mistakes](#avoid-common-mistakes)

---

## Describe What and Why, Not How

The code shows _how_ something works. Documentation should explain _what_ it does and _why_.

### Good

```javascript
/**
 * Calculates the compound interest for an investment.
 * Uses the standard compound interest formula to account for
 * interest that accrues on previously earned interest.
 * @param {number} principal - Initial investment amount.
 * @param {number} rate - Annual interest rate (e.g., 0.05 for 5%).
 * @param {number} years - Investment duration in years.
 * @returns {number} Final amount after compound interest.
 */
function calculateCompoundInterest(principal, rate, years) {
	return principal * Math.pow(1 + rate, years);
}
```

### Bad

```javascript
/**
 * This function takes principal, rate and years as parameters.
 * It multiplies principal by (1 + rate) raised to the power of years.
 * Then it returns the result.
 * @param {number} principal - The principal parameter.
 * @param {number} rate - The rate parameter.
 * @param {number} years - The years parameter.
 * @returns {number} The result of the calculation.
 */
function calculateCompoundInterest(principal, rate, years) {
	return principal * Math.pow(1 + rate, years);
}
```

**Why it's bad:**

- Restates the code instead of explaining purpose
- Parameter descriptions add no value ("The principal parameter")
- Doesn't explain what compound interest is or when to use it

---

## Document Optional Parameters Correctly

Use brackets `[param]` for optional parameters and `[param=default]` to show defaults.

### Good

```javascript
/**
 * Formats a number with thousand separators.
 * @param {number} value - Number to format.
 * @param {string} [locale='en-US'] - Locale for formatting.
 * @param {Object} [options] - Additional formatting options.
 * @param {number} [options.minimumFractionDigits=0] - Minimum decimal places.
 * @param {number} [options.maximumFractionDigits=2] - Maximum decimal places.
 * @returns {string} Formatted number string.
 * @example
 * formatNumber(1234567);           // "1,234,567"
 * formatNumber(1234.5, 'de-DE');   // "1.234,5"
 * formatNumber(99.999, 'en-US', { maximumFractionDigits: 1 }); // "100.0"
 */
function formatNumber(value, locale = "en-US", options = {}) {
	return new Intl.NumberFormat(locale, options).format(value);
}
```

### Bad

```javascript
/**
 * Formats a number with thousand separators.
 * @param {number} value - Number to format.
 * @param {string} locale - Locale for formatting.
 * @param {Object} options - Additional formatting options.
 * @returns {string} Formatted number string.
 */
function formatNumber(value, locale = "en-US", options = {}) {
	return new Intl.NumberFormat(locale, options).format(value);
}
```

**Why it's bad:**

- Doesn't indicate which parameters are optional
- Doesn't show default values
- Caller doesn't know they can omit `locale` and `options`

---

## Use @example Effectively

Examples should demonstrate real use cases, edge cases, and expected outputs.

### Good

```javascript
/**
 * Truncates a string to a maximum length, adding ellipsis if needed.
 * @param {string} text - Text to truncate.
 * @param {number} maxLength - Maximum length including ellipsis.
 * @returns {string} Truncated string.
 * @example
 * // Basic truncation
 * truncate("Hello, World!", 8);
 * // => "Hello..."
 *
 * @example
 * // String shorter than maxLength (no change)
 * truncate("Hi", 10);
 * // => "Hi"
 *
 * @example
 * // Edge case: maxLength less than 4
 * truncate("Hello", 3);
 * // => "..."
 *
 * @example
 * // Empty string
 * truncate("", 10);
 * // => ""
 */
function truncate(text, maxLength) {
	if (text.length <= maxLength) return text;
	if (maxLength < 4) return "...".slice(0, maxLength);
	return text.slice(0, maxLength - 3) + "...";
}
```

### Bad

```javascript
/**
 * Truncates a string to a maximum length, adding ellipsis if needed.
 * @param {string} text - Text to truncate.
 * @param {number} maxLength - Maximum length including ellipsis.
 * @returns {string} Truncated string.
 * @example
 * truncate("Hello", 3);
 */
function truncate(text, maxLength) {
	if (text.length <= maxLength) return text;
	if (maxLength < 4) return "...".slice(0, maxLength);
	return text.slice(0, maxLength - 3) + "...";
}
```

**Why it's bad:**

- Single example doesn't show the range of behavior
- No expected output shown
- Edge cases not documented
- Caller can't understand the function without reading the code

---

## Deprecation Done Right

Always provide an alternative and explain migration path.

### Good

```javascript
/**
 * Fetches user data from the API.
 * @deprecated Since v2.0. Use {@link UserService.getUser} instead.
 * Migration: Replace `fetchUser(id)` with `userService.getUser(id)`.
 * Will be removed in v3.0.
 * @param {string} userId - User ID.
 * @returns {Promise<User>} User data.
 */
async function fetchUser(userId) {
	console.warn("fetchUser is deprecated. Use UserService.getUser instead.");
	return userService.getUser(userId);
}
```

### Bad

```javascript
/**
 * @deprecated
 */
async function fetchUser(userId) {
	return userService.getUser(userId);
}
```

**Why it's bad:**

- No alternative provided
- No timeline for removal
- Caller doesn't know how to migrate
- No runtime warning

---

## TypeScript-Specific Practices

In TypeScript, types are already in the code. Use JSDoc for descriptions, examples, and metadata.

### Good

```typescript
/**
 * Validates an email address format.
 * Checks for basic email structure but doesn't verify deliverability.
 * @param email - Email address to validate.
 * @returns True if the format is valid.
 * @example
 * isValidEmail('user@example.com'); // true
 * isValidEmail('invalid-email');     // false
 * @see {@link https://emailregex.com/} for regex details
 */
function isValidEmail(email: string): boolean {
	const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
	return regex.test(email);
}
```

### Bad (redundant types)

```typescript
/**
 * Validates an email address format.
 * @param {string} email - Email address to validate.
 * @returns {boolean} True if the format is valid.
 */
function isValidEmail(email: string): boolean {
	const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
	return regex.test(email);
}
```

**Why it's bad:**

- `{string}` and `{boolean}` duplicate what TypeScript already declares
- Adds noise without value
- Can become out of sync with actual types

### When to use JSDoc types in TypeScript

Use JSDoc types only when you need to add information TypeScript can't express:

```typescript
/**
 * Parses configuration from environment variables.
 * @returns Configuration object with all required fields.
 * @throws {ConfigError} If required variables are missing.
 */
function parseConfig(): Config {
	// TypeScript can't express what exceptions a function throws
}

/**
 * Fetches data from multiple endpoints in parallel.
 * @template T - Response type for all endpoints.
 * @param urls - URLs to fetch.
 * @returns Array of responses in the same order as URLs.
 * @example
 * // Fetch users and posts simultaneously
 * const [users, posts] = await fetchAll<ApiResponse>(['/users', '/posts']);
 */
async function fetchAll<T>(urls: string[]): Promise<T[]> {
	return Promise.all(urls.map((url) => fetch(url).then((r) => r.json())));
}
```

---

## Keep Documentation in Sync

Outdated documentation is worse than no documentation.

### Good Practices

1. **Update docs when changing function signature:**

```javascript
// BEFORE
/**
 * Sends a notification to a user.
 * @param {string} userId - Target user ID.
 * @param {string} message - Notification message.
 */
function notify(userId, message) {}

// AFTER (parameter added)
/**
 * Sends a notification to a user.
 * @param {string} userId - Target user ID.
 * @param {string} message - Notification message.
 * @param {('email'|'push'|'sms')} [channel='push'] - Delivery channel.
 */
function notify(userId, message, channel = "push") {}
```

2. **Document behavior changes:**

```javascript
/**
 * Retries a failed operation with exponential backoff.
 * @param {Function} operation - Async operation to retry.
 * @param {number} [maxRetries=3] - Maximum retry attempts.
 * @returns {Promise<*>} Operation result.
 * @throws {Error} After all retries exhausted.
 * @since 1.0.0
 * @changelog
 * - 2.0.0: Added exponential backoff (was linear)
 * - 1.5.0: Added maxRetries parameter
 */
async function retry(operation, maxRetries = 3) {}
```

### Bad

```javascript
// Code changed but docs not updated
/**
 * Sends a notification to a user.
 * @param {string} userId - Target user ID.
 * @param {string} message - Notification message.
 */
function notify(userId, message, channel = "push", priority = "normal") {}
// Missing: channel and priority parameters!
```

---

## Avoid Common Mistakes

### Mistake 1: Empty or trivial descriptions

```javascript
// Bad
/**
 * @param {string} name - The name.
 * @param {number} age - The age.
 */

// Good
/**
 * @param {string} name - User's display name (max 50 characters).
 * @param {number} age - User's age in years (must be 0-150).
 */
```

### Mistake 2: Documenting obvious getters/setters

```javascript
// Bad - adds no value
/**
 * Gets the user's name.
 * @returns {string} The name of the user.
 */
get name() { return this._name; }

// Good - only if there's something non-obvious
/**
 * Gets the user's display name.
 * Returns the nickname if set, otherwise first name + last name.
 * @returns {string} Display name, never empty.
 */
get displayName() {
  return this.nickname || `${this.firstName} ${this.lastName}`;
}
```

### Mistake 3: Inconsistent style

```javascript
// Bad - mixed styles
/**
 * @param {string} userId The user ID
 * @param {number} limit - Maximum results.
 * @param offset {number} Starting position
 */

// Good - consistent style
/**
 * @param {string} userId - The user ID.
 * @param {number} limit - Maximum results.
 * @param {number} offset - Starting position.
 */
```

### Mistake 4: Wrong types

```javascript
// Bad
/**
 * @param {Array} items - List of items.
 * @returns {Object} Result object.
 */

// Good - be specific
/**
 * @param {Product[]} items - Products to process.
 * @returns {{total: number, tax: number, items: ProcessedProduct[]}} Order summary.
 */
```

### Mistake 5: Missing async/throws documentation

```javascript
// Bad
/**
 * Saves user to database.
 * @param {User} user - User to save.
 * @returns {User} Saved user.
 */
async function saveUser(user) {
	const result = await db.users.insert(user);
	if (!result.ok) throw new DatabaseError("Insert failed");
	return result.user;
}

// Good
/**
 * Saves user to database.
 * @param {User} user - User to save.
 * @returns {Promise<User>} Saved user with generated ID.
 * @throws {DatabaseError} If insert operation fails.
 * @throws {ValidationError} If user data is invalid.
 * @async
 */
async function saveUser(user) {
	const result = await db.users.insert(user);
	if (!result.ok) throw new DatabaseError("Insert failed");
	return result.user;
}
```

### Mistake 6: Not documenting side effects

```javascript
// Bad
/**
 * Logs the user in.
 * @param {string} email
 * @param {string} password
 * @returns {User}
 */
async function login(email, password) {
	const user = await auth.authenticate(email, password);
	localStorage.setItem("token", user.token); // Side effect!
	analytics.track("login", { userId: user.id }); // Side effect!
	return user;
}

// Good
/**
 * Authenticates user and establishes session.
 * Stores auth token in localStorage and tracks login event.
 * @param {string} email - User's email address.
 * @param {string} password - User's password.
 * @returns {Promise<User>} Authenticated user.
 * @throws {AuthError} If credentials are invalid.
 * @fires analytics#login
 * @sideeffect Sets 'token' in localStorage.
 */
async function login(email, password) {
	const user = await auth.authenticate(email, password);
	localStorage.setItem("token", user.token);
	analytics.track("login", { userId: user.id });
	return user;
}
```

---

## Quick Reference: When to Document

| Scenario                   | Document?  | What to include                           |
| -------------------------- | ---------- | ----------------------------------------- |
| Public API function        | Yes        | Full docs with examples                   |
| Complex internal function  | Yes        | Purpose, edge cases                       |
| Simple getter              | No         | Unless non-obvious behavior               |
| Private helper (2-3 lines) | Usually no | Maybe a one-liner                         |
| Deprecated function        | Yes        | Alternative, migration path, removal date |
| Function with side effects | Yes        | All side effects explicitly               |
| Async function             | Yes        | Promise type, possible errors             |
| Generic function           | Yes        | Template parameter explanation            |
