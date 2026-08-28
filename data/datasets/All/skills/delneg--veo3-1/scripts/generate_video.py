#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
Generate videos using grsai.com Veo 3.1 API.

Usage:
    uv run generate_video.py --prompt "your video description" --filename "output.mp4" [--model veo3.1-fast] [--duration 8] [--api-key KEY]
"""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


GRSAI_VIDEO_URL = "https://grsaiapi.com/v1/video/veo"
GRSAI_RESULT_URL = "https://grsaiapi.com/v1/draw/result"

AVAILABLE_MODELS = [
    "veo3.1-fast",
    "veo3.1-fast-1080p",
    "veo3.1-fast-4k",
    "veo3.1-pro",
    "veo3.1-pro-1080p",
    "veo3.1-pro-4k",
]

PERMANENT_KEYWORDS = ("moderation", "nsfw", "invalid", "unauthorized", "forbidden", "not exist")
TRANSIENT_KEYWORDS = ("timeout", "network", "connection", "unavailable", "overload", "retry", "rate limit", "too many")

READ_TIMEOUT = 45      # seconds to wait for API response
DOWNLOAD_TIMEOUT = 300 # seconds to download the video (large files)
POLL_INTERVAL = 5.0    # seconds between status polls
POLL_TIMEOUT = 600     # max seconds to wait for generation to complete


def get_api_key(provided_key: str | None) -> str | None:
    if provided_key:
        return provided_key
    return os.environ.get("GRSAI_API_KEY")


def http_post(url: str, data: dict, api_key: str) -> dict:
    body = json.dumps(data).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=READ_TIMEOUT) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body_text = e.read().decode("utf-8", errors="replace")
        if e.code == 401:
            raise RuntimeError(f"Unauthorized (HTTP 401): check your API key. Details: {body_text}")
        if e.code == 429:
            raise RuntimeError(f"Rate limited (HTTP 429): too many requests. Details: {body_text}")
        if e.code >= 500:
            raise RuntimeError(f"Server error (HTTP {e.code}): {body_text}")
        raise RuntimeError(f"HTTP {e.code}: {body_text}")
    except urllib.error.URLError as e:
        raise RuntimeError(f"Network error connecting to {url}: {e.reason}")
    except TimeoutError:
        raise TimeoutError(f"Request to {url} timed out after {READ_TIMEOUT}s")


def is_permanent_error(msg: str) -> bool:
    msg_lower = msg.lower()
    return any(kw in msg_lower for kw in PERMANENT_KEYWORDS)


def submit_task(payload: dict, api_key: str) -> str:
    """Submit a generation task, return task_id."""
    response = http_post(GRSAI_VIDEO_URL, payload, api_key)
    if response.get("code") != 0:
        raise RuntimeError(response.get("msg", "Unknown error from API"))
    task_id = response.get("data", {}).get("id")
    if not task_id:
        raise RuntimeError(f"No task ID in response: {response}")
    return task_id


def poll_result(task_id: str, api_key: str) -> dict:
    """Poll for task result until succeeded, failed, or timeout."""
    deadline = time.time() + POLL_TIMEOUT
    while time.time() < deadline:
        result = http_post(GRSAI_RESULT_URL, {"id": task_id}, api_key)
        if result.get("code") != 0:
            raise RuntimeError(f"Result API error: {result.get('msg')}")
        data = result.get("data", {})
        status = data.get("status")
        progress = data.get("progress", 0)
        print(f"  Progress: {progress}% ({status})")
        if status == "succeeded":
            return data
        if status == "failed":
            reason = (data.get("failure_reason", "") + " " + data.get("error", "")).strip()
            raise RuntimeError(reason or "Generation failed with unknown reason")
        time.sleep(POLL_INTERVAL)
    raise TimeoutError(f"Generation timed out after {POLL_TIMEOUT}s (task: {task_id})")


def try_generate(payload: dict, api_key: str, max_retries: int = 3) -> dict:
    """Try to generate with retries on transient errors."""
    delay = 5.0
    last_error: Exception = RuntimeError("No attempts made")

    for attempt in range(1, max_retries + 1):
        try:
            model = payload["model"]
            print(f"[{model}] Attempt {attempt}/{max_retries}: submitting task...")
            task_id = submit_task(payload, api_key)
            print(f"[{model}] Task created: {task_id}")
            return poll_result(task_id, api_key)

        except TimeoutError as e:
            last_error = e
            print(f"Attempt {attempt} timed out: {e}")

        except RuntimeError as e:
            msg = str(e)
            last_error = e
            if is_permanent_error(msg):
                print(f"Permanent error — stopping: {msg}")
                raise
            print(f"Attempt {attempt} failed: {msg}")

        if attempt < max_retries:
            print(f"Retrying in {delay:.0f}s...")
            time.sleep(delay)
            delay = min(delay * 2, 60)

    raise last_error


def download_video(url: str, output_path: Path) -> None:
    """Download video from URL to file, with progress indication."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "grsai-veo-skill/1.0"})
        with urllib.request.urlopen(req, timeout=DOWNLOAD_TIMEOUT) as resp:
            total = int(resp.headers.get("Content-Length", 0))
            downloaded = 0
            chunks = []
            chunk_size = 1024 * 64  # 64 KB
            while True:
                chunk = resp.read(chunk_size)
                if not chunk:
                    break
                chunks.append(chunk)
                downloaded += len(chunk)
                if total:
                    pct = downloaded * 100 // total
                    print(f"  Downloading: {pct}% ({downloaded // 1024} KB)", end="\r")
            print()
            output_path.write_bytes(b"".join(chunks))
    except urllib.error.URLError as e:
        raise RuntimeError(f"Network error downloading video: {e.reason}")
    except TimeoutError:
        raise RuntimeError(f"Video download timed out after {DOWNLOAD_TIMEOUT}s")


def main():
    parser = argparse.ArgumentParser(
        description="Generate videos using grsai.com Veo 3.1 API"
    )
    parser.add_argument("--prompt", "-p", required=True, help="Video description/prompt")
    parser.add_argument("--filename", "-f", help="Output filename (e.g., output.mp4). Required unless --url-only is set.")
    parser.add_argument(
        "--model", "-m",
        choices=AVAILABLE_MODELS,
        default="veo3.1-fast",
        help="Model to use (default: veo3.1-fast)",
    )
    parser.add_argument(
        "--duration", "-d",
        type=int,
        choices=[4, 6, 8],
        default=8,
        help="Video duration in seconds: 4, 6, or 8 (default: 8)",
    )
    parser.add_argument(
        "--aspect-ratio", "-a",
        choices=["16:9", "9:16"],
        default="16:9",
        help="Aspect ratio: 16:9 (default, landscape) or 9:16 (portrait)",
    )
    parser.add_argument("--api-key", "-k", help="grsai API key (overrides GRSAI_API_KEY env var)")
    parser.add_argument(
        "--url-only",
        action="store_true",
        help="Print the video URL to stdout and exit without downloading. Useful for chaining with other tools.",
    )

    args = parser.parse_args()

    if not args.url_only and not args.filename:
        parser.error("--filename is required unless --url-only is set")

    api_key = get_api_key(args.api_key)
    if not api_key:
        print("Error: No API key provided.", file=sys.stderr)
        print("Set GRSAI_API_KEY environment variable or pass --api-key", file=sys.stderr)
        sys.exit(1)

    output_path = Path(args.filename) if args.filename else None
    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)

    payload = {
        "model": args.model,
        "prompt": args.prompt,
        "durationSeconds": args.duration,
        "aspectRatio": args.aspect_ratio,
        "webHook": "-1",
    }

    print(f"Generating video — model={args.model}, duration={args.duration}s, aspect={args.aspect_ratio}")
    print(f"Prompt: {args.prompt[:100]}{'...' if len(args.prompt) > 100 else ''}")

    try:
        result = try_generate(payload, api_key)
    except RuntimeError as e:
        print(f"\nGeneration failed: {e}", file=sys.stderr)
        sys.exit(1)
    except TimeoutError as e:
        print(f"\nGeneration timed out: {e}", file=sys.stderr)
        sys.exit(1)

    # Veo returns url at top-level; nano-banana uses results[0].url — handle both
    video_url = result.get("url")
    if not video_url:
        nested = result.get("results", [])
        if nested:
            video_url = nested[0].get("url")
    if not video_url:
        print(f"Error: No video URL in result: {result}", file=sys.stderr)
        sys.exit(1)

    credits = result.get("credits_cost", "unknown")
    print(f"Generation complete! Credits used: {credits}")
    print(f"VIDEO_URL: {video_url}")

    if args.url_only:
        return

    print(f"Downloading video from: {video_url[:80]}...")

    try:
        download_video(video_url, output_path)  # type: ignore[arg-type]
    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    size_kb = output_path.stat().st_size // 1024  # type: ignore[union-attr]
    print(f"\nVideo saved: {output_path.resolve()} ({size_kb} KB)")


if __name__ == "__main__":
    main()
