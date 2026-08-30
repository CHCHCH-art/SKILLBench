#!/usr/bin/env python3
"""
Together AI Video Generation — Async Workflow (v2 SDK)

Submit a video job, poll for completion, and download the result.
Supports text-to-video and image-to-video (keyframes).

Usage:
    python generate_video.py

Requires:
    pip install together requests
    export TOGETHER_API_KEY=your_key
"""

import time
from together import Together

client = Together()


def generate_text_to_video():
    """Generate a video from a text prompt."""
    job = client.videos.create(
        prompt="A serene sunset over the ocean with gentle waves lapping at the shore",
        model="google/veo-3.0",
        width=1920,
        height=1080,
    )
    print(f"Submitted job: {job.id}")
    return wait_for_video(job.id)


def generate_image_to_video(image_base64: str):
    """Generate a video from a starting image (keyframe)."""
    job = client.videos.create(
        prompt="Smooth camera zoom out revealing a vast landscape",
        model="minimax/hailuo-02",
        width=1366,
        height=768,
        fps=25,
        frame_images=[{"input_image": image_base64, "frame": 0}],
    )
    print(f"Submitted job: {job.id}")
    return wait_for_video(job.id)


def wait_for_video(job_id: str, poll_interval: int = 5, timeout: int = 600) -> str:
    """Poll a video job until completion. Returns the video URL."""
    elapsed = 0
    while elapsed < timeout:
        status = client.videos.retrieve(job_id)
        print(f"  Status: {status.status}")

        if status.status == "completed":
            video_url = status.outputs.video_url
            cost = status.outputs.cost
            print(f"\nVideo ready! Cost: ${cost}")
            print(f"URL: {video_url}")
            return video_url
        elif status.status == "failed":
            errors = getattr(status.info, "errors", None)
            raise RuntimeError(f"Video generation failed: {errors}")

        time.sleep(poll_interval)
        elapsed += poll_interval

    raise TimeoutError(f"Video job {job_id} did not complete within {timeout}s")


if __name__ == "__main__":
    video_url = generate_text_to_video()

    # Download the video
    import requests

    response = requests.get(video_url)
    with open("output.mp4", "wb") as f:
        f.write(response.content)
    print("Saved to output.mp4")
