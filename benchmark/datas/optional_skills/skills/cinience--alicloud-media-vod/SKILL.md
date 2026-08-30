---
name: alicloud-media-vod
description: Manage Alibaba Cloud ApsaraVideo VOD resources and media workflows via OpenAPI/SDK. Use for upload and media asset operations, transcoding templates, playback authorization, AI processing jobs, and VOD troubleshooting.
---

Category: service

# ApsaraVideo VOD

## Validation

```bash
mkdir -p output/alicloud-media-vod
python -m py_compile skills/media/vod/alicloud-media-vod/scripts/list_openapi_meta_apis.py
echo "py_compile_ok" > output/alicloud-media-vod/validate.txt
```

Pass criteria: command exits 0 and `output/alicloud-media-vod/validate.txt` is generated.

## Output And Evidence

- Save API inventory and operation evidence under `output/alicloud-media-vod/`.
- Keep region, media IDs, template IDs, and request parameters in evidence files.

Use Alibaba Cloud OpenAPI (RPC) with official SDKs or OpenAPI Explorer to manage VOD resources.
Prefer metadata-first API discovery before mutate operations.

## Prerequisites

- Prepare least-privilege RAM AccessKey/STS credentials.
- Confirm target region and media scope before changes.
- Use read-only `Describe*` / `List*` APIs first.

## Workflow

1) Confirm target media IDs, storage scope, and desired operation.
2) Discover API names and required parameters via metadata and API Explorer.
3) Execute read-only validation calls.
4) Execute upload/process/playback/configuration operations.
5) Save outputs and evidence under `output/alicloud-media-vod/`.

## AccessKey Priority

1) Environment variables: `ALICLOUD_ACCESS_KEY_ID` / `ALICLOUD_ACCESS_KEY_SECRET` / `ALICLOUD_REGION_ID`.
2) Shared config file: `~/.alibabacloud/credentials`.

If region is ambiguous, ask before write operations.

## API Discovery

- Product code: `vod`
- Default API version: `2017-03-21`
- Metadata source: `https://api.aliyun.com/meta/v1/products/vod/versions/2017-03-21/api-docs.json`

## Minimal Executable Quickstart

```bash
python skills/media/vod/alicloud-media-vod/scripts/list_openapi_meta_apis.py
```

Optional overrides:

```bash
python skills/media/vod/alicloud-media-vod/scripts/list_openapi_meta_apis.py \
  --product-code vod \
  --version 2017-03-21 \
  --output-dir output/alicloud-media-vod
```

## Common Operation Mapping

- Upload and assets: `CreateUploadVideo`, `CreateUploadImage`, `GetPlayInfo`, `SearchMedia`
- Media management: `GetVideoInfo`, `UpdateVideoInfo`, `DeleteVideo`
- Transcode/templates: `AddTranscodeTemplateGroup`, `UpdateTranscodeTemplateGroup`, `SubmitTranscodeJobs`
- Snapshot/AI jobs: `SubmitSnapshotJob`, `SubmitAIJob`, `GetJobDetail`
- Security/play auth: `GetVideoPlayAuth`, `SetMessageCallback`, `SetDefaultWatermark`

## Output Policy

Write all generated files and execution evidence under:
`output/alicloud-media-vod/`

## References

- Source list: `references/sources.md`
- Task templates: `references/templates.md`
