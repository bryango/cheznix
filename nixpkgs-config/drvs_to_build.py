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

STORE_DIR = "/nix/store"


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
        record.levelname = f"{style}{levelname}{self.RESET}"
        return super().format(record)


handler = logging.StreamHandler(sys.stderr)
handler.setFormatter(ColorFormatter("%(levelname)s: %(message)s"))
logging.root.handlers = [handler]
logging.root.setLevel(logging.INFO)


def get_build_plan() -> list[str]:
    """
    Run `nix build --dry-run` and stream its output.

    Returns:
        List[str]: List of non-empty lines from the build plan.

    Raises:
        subprocess.CalledProcessError: If nix build command fails.
        SystemExit: If there's an error running the command.
    """
    try:
        build_cmd = ["nix", "build", "--dry-run"] + sys.argv[1:]
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

                stripped_line = line.strip()
                if re.match(r"these (.*) derivations will be built.*", line):
                    logging.debug("found build plan header: %s", stripped_line)
                    continue

                if re.match(r"these .* paths will be fetched.*", line):
                    logging.debug("found fetch plan header: %s", stripped_line)
                    logging.info(
                        "ignoring paths to be fetched, gathering derivations to be built"
                    )
                    break

                if (
                    stripped_line
                    and stripped_line.startswith("/")
                    and stripped_line.endswith(".drv")
                ):
                    build_list.append(stripped_line)
                else:
                    logging.warning("unexpected line: %s", stripped_line)

        return_code = process.wait()
        if return_code != 0:
            raise subprocess.CalledProcessError(return_code, build_cmd)

        return build_list

    except subprocess.CalledProcessError as err:
        logging.error("Error running nix build: %s", err)
        logging.error("Error output: %s", err.stderr)
        sys.exit(1)


def nix_eval(*expr: str) -> str | subprocess.CalledProcessError:
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
    except subprocess.CalledProcessError as error:
        return error


def parse_drv_name(drv_path: str) -> dict:
    """
    Extract the derivation name from its path.

    Args:
        drv_path (str): Full path to the .drv file.

    Returns:
        str: The derivation name without the .drv extension.
    """
    if storeDir := nix_eval("builtins.storeDir"):
        if isinstance(storeDir, str):
            global STORE_DIR
            logging.debug("setting store directory: %s", storeDir)
            STORE_DIR = storeDir
        else:
            logging.debug("error evaluating builtins.storeDir: %s", storeDir)

    basename = drv_path.removeprefix(STORE_DIR + "/").removesuffix(".drv")
    print(basename)
    if match := re.match(r"^[a-z0-9]+-(.+)$", basename):
        filename = match.group(1)
    else:
        logging.error("unexpected drv path format: %s", drv_path)
        sys.exit(1)

    if json_str := nix_eval(
        f'"{filename}"', "--apply", "builtins.parseDrvName", "--json"
    ):
        if isinstance(json_str, str):
            try:
                parsed = json.loads(json_str)
                if "name" in parsed:
                    return parsed
                else:
                    logging.error("parsed drv name missing 'name' field: %s", json_str)
                    sys.exit(1)
            except json.JSONDecodeError as e:
                logging.error("error decoding JSON from parseDrvName: %s", e)
                sys.exit(1)
        else:
            logging.error("error evaluating parseDrvName: %s", json_str)
            sys.exit(1)

    return {}


if __name__ == "__main__":
    build_plan = [parse_drv_name(drv) | {"path": drv} for drv in get_build_plan()]
    json.dump({"building": build_plan}, sys.stdout, indent=2)
    print()  # ensure newline after JSON output
