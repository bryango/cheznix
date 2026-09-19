"""Keep the v1 model catalog in sync with its two source catalogs."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def sync(codex_dir):
    models = []
    slugs = set()
    for source in (codex_dir / "models_cache.json",
                   codex_dir / "agents/deepseek-models.json"):
        data = json.loads(source.read_text())
        if not isinstance(data, dict) or not isinstance(data.get("models"), list):
            raise ValueError(f"{source}: expected a models array")
        for model in data["models"]:
            if not isinstance(model, dict):
                raise ValueError(f"{source}: expected a model object")
            slug = model.get("slug")
            if not isinstance(slug, str) or not slug or slug in slugs:
                raise ValueError(f"{source}: missing or duplicate model slug: {slug!r}")
            slugs.add(slug)
            models.append(dict(model, multi_agent_version="v1"))

    expected = {"models": models}
    target = codex_dir / "models-v1.json"
    try:
        actual = json.loads(target.read_text())
    except (FileNotFoundError, json.JSONDecodeError, UnicodeDecodeError):
        actual = None
    if actual == expected:
        return False

    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8",
                                         dir=codex_dir, prefix=".models-v1-",
                                         delete=False) as output:
            temporary = Path(output.name)
            json.dump(expected, output, indent=2, ensure_ascii=False)
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, target)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    return True


def notify(message):
    # Pass text as an argument, never interpolate it into AppleScript source.
    subprocess.run([
        "/usr/bin/osascript", "-e",
        'on run argv\n display notification (item 1 of argv) '
        'with title "Codex models sync"\nend run', message,
    ], check=True, capture_output=True, text=True, timeout=15)


def main():
    try:
        changed = sync(Path.home() / ".codex")
        if changed:
            print("Updated models-v1.json from the source catalogs.")
            notify("Updated models-v1.json to match the source catalogs.")
        else:
            print("Model catalog is unchanged.")
        return 0
    except Exception as error:
        message = f"Model catalog sync failed: {error}"
        print(message, file=sys.stderr)
        try:
            notify(message)
        except Exception as notification_error:
            print(f"Notification failed: {notification_error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
