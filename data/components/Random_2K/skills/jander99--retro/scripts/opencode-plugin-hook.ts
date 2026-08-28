/**
 * ⚠️  SPECULATIVE IMPLEMENTATION
 *
 * This script was written based on available documentation and community examples.
 * The OpenCode plugin hook API may have changed since this was written.
 *
 * Before using: verify the hook API at https://opencode.ai/docs or the OpenCode source.
 * This script is provided as a starting point, not a production-ready solution.
 *
 * Last verified: 2025 (approximate)
 */

/**
 * OpenCode Plugin: Auto-trigger retro skill when all todos are complete
 *
 * Install: copy this file into your OpenCode plugin directory, then load it
 * via your opencode.config.ts (or opencode.config.js) with:
 *
 *   import retroHook from "./plugins/retro-auto-trigger";
 *   export default defineConfig({ plugins: [retroHook()] });
 *
 * How it works:
 *   - Listens to tool.execute.after for the "todowrite" tool
 *   - After every TodoWrite call, checks if ALL todos are in a terminal state
 *     (completed or cancelled)
 *   - If yes, and at least one todo is actually "completed" (not just all cancelled),
 *     injects a system message asking the agent to run the retro skill
 *
 * Detection logic (from research of OpenCode source packages/opencode/src/tool/todo.ts):
 *   - metadata.todos is the full todo array after the write
 *   - Terminal states: "completed" | "cancelled"
 *   - All-done condition: todos.length > 0 AND todos.every(t => terminal(t.status))
 *                         AND todos.some(t => t.status === "completed")
 */

import type { Plugin, ToolExecuteAfterHookContext } from "@opencode-ai/plugin";

// v2 TRIGGER: This hook integrates with OpenCode session lifecycle.
// RETRO WORKFLOW:
//   - SESSION_START: Retrieve relevant lessons with retro-lessons.sh inject
//     and prepend to the session context for proactive guidance.
//   - SESSION_END: Call retro skill, write v2 entries with Trigger/Action/Scope headers.
// See: skills/retro/references/injection.md, skills/retro/references/retrieval.md

type TodoStatus = "pending" | "in_progress" | "completed" | "cancelled";
interface Todo {
  content: string;
  status: TodoStatus;
  priority: "high" | "medium" | "low";
}

const TERMINAL: Set<TodoStatus> = new Set(["completed", "cancelled"]);

function allTodosTerminal(todos: Todo[]): boolean {
  if (!todos || todos.length === 0) return false;
  const hasCompleted = todos.some((t) => t.status === "completed");
  const allTerminal = todos.every((t) => TERMINAL.has(t.status));
  return allTerminal && hasCompleted;
}

export function retroAutoTrigger(): Plugin {
  return {
    name: "retro-auto-trigger",

    hooks: {
      async "tool.execute.after"(ctx: ToolExecuteAfterHookContext) {
        // Only act on the todowrite tool
        if (ctx.tool !== "todowrite") return;

        const todos: Todo[] | undefined = ctx.output?.metadata?.todos;
        if (!todos) return;

        if (allTodosTerminal(todos)) {
          // Inject a message instructing the agent to run the retro skill.
          // The message is appended to the session as a user turn so the
          // agent sees it at the start of its next response.
          await ctx.session.appendMessage({
            role: "user",
            content:
              "✅ All tasks are complete. Please run the **retro** skill now: " +
              "load `@skills/retro/SKILL.md`, assess the session using the " +
              "Sailboat+Forward rubric, and write the entry to `LESSONS.md`.",
          });
        }
      },
    },
  };
}

export default retroAutoTrigger;
