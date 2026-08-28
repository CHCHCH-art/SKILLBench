# Using session_read in OpenCode

`session_read` is available in OpenCode. It returns the full message history for a session,
enabling high-fidelity retrospectives based on the complete transcript rather than just what
remains in the context window.

## How to Use It

```
session_read(session_id: "<current session id>")
```

To get the current session ID, use `session_list` (lists recent sessions) and take the most
recent one, or use the session ID from the environment if available.

## What to Look For in the Transcript

When analyzing the transcript for a retro, scan for:

### Correction Loops
A correction loop is any sequence where:
1. Agent takes an action
2. Action fails OR user corrects the agent
3. Agent retries

Each loop is an Anchor candidate. Note: *what* assumption caused the loop.

### Tool Call Failures
Look for tool calls that returned errors. Categorize by:
- Wrong path / file not found → assumption about structure
- Permission denied → assumption about access
- Unexpected format → assumption about data shape
- Timeout → assumption about performance

### User Redirects
Any message where the user says "no, actually...", "wait...", "that's not what I meant",
"you should have...". These are strong Anchor signals.

### What Completed Without Incident
Steps that were planned, executed, and succeeded on first try → Wind candidates.

## Graceful Degradation

If `session_read` is not available (not in OpenCode, or session ID not accessible):

```
Note in the retro entry: "> Reconstructed from context window (session_read unavailable)"
```

Then use the current context window to reconstruct:
- What the original task was (from earliest visible messages)
- What was tried (from tool calls visible in context)
- What corrections occurred (from visible user messages)
- What the final state is (current state of files / output)

This produces a lower-fidelity but still useful retro. The key anchor signals (correction loops,
user redirects) are usually still visible in a typical context window.
