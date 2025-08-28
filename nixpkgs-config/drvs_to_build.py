#!/usr/bin/env python3
"""
Parse and stream the output of `nix build --dry-run` command.
Captures the build plan from stderr, streams it in real-time,
and prints a JSON of derivations to be built.
"""

import logging
import re
import subprocess
import sys
import json
from typing import Optional

STORE_DIR: str = "/nix/store"


class ColorFormatter(logging.Formatter):
    """Custom log formatter with lowercase colored level names"""

    # ANSI escape codes
    COLORS = {
        "DEBUG": "\033[1;36m",  # bold cyan
        "INFO": "\033[1;32m",  # bold green
        "WARNING": "\033[1;33m",  # bold yellow
        "ERROR": "\033[1;31m",  # bold red
        "CRITICAL": "\033[1;35m",  # bold magenta
    }
    RESET = "\033[0m"

    def format(self, record):
        levelname = record.levelname.lower()
        style = self.COLORS.get(record.levelname, "")
        record.levelname = f"{style}{levelname}:{self.RESET}"
        return super().format(record)


def initialize_logging():
    handler = logging.StreamHandler(sys.stderr)
    handler.setFormatter(ColorFormatter("%(levelname)s %(message)s"))
    logging.root.handlers = [handler]
    logging.root.setLevel(logging.INFO)


initialize_logging()


def get_build_plan(*args: str) -> list[str]:
    """
    Run `nix build --dry-run` and stream its output.

    Returns:
        list[str]: List of derivations that form the build plan.
    """
    build_cmd = ["nix", "build", "--dry-run"] + list(args)
    process = subprocess.Popen(
        build_cmd,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,  # Line buffered
    )

    build_list = []

    if process.stderr is not None:
        for line in process.stderr:
            # stream to stderr in real-time
            print(line, end="", file=sys.stderr, flush=True)

            if re.match(r"these (.*) derivations will be built.*", line):
                logging.debug("^ found build plan header: %s")
                continue

            if re.match(r"these .* paths will be fetched.*", line):
                logging.debug("^ found fetch plan header")
                logging.info(
                    "ignoring paths to be fetched, gathering derivations to be built"
                )
                break

            if (
                (stripped_line := line.strip())
                and stripped_line.startswith("/")
                and stripped_line.endswith(".drv")
            ):
                build_list.append(stripped_line)
            else:
                logging.warning("^ unexpected log output")

    return_code = process.wait()
    if return_code != 0:
        logging.error(
            f"command {build_cmd} failed with code {return_code} and output: {process.stdout}"
        )

    return build_list


def call_nix_eval(*expr: str) -> Optional[str]:
    """
    Evaluate a Nix expression and return its output.

    Args:
        expr (str): The Nix expression to evaluate.

    Returns:
        str: The output of the evaluated expression.

    Raises:
        subprocess.CalledProcessError: If nix eval command fails.
        SystemExit: If there's an error running the command.
    """
    try:
        cmd = (
            ["nix", "eval", "--expr"]
            + list(expr)
            + (["--raw"] if len(expr) == 1 else [])
        )
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except Exception as error:
        logging.error(f"command {cmd} failed with: {error}")
        return None


def parse_drv_name(drv_path: str) -> dict[str, str]:
    """
    Extract the derivation name from its path.

    Args:
        drv_path (str): Full path to the .drv file.

    Returns:
        str: The derivation name without the .drv extension.
    """
    if storeDir := call_nix_eval("builtins.storeDir"):
        global STORE_DIR
        logging.debug("setting store directory: %s", storeDir)
        STORE_DIR = storeDir

    basename = drv_path.removeprefix(STORE_DIR + "/").removesuffix(".drv")
    if match := re.match(r"^[a-z0-9]+-(.+)$", basename):
        filename = match.group(1)
    else:
        logging.error("unexpected drv path format: %s", drv_path)
        filename = ""

    if json_str := call_nix_eval(
        f'"{filename}"', "--apply", "builtins.parseDrvName", "--json"
    ):
        try:
            parsed = json.loads(json_str)
            if "name" not in parsed:
                logging.error("parsed drv name missing 'name' field: %s", json_str)
        except Exception as error:
            logging.error("failed decoding JSON from parseDrvName: %s", error)
            parsed = {}

    parsed.update(path=drv_path)
    return parsed


def get_versioned_drv(drv_list: list[dict[str, str]]) -> list[dict[str, str]]:
    return [drv for drv in drv_list if drv.get("version")]


if __name__ == "__main__":
    build_plan = [parse_drv_name(drv) for drv in get_build_plan(*sys.argv[1:])]
    versioned = get_versioned_drv(build_plan)

    json.dump({"building": build_plan, "versioned": versioned}, sys.stdout, indent=2)
    print()  # ensure newline after JSON output
