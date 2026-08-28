#!/usr/bin/env bun
import { file, argv, env } from "bun";
import { resolve } from "path";

interface Options {
  prompt: string;
  model: string;
  size: string;
  num: number;
  format: string;
  out: string | null;
  edit: string[];
  resolution: string;
}

interface FalImage {
  url: string;
  width?: number;
  height?: number;
}

interface FalResponse {
  images: FalImage[];
}

async function loadEnv(): Promise<void> {
  const paths = [
    resolve(process.cwd(), ".env"),
    resolve(import.meta.dir, "../../../.env"),
  ];
  for (const p of paths) {
    const f = file(p);
    if (await f.exists()) {
      const content = await f.text();
      for (const line of content.split("\n")) {
        const match = line.match(/^\s*([\w]+)\s*=\s*(.*)$/);
        if (match && !env[match[1]]) {
          env[match[1]] = match[2].replace(/^["']|["']$/g, "");
        }
      }
    }
  }
}

await loadEnv();

const FAL_KEY = env.FAL_API_KEY || env.FAL_KEY;
if (!FAL_KEY) {
  console.error("Error: FAL_API_KEY not found in .env or environment");
  process.exit(1);
}

function parseArgs(args: string[]): Options {
  const opts: Options = {
    prompt: "",
    model: "fal-ai/nano-banana",
    size: "square",
    num: 1,
    format: "png",
    out: null,
    edit: [],
    resolution: "1K",
  };

  let i = 0;
  while (i < args.length) {
    const arg = args[i];
    if (arg === "--model") opts.model = args[++i];
    else if (arg === "--size") opts.size = args[++i];
    else if (arg === "--num") opts.num = parseInt(args[++i], 10);
    else if (arg === "--format") opts.format = args[++i];
    else if (arg === "--out") opts.out = args[++i];
    else if (arg === "--edit") opts.edit.push(args[++i]);
    else if (arg === "--resolution") opts.resolution = args[++i];
    else if (!arg.startsWith("-")) opts.prompt = arg;
    i++;
  }
  return opts;
}

async function generate(opts: Options): Promise<FalResponse> {
  const isEdit = opts.edit.length > 0;
  const endpoint = isEdit
    ? `https://fal.run/${opts.model}/edit`
    : `https://fal.run/${opts.model}`;

  const body: Record<string, unknown> = {
    prompt: opts.prompt,
    num_images: opts.num,
    output_format: opts.format,
  };

  if (isEdit) {
    body.image_urls = opts.edit;
    body.resolution = opts.resolution;
  } else {
    body.image_size = opts.size;
  }

  const res = await fetch(endpoint, {
    method: "POST",
    headers: {
      Authorization: `Key ${FAL_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`fal.ai error ${res.status}: ${err}`);
  }

  return res.json();
}

async function downloadImage(url: string, path: string): Promise<void> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Failed to download: ${res.status}`);
  await Bun.write(path, res);
  console.log(`Saved: ${path}`);
}

const args = argv.slice(2);
if (args.length === 0 || args.includes("--help")) {
  console.log(`Usage: bun fal-generate.ts <prompt> [options]

Options:
  --model <id>        Model (default: fal-ai/nano-banana)
  --size <size>       Size: square, landscape_4_3, portrait_4_3, etc.
  --num <n>           Number of images 1-4
  --format <fmt>      png, jpeg, webp
  --out <path>        Save first image to file
  --edit <url>        Image URL for editing (can be repeated for multiple images)
  --resolution <res>  Edit output resolution: 1K, 2K, 4K (default: 1K)`);
  process.exit(0);
}

const opts = parseArgs(args);
if (!opts.prompt) {
  console.error("Error: prompt required");
  process.exit(1);
}

console.log(`Generating with ${opts.model}...`);
const result = await generate(opts);

for (const img of result.images) {
  console.log(`Image: ${img.url}`);
  if (img.width && img.height) {
    console.log(`  Size: ${img.width}x${img.height}`);
  }
}

if (opts.out && result.images[0]) {
  await downloadImage(result.images[0].url, opts.out);
}
