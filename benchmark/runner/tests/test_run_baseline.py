from __future__ import annotations

import os
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from unittest import mock


RUNNER_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RUNNER_ROOT))

import run_baseline as baseline  # noqa: E402
import tool  # noqa: E402


class CommandLineTests(unittest.TestCase):
    def test_mapping_file_is_the_only_skill_run_selector(self) -> None:
        with mock.patch.object(
            sys,
            "argv",
            ["run_baseline.py", "--mapping-file", "custom.jsonl"],
        ):
            args = baseline.parse_args()

        self.assertEqual(args.mapping_file, Path("custom.jsonl"))
        self.assertFalse(args.no_skill)

    def test_no_skill_remains_a_separate_selector(self) -> None:
        with mock.patch.object(sys, "argv", ["run_baseline.py", "--no-skill"]):
            args = baseline.parse_args()

        self.assertTrue(args.no_skill)
        self.assertIsNone(args.mapping_file)

    def test_legacy_named_mapping_flags_are_rejected(self) -> None:
        for option in ("--standard", "--high-cost", "--selected", "--mapping_file"):
            with self.subTest(option=option):
                with (
                    mock.patch.object(
                        sys,
                        "argv",
                        ["run_baseline.py", option, "mapping.jsonl"],
                    ),
                    mock.patch("sys.stderr"),
                    self.assertRaises(SystemExit) as raised,
                ):
                    baseline.parse_args()

                self.assertEqual(raised.exception.code, 2)


class TaskMajorScheduleTests(unittest.TestCase):
    def test_repeats_of_each_task_are_adjacent(self) -> None:
        self.assertEqual(
            baseline.task_major_schedule(["task-a", "task-b"], [1, 2, 3]),
            [
                ("task-a", 1),
                ("task-a", 2),
                ("task-a", 3),
                ("task-b", 1),
                ("task-b", 2),
                ("task-b", 3),
            ],
        )


class DockerMemoryMonitorTests(unittest.TestCase):
    def test_monitor_sums_current_memory_across_task_containers(self) -> None:
        monitor = baseline.DockerMemoryMonitor("docker", "task-a")
        monitor._record_sample("first", 2 * 1024 * 1024)
        monitor._record_sample("second", 3 * 1024 * 1024)

        self.assertEqual(monitor.peak_memory_mib, 5.0)
        self.assertEqual(monitor.metric, "container_cgroup_memory")
        self.assertEqual(monitor.sample_count, 2)

    def test_sampler_uses_one_persistent_cgroup_reader_at_100ms(self) -> None:
        monitor = baseline.DockerMemoryMonitor("docker", "task-a")

        command = monitor._sampler_command("container-id")

        self.assertEqual(command[:3], ["docker", "exec", "container-id"])
        self.assertIn("/sys/fs/cgroup/memory.current", command[-1])
        self.assertIn("sleep 0.100", command[-1])

    def test_event_stream_uses_actor_fields_supported_by_docker(self) -> None:
        monitor = baseline.DockerMemoryMonitor("docker", "task-a")

        command = monitor._event_command()

        self.assertIn("{{.Actor.ID}}", command[-1])
        self.assertIn('index .Actor.Attributes "name"', command[-1])

    def test_project_label_is_used_to_isolate_parallel_batches(self) -> None:
        expected = Path(r"E:\runs\batch-a\task-a\mapping\task-a\environment")
        monitor = baseline.DockerMemoryMonitor(
            "docker",
            "task-a",
            project_working_dir=expected,
        )
        completed = baseline.subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout=str(expected).replace("\\", "/") + "\n",
            stderr="",
        )

        with mock.patch.object(monitor, "_docker_command", return_value=completed):
            matched = monitor._matches_project("container-id")

        self.assertTrue(matched)


class ResourceAwareScheduleTests(unittest.TestCase):
    @staticmethod
    def write_task(root: Path, task_id: str, cpus: int, memory_mib: int) -> None:
        task_dir = root / task_id
        task_dir.mkdir(parents=True)
        (task_dir / "task.toml").write_text(
            "[environment]\n"
            f"cpus = {cpus}\n"
            f"memory_mb = {memory_mib}\n",
            encoding="utf-8",
        )

    def test_plan_runs_light_tasks_first_and_heavy_tasks_exclusively(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            tasks_root = Path(temp)
            self.write_task(tasks_root, "light-a", 2, 4096)
            self.write_task(tasks_root, "heavy", 9, 4096)
            self.write_task(tasks_root, "light-b", 4, 8192)

            light, heavy = baseline.build_execution_plan(
                ["light-a", "heavy", "light-b"],
                tasks_root,
                max_parallel_cpus=16,
                max_parallel_memory_mib=24 * 1024,
            )

        self.assertEqual([task.task_id for task in light], ["light-a", "light-b"])
        self.assertEqual([task.task_id for task in heavy], ["heavy"])
        self.assertEqual([task.task_index for task in light], [1, 3])
        self.assertTrue(heavy[0].heavy)

    def test_plan_rejects_task_over_budget(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            tasks_root = Path(temp)
            self.write_task(tasks_root, "too-large", 17, 4096)

            with self.assertRaisesRegex(ValueError, "cannot fit"):
                baseline.build_execution_plan(
                    ["too-large"],
                    tasks_root,
                    max_parallel_cpus=16,
                    max_parallel_memory_mib=24 * 1024,
                )

    def test_resources_must_be_declared(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            tasks_root = Path(temp)
            task_dir = tasks_root / "missing-memory"
            task_dir.mkdir()
            (task_dir / "task.toml").write_text(
                "[environment]\ncpus = 1\n",
                encoding="utf-8",
            )

            with self.assertRaisesRegex(ValueError, "environment.memory_mb"):
                baseline.task_resources("missing-memory", tasks_root)

    def test_light_tasks_overlap_and_heavy_task_starts_afterward(self) -> None:
        resources = baseline.TaskResources(cpus=1, memory_mib=1024)
        light = [
            baseline.ScheduledTask(1, "light-a", resources, False),
            baseline.ScheduledTask(2, "light-b", resources, False),
        ]
        heavy = [baseline.ScheduledTask(3, "heavy", resources, True)]
        light_barrier = threading.Barrier(2)
        state_lock = threading.Lock()
        completed_light: set[str] = set()
        heavy_started_after_light = False

        def fake_run(
            task: baseline.ScheduledTask,
            **_: object,
        ) -> baseline.TaskExecutionResult:
            nonlocal heavy_started_after_light
            if not task.heavy:
                light_barrier.wait(timeout=2)
                with state_lock:
                    completed_light.add(task.task_id)
            else:
                with state_lock:
                    heavy_started_after_light = completed_light == {"light-a", "light-b"}
            return baseline.TaskExecutionResult([], [])

        with mock.patch.object(baseline, "run_scheduled_task", side_effect=fake_run):
            results = baseline.execute_plan(light, heavy, task_workers=2)

        self.assertEqual(len(results), 3)
        self.assertTrue(heavy_started_after_light)

    def test_scheduled_task_supports_rerun_preparation(self) -> None:
        resources = baseline.TaskResources(cpus=1, memory_mib=1024)
        scheduled = baseline.ScheduledTask(1, "task-a", resources, False)
        prepared: list[tuple[str, str]] = []

        with tempfile.TemporaryDirectory() as temp:
            batch_dir = Path(temp) / "Example_Run001"
            (batch_dir / "Repeat_1").mkdir(parents=True)

            with (
                mock.patch.object(baseline, "run_task", return_value=0) as run_task,
                mock.patch("builtins.print"),
            ):
                result = baseline.run_scheduled_task(
                    scheduled,
                    task_count=1,
                    repeat_numbers=[1],
                    condition="mapping",
                    harbor="harbor",
                    docker="docker",
                    api={},
                    batch_dir=batch_dir,
                    tasks_root=Path(temp),
                    mapping_file=Path(temp) / "mapping.jsonl",
                    skill_paths_by_task={"task-a": []},
                    operation="rerun",
                    before_run=lambda task_id, current_dir: prepared.append(
                        (task_id, current_dir.name)
                    ),
                )

        self.assertEqual(prepared, [("task-a", "Repeat_1")])
        self.assertEqual(result.failures, [])
        self.assertEqual(run_task.call_args.kwargs["operation"], "rerun")


class SkillMappingTests(unittest.TestCase):
    def test_jsonl_mapping_resolves_central_skill_directories(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            skills_root = root / "skills"
            selected_skill = skills_root / "chosen-skill"
            selected_skill.mkdir(parents=True)
            (selected_skill / "SKILL.md").write_text("# Chosen", encoding="utf-8")
            mapping_file = root / "selected.jsonl"
            mapping_file.write_text(
                '{"task_id":"task-a","skills":["chosen-skill"]}\n',
                encoding="utf-8",
            )

            self.assertEqual(
                baseline.resolve_skill_mapping(
                    mapping_file, ["task-a"], skills_root
                ),
                {"task-a": [selected_skill]},
            )

    def test_mapping_validation_reports_all_missing_references(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            skills_root = root / "skills"
            skills_root.mkdir()
            mapping_file = root / "standard.jsonl"
            mapping_file.write_text(
                '{"task_id":"task-a","skills":["missing-skill"]}\n',
                encoding="utf-8",
            )

            with self.assertRaisesRegex(
                ValueError, "(?s)Skill not found 'missing-skill'.*no mapping entry"
            ):
                baseline.resolve_skill_mapping(
                    mapping_file, ["task-a", "task-b"], skills_root
                )

    def test_yaml_mapping_uses_the_same_record_schema(self) -> None:
        try:
            import yaml  # noqa: F401
        except ImportError:
            self.skipTest("PyYAML is not installed")

        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            skill_dir = root / "skills" / "chosen-skill"
            skill_dir.mkdir(parents=True)
            (skill_dir / "SKILL.md").write_text("# Chosen", encoding="utf-8")
            mapping_file = root / "standard.yaml"
            mapping_file.write_text(
                "- task_id: task-a\n  skills:\n    - chosen-skill\n",
                encoding="utf-8",
            )

            resolved = baseline.resolve_skill_mapping(
                mapping_file, ["task-a"], root / "skills"
            )

        self.assertEqual([path.name for path in resolved["task-a"]], ["chosen-skill"])


class SessionSkillAuditTests(unittest.TestCase):
    def test_raw_session_recovers_available_and_loaded_skills(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            session_path = Path(temp) / "session.jsonl"
            session_path.write_text(
                "\n".join(
                    [
                        '{"type":"response_item","payload":{"type":"message","role":"developer","content":[{"type":"input_text","text":"<skills_instructions>\\n### Available skills\\n- chosen-skill (file: /root/.agents/skills/chosen-skill/SKILL.md)"}]}}',
                        '{"type":"response_item","payload":{"type":"function_call","call_id":"call-1","name":"exec_command","arguments":"cat /root/.agents/skills/chosen-skill/SKILL.md"}}',
                    ]
                ),
                encoding="utf-8",
            )

            available, loaded, evidence = tool.raw_session_skill_usage(
                session_path,
                {"chosen-skill"},
            )

        self.assertEqual(available, {"chosen-skill"})
        self.assertEqual(loaded, {"chosen-skill"})
        self.assertIn("chosen-skill", evidence)

    def test_preloaded_skills_count_as_loaded_and_remain_distinguishable(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            job_dir = Path(temp)
            trajectory_path = job_dir / "trial-1" / "agent" / "trajectory.json"
            trajectory_path.parent.mkdir(parents=True)
            trajectory_path.write_text(
                '{"steps":[{"source":"system","message":"<skills_instructions>\\n### Available skills\\n- chosen-skill (file: /root/.agents/skills/chosen-skill/SKILL.md)"}]}',
                encoding="utf-8",
            )

            audit = tool.analyze_skill_usage(
                job_dir,
                ["chosen-skill"],
                preloaded_skills=["chosen-skill"],
            )

        self.assertEqual(audit["loaded_skills"], ["chosen-skill"])
        self.assertEqual(audit["preloaded_skills"], ["chosen-skill"])
        self.assertEqual(audit["explicitly_loaded_skills"], [])


class StagedTaskPathTests(unittest.TestCase):
    @unittest.skipUnless(os.name == "nt", "Windows MAX_PATH only")
    def test_known_deep_task_path_stays_below_max_path(self) -> None:
        execution_dir = (
            baseline.RUNS_ROOT
            / "single_High Cost_Run999"
            / "Repeat_999"
        )
        task_id = "crystallographic-wyckoff-position-analysis"
        staged_file = (
            baseline.batch_work_root(execution_dir)
            / task_id
            / "high_cost"
            / task_id
            / "environment"
            / "skills"
            / "pymatgen"
            / "references"
            / "transformations_workflows.md"
        )
        self.assertLess(len(str(staged_file)), 260)


class CopyTaskTests(unittest.TestCase):
    @unittest.skipUnless(os.name == "nt", "Windows extended paths only")
    def test_copy_task_supports_paths_beyond_max_path(self) -> None:
        task_id = "crystallographic-wyckoff-position-analysis"
        relative_file = (
            Path("environment")
            / "skills"
            / "pymatgen"
            / "references"
            / "transformations_workflows.md"
        )
        probe_root = baseline.CURRENT_TASKS_ROOT / "_max_path_test"

        with tempfile.TemporaryDirectory(dir=baseline.WORK_ROOT) as source_temp:
            source = Path(source_temp) / task_id / relative_file
            source.parent.mkdir(parents=True)
            source.write_text("probe", encoding="utf-8")

            unpadded = probe_root / task_id / relative_file
            padding = "x" * max(1, 260 - len(str(unpadded)))
            dataset_root = probe_root / padding
            copied_file = dataset_root / task_id / relative_file
            self.assertGreaterEqual(len(str(copied_file)), 260)

            try:
                baseline.copy_task(task_id, dataset_root, Path(source_temp))
                self.assertEqual(
                    baseline.extended_length_path(copied_file).read_text(
                        encoding="utf-8"
                    ),
                    "probe",
                )
            finally:
                baseline.clean_path(probe_root, baseline.CURRENT_TASKS_ROOT)


class SummaryTokenTests(unittest.TestCase):
    def test_harbor_summary_aggregates_agent_tokens(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            run_dir = Path(temp)
            job_dir = run_dir / baseline.JOB_NAME
            baseline.write_json(
                job_dir / "result.json",
                {"stats": {}, "n_total_trials": 2},
            )
            for index, (input_tokens, output_tokens) in enumerate(
                ((120, 30), (80, 20)),
                start=1,
            ):
                baseline.write_json(
                    job_dir / f"trial-{index}" / "result.json",
                    {
                        "agent_result": {
                            "n_input_tokens": input_tokens,
                            "n_output_tokens": output_tokens,
                        },
                        "verifier_result": {"rewards": {"reward": 1.0}},
                    },
                )

            summary = baseline.harbor_summary(run_dir)

        self.assertIsNotNone(summary)
        assert summary is not None
        self.assertEqual(summary["agent_input_tokens"], 200)
        self.assertEqual(summary["agent_output_tokens"], 50)

    def test_harbor_summary_recovers_tokens_from_timeout_checkpoint(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            run_dir = Path(temp)
            job_dir = run_dir / baseline.JOB_NAME
            baseline.write_json(
                job_dir / "result.json",
                {"stats": {}, "n_total_trials": 1},
            )
            trial_dir = job_dir / "timed-out-trial"
            baseline.write_json(
                trial_dir / "result.json",
                {
                    "agent_result": {
                        "n_input_tokens": None,
                        "n_output_tokens": None,
                    },
                    "exception_info": {"exception_type": "AgentTimeoutError"},
                },
            )
            baseline.write_json(
                trial_dir / "agent" / "token_usage.json",
                {
                    "type": "event_msg",
                    "payload": {
                        "type": "token_count",
                        "info": {
                            "total_token_usage": {
                                "input_tokens": 4321,
                                "output_tokens": 87,
                            }
                        },
                    },
                },
            )

            summary = baseline.harbor_summary(run_dir)

        self.assertIsNotNone(summary)
        assert summary is not None
        self.assertEqual(summary["agent_input_tokens"], 4321)
        self.assertEqual(summary["agent_output_tokens"], 87)

    def test_csv_rows_replace_run_summary_with_agent_tokens(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            batch_dir = Path(temp)
            task_id = "task-a"
            baseline.write_json(
                batch_dir
                / task_id
                / baseline.CONDITION_DIR_NAMES["mapping"]
                / "run_summary.json",
                {
                    "status": "completed",
                    "passed": True,
                    "agent_input_tokens": 1234,
                    "agent_output_tokens": 56,
                },
            )

            rows, _ = baseline.build_batch_summary_rows(
                batch_dir,
                [task_id],
                "mapping",
            )

        self.assertNotIn("run_summary", baseline.SUMMARY_FIELDNAMES)
        self.assertNotIn("run_summary", rows[0])
        self.assertEqual(rows[0]["agent_input_tokens"], 1234)
        self.assertEqual(rows[0]["agent_output_tokens"], 56)


if __name__ == "__main__":
    unittest.main()
