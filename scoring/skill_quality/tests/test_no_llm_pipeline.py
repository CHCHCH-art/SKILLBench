from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


PIPELINE = Path(__file__).resolve().parents[1] / "run_skill_pipeline.py"
MERGER = PIPELINE.with_name("merge_all_desc.py")


class NoLlmPipelineTest(unittest.TestCase):
    def test_merge_default_mode_still_includes_llm_labels(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            skill_dir = Path(temp_dir) / "example-skill"
            skill_dir.mkdir()
            (skill_dir / "Base Describe.md").write_text(
                "# Base Describe\n\n"
                "skill_id: example-1\n"
                "skill_name: Example\n"
                "skill_dir_name: example-skill\n",
                encoding="utf-8",
            )
            (skill_dir / "skill_llm_describe.json").write_text(
                json.dumps(
                    {
                        "task_tags": [" Example:Action "],
                        "service_cost_score": "3",
                        "service_safety_score": 4,
                    }
                ),
                encoding="utf-8",
            )

            completed = subprocess.run(
                [sys.executable, str(MERGER), temp_dir],
                text=True,
                encoding="utf-8",
                errors="replace",
                capture_output=True,
                timeout=30,
            )
            self.assertEqual(
                completed.returncode,
                0,
                msg=f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}",
            )
            record = json.loads(
                (skill_dir / "All_Desc.jsonl").read_text(encoding="utf-8")
            )
            self.assertEqual(record["task_tags"], ["example:action"])
            self.assertEqual(record["service_cost_score"], 3)
            self.assertEqual(record["service_safety_score"], 4)

    def test_generates_base_only_all_jsonl_and_ignores_stale_labels(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            dataset_root = Path(temp_dir) / "Example"
            skills_dir = dataset_root / "skills"
            skill_dir = skills_dir / "example-skill"
            skill_dir.mkdir(parents=True)

            (dataset_root / "Base Describe.md").write_text(
                "# Base Describe\n\n"
                "source_platform: local\n"
                "source_type: test\n"
                "source_url: \n"
                "license: UNKNOWN\n",
                encoding="utf-8",
            )
            (skill_dir / "SKILL.md").write_text(
                "---\n"
                "name: example-skill\n"
                "description: A valid test skill.\n"
                "---\n\n"
                "# Example\n\nDo the example task.\n",
                encoding="utf-8",
            )
            (skill_dir / "skill_llm_describe.json").write_text(
                json.dumps(
                    {
                        "task_tags": ["stale:label"],
                        "service_cost_score": 10,
                        "service_safety_score": 10,
                    }
                ),
                encoding="utf-8",
            )

            completed = subprocess.run(
                [
                    sys.executable,
                    str(PIPELINE),
                    str(skills_dir),
                    "--no_llm",
                    "--report-dir",
                    str(dataset_root / "report"),
                    "--invalid-dir",
                    str(dataset_root / "invalid"),
                ],
                text=True,
                encoding="utf-8",
                errors="replace",
                capture_output=True,
                timeout=30,
            )

            self.assertEqual(
                completed.returncode,
                0,
                msg=f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}",
            )

            records = [
                json.loads(line)
                for line in (dataset_root / "All.jsonl").read_text(encoding="utf-8").splitlines()
                if line.strip()
            ]
            self.assertEqual(len(records), 1)
            self.assertEqual(records[0]["skill_id"], "Example-1")
            self.assertEqual(records[0]["skill_dir_name"], "example-skill")
            for field in (
                "task_tags",
                "service_cost_score",
                "service_safety_score",
            ):
                self.assertNotIn(field, records[0])

            report = json.loads(
                (dataset_root / "report" / "pipeline_report.json").read_text(
                    encoding="utf-8"
                )
            )
            self.assertFalse(report["llm_enabled"])
            skipped = {
                step["step"]: step.get("reason")
                for step in report["steps"]
                if step["status"] == "skipped"
            }
            self.assertEqual(skipped["ds"], "no_llm")
            self.assertEqual(skipped["scan"], "no_llm")
            self.assertEqual(skipped["backup"], "no_llm")


if __name__ == "__main__":
    unittest.main()
