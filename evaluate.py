#!/usr/bin/env python3

import os
import re
import subprocess
import sys
import tempfile
from argparse import ArgumentDefaultsHelpFormatter, ArgumentParser
from typing import List


def user_cache_dir(name: str):
    """
    Get the cache directory path.

    MacOS:    ~/Library/Caches/<name>
    Unix:     ~/.cache/<name>    (from XDG_CACHE_HOME)
    """
    if sys.platform == "darwin":
        path = os.path.expanduser("~/Library/Caches")
    elif sys.platform == "linux":
        path = os.getenv("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))
    else:
        raise NotImplementedError
    path = os.path.join(path, name)
    return path


def parse_args():
    parser = ArgumentParser(formatter_class=ArgumentDefaultsHelpFormatter)
    # fmt: off
    parser.add_argument("--lang", "-l", metavar="LANG_CODE", required=True,
                        help="Language code (ISO 639-1)")
    parser.add_argument("--dataset-name", "-d", metavar="NAME", choices=["aspec_ja_en"], required=True,
                        help="Dataset name")
    parser.add_argument("--test-path", "-t", metavar="FILE", default=os.getenv("WAT_EVAL_TEST"),
                        help="Test file")
    parser.add_argument("--input", "-i", metavar="INPUT", required=True,
                        help="Input file")
    parser.add_argument("--metric", "-m", metavar="METRIC", choices=["bleu", "ribes"], default="bleu",
                        help="Metric")
    parser.add_argument("--cache-dir", metavar="DIR", default=user_cache_dir("wat_evalator"),
                        help="Cache directory")
    # fmt: on
    return parser.parse_args()


EXTRACT_RE = re.compile(r" \|\|\| ")
EXTRACT_PART = {
    "aspec_ja_en": {
        "ja": 2,
        "en": 3,
    },
    "aspec_ja_zh": {
        "ja": 1,
        "zh": 2,
    },
}


def extract_reference(lines: List[str], lang: str, dataset: str):
    part = EXTRACT_PART[dataset][lang]
    return [EXTRACT_RE.split(line.strip())[part] + "\n" for line in lines]


def main(args):
    if args.test_path is None or os.path.exists(args.test_path):
        raise FileNotFoundError(
            f"{args.test_path}: Please specify the test file path "
            "via `--test-path` option or `WAT_EVAL_TEST` environment variable."
        )

    test_split = os.path.splitext(os.path.basename(args.test_path))[0]
    cache_dir = os.path.abspath(args.cache_dir)
    work_dir = os.path.join(cache_dir, args.dataset_name)

    orig_dir = os.path.join(work_dir, "orig")
    os.makedirs(orig_dir, exist_ok=True)
    ref_path = os.path.join(orig_dir, f"{test_split}.{args.lang}")

    with open(args.test_path, mode="r") as f:
        with open(ref_path, mode="w") as o:
            o.writelines(
                extract_reference(
                    f.readlines(),
                    args.lang,
                    args.dataset_name,
                )
            )

    procedure_path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "procedures",
        f"{args.lang}.mk",
    )
    with open(args.input) as f:
        with tempfile.TemporaryDirectory() as tempdir:
            input_lines = f.readlines()
            sysout_path = os.path.join(tempdir, "sysout")
            with open(sysout_path, mode="w") as f:
                f.writelines(input_lines)
            cmd = [
                "make",
                "-s",
                "-f",
                procedure_path,
                "-C",
                cache_dir,
                f"REF={ref_path}",
                f"SYSOUT={sysout_path}",
                f"METRIC={args.metric}",
                "evaluate",
            ]
            subprocess.run(cmd)


def cli_main():
    args = parse_args()
    main(args)


if __name__ == "__main__":
    cli_main()
