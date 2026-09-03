#!/usr/bin/env python3
"""Generate a synthetic file tree for benchmarking the fuzzy-finder skill.

Plants a fixed set of "needle" files at known shallow/mid/deep locations
(for correctness checks) and fills the rest of the tree with randomly
combined, source-tree-plausible filenames until --files is reached.

Usage:
  gen_corpus.py --out DIR --files N [--depth D] [--seed S] [--flat]

Prints a JSON manifest to stdout: {"needles": {name: relpath, ...}, "root": DIR}
"""
import argparse
import json
import os
import random

DIR_WORDS = [
    "src", "lib", "internal", "components", "services", "controllers",
    "models", "utils", "handlers", "core", "api", "pkg", "modules",
    "views", "tests", "config", "adapters", "middleware", "hooks", "store",
]

NAME_WORDS = [
    "user", "auth", "session", "payment", "order", "invoice", "customer",
    "product", "cart", "search", "index", "cache", "queue", "worker",
    "email", "notification", "report", "metric", "logger", "router",
    "gateway", "connection", "pool", "client", "server", "socket", "token",
    "parser", "encoder", "decoder", "validator", "scheduler", "manager",
]

EXTENSIONS = [".ts", ".py", ".cpp", ".go", ".md", ".json", ".rs", ".java", ".rb"]

NEEDLES = {
    # name -> (depth_fraction of --depth, distinctive filename)
    "shallow": "user_auth_service.py",
    "mid": "payment_gateway_handler.go",
    "deep": "database_connection_pool.cpp",
    "shallow2": "search_index_builder.ts",
    "deep2": "notification_dispatch_worker.rs",
}


def rand_filename(rng):
    a, b = rng.choice(NAME_WORDS), rng.choice(NAME_WORDS)
    ext = rng.choice(EXTENSIONS)
    suffix = rng.randint(0, 9999)
    return f"{a}_{b}_{suffix}{ext}"


def build_dir_path(rng, out_root, depth):
    parts = [rng.choice(DIR_WORDS) for _ in range(depth)]
    path = os.path.join(out_root, *parts) if parts else out_root
    os.makedirs(path, exist_ok=True)
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--files", type=int, required=True)
    ap.add_argument("--depth", type=int, default=6)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--flat", action="store_true",
                     help="put all files in a single directory instead of a tree")
    args = ap.parse_args()

    rng = random.Random(args.seed)
    os.makedirs(args.out, exist_ok=True)

    manifest = {"root": os.path.abspath(args.out), "needles": {}}

    depth_map = {
        "shallow": 1, "shallow2": 1,
        "mid": max(1, args.depth // 2),
        "deep": args.depth, "deep2": args.depth,
    }

    for key, fname in NEEDLES.items():
        if args.flat:
            d = args.out
        else:
            d = build_dir_path(rng, args.out, depth_map[key])
        os.makedirs(d, exist_ok=True)
        fpath = os.path.join(d, fname)
        open(fpath, "w").close()
        manifest["needles"][key] = os.path.relpath(fpath, args.out)

    remaining = args.files - len(NEEDLES)
    for _ in range(max(0, remaining)):
        if args.flat:
            d = args.out
        else:
            depth = rng.randint(1, args.depth)
            d = build_dir_path(rng, args.out, depth)
        fname = rand_filename(rng)
        fpath = os.path.join(d, fname)
        # collisions are astronomically unlikely given the suffix range x depth,
        # but skip silently rather than error if one occurs
        if not os.path.exists(fpath):
            open(fpath, "w").close()

    print(json.dumps(manifest))


if __name__ == "__main__":
    main()
