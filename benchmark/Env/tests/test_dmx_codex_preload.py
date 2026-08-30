import asyncio
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock

from my_agents.dmx_codex import DMXCodex


class DMXCodexPreloadTests(unittest.TestCase):
    def test_preloaded_prompt_is_streamed_from_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            agent = DMXCodex(
                Path(temp_dir),
                extra_env={
                    "DMX_CODEX_PRELOAD_SKILLS": "true",
                    "OPENAI_API_KEY": "test-key",
                },
                model_name="test-model",
                skills_dir="/root/task-skills",
            )
            agent.exec_as_agent = AsyncMock()
            agent._checkpoint_remote_token_usage = AsyncMock()

            environment = SimpleNamespace(default_user=None)
            asyncio.run(agent.run("task body", environment, SimpleNamespace()))

            commands = [
                call.kwargs["command"] for call in agent.exec_as_agent.await_args_list
            ]
            codex_command = next(
                command for command in commands if "codex exec " in command
            )

            self.assertIn('cat "$skill_file"', codex_command)
            self.assertIn("<task_instruction>", codex_command)
            self.assertIn("-- -", codex_command)
            self.assertIn(
                '< "$CODEX_HOME/preloaded-instruction.md"', codex_command
            )
            self.assertNotIn("preloaded_instruction=$(", codex_command)
            self.assertNotIn('"$preloaded_instruction"', codex_command)
            self.assertNotIn("</dev/null", codex_command)


if __name__ == "__main__":
    unittest.main()
