#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any


AUTH_PATH = Path.home() / ".codex" / "auth.json"
ENDPOINT = "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits"
WARNING_WINDOW = timedelta(hours=48)


class CheckError(RuntimeError):
    """A safe-to-display checker failure."""


class AlertTimeoutError(RuntimeError):
    """The macOS alert was not acknowledged before its timeout."""


class NoRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(
        self,
        request: urllib.request.Request,
        file_pointer: Any,
        code: int,
        message: str,
        headers: Any,
        new_url: str,
    ) -> None:
        return None


def show_alert(title: str, message: str, alert_type: str) -> None:
    script = """
on run argv
    set alertTitle to item 1 of argv
    set alertMessage to item 2 of argv
    set alertType to item 3 of argv

    if alertType is "critical" then
        display alert alertTitle message alertMessage as critical buttons {"OK"} default button "OK" giving up after 60
    else
        display alert alertTitle message alertMessage as warning buttons {"OK"} default button "OK" giving up after 60
    end if
end run
"""
    result = subprocess.run(
        ["/usr/bin/osascript", "-e", script, title, message, alert_type],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    if "gaveup:true" in result.stdout.replace(" ", "").lower():
        raise AlertTimeoutError(
            "The macOS alert timed out before it was acknowledged."
        )


def load_credentials() -> tuple[str, str | None]:
    try:
        auth = json.loads(AUTH_PATH.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise CheckError("The Codex authentication file does not exist.") from error
    except PermissionError as error:
        raise CheckError("The Codex authentication file cannot be read.") from error
    except json.JSONDecodeError as error:
        raise CheckError("The Codex authentication file is not valid JSON.") from error

    tokens = auth.get("tokens")
    if not isinstance(tokens, dict):
        raise CheckError("The Codex authentication file has no tokens object.")

    access_token = tokens.get("access_token")
    if not isinstance(access_token, str) or not access_token:
        raise CheckError("The Codex authentication file has no access token.")

    account_id = tokens.get("account_id")
    if not isinstance(account_id, str) or not account_id:
        account_id = None

    return access_token, account_id


def fetch_credits(access_token: str, account_id: str | None) -> dict[str, Any]:
    headers = {
        "Accept": "application/json",
        "Authorization": f"Bearer {access_token}",
        "OAI-Product-Sku": "CODEX",
        "OpenAI-Beta": "codex-1",
        "originator": "Codex Desktop",
    }
    if account_id is not None:
        headers["ChatGPT-Account-ID"] = account_id

    request = urllib.request.Request(
        ENDPOINT,
        headers=headers,
        method="GET",
    )
    opener = urllib.request.build_opener(NoRedirectHandler())

    try:
        with opener.open(request, timeout=30) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as error:
        raise CheckError(f"The reset-credit service returned HTTP {error.code}.") from error
    except urllib.error.URLError as error:
        raise CheckError("The reset-credit service could not be reached.") from error
    except TimeoutError as error:
        raise CheckError("The reset-credit request timed out.") from error
    except json.JSONDecodeError as error:
        raise CheckError("The reset-credit service returned invalid JSON.") from error

    if not isinstance(payload, dict):
        raise CheckError("The reset-credit service returned an unexpected response.")
    return payload


def parse_expiry(value: Any) -> datetime:
    if not isinstance(value, str) or not value:
        raise CheckError("An available reset credit has no expiry time.")

    try:
        expiry = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise CheckError("An available reset credit has an invalid expiry time.") from error

    if expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=timezone.utc)
    return expiry.astimezone(timezone.utc)


def available_expiries(payload: dict[str, Any]) -> list[datetime]:
    credits = payload.get("credits")
    if not isinstance(credits, list):
        raise CheckError("The reset-credit response has no credit list.")

    expiries = []
    for credit in credits:
        if not isinstance(credit, dict):
            raise CheckError("The reset-credit response contains an invalid credit.")

        status = credit.get("status")
        if isinstance(status, str) and status.lower() == "available":
            expiry_value = credit.get("expires_at", credit.get("expiresAt"))
            expiries.append(parse_expiry(expiry_value))

    expiries.sort()
    return expiries


def format_distance(expiry: datetime, now: datetime) -> str:
    total_minutes = int((expiry - now).total_seconds() // 60)
    if total_minutes < 0:
        elapsed_minutes = abs(total_minutes)
        days, remainder = divmod(elapsed_minutes, 24 * 60)
        hours, minutes = divmod(remainder, 60)
        return f"expired {days}d {hours}h {minutes}m ago"

    days, remainder = divmod(total_minutes, 24 * 60)
    hours, minutes = divmod(remainder, 60)
    return f"in {days}d {hours}h {minutes}m"


def parse_optional_timestamp(value: Any) -> datetime | None:
    if not isinstance(value, str) or not value:
        return None
    try:
        timestamp = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if timestamp.tzinfo is None:
        timestamp = timestamp.replace(tzinfo=timezone.utc)
    return timestamp.astimezone(timezone.utc)


def format_local_timestamp(timestamp: datetime | None) -> str:
    if timestamp is None:
        return "—"

    local_timestamp = timestamp.astimezone()
    offset = local_timestamp.strftime("%z")
    formatted_offset = f"{offset[:3]}:{offset[3:]}" if offset else "unknown"
    return (
        f"{local_timestamp:%Y-%m-%d %H:%M} "
        f"{local_timestamp:%Z} (UTC{formatted_offset})"
    )


def markdown_cell(value: Any) -> str:
    if value is None or value == "":
        return "—"
    return " ".join(str(value).split()).replace("|", "\\|")


def format_metadata(payload: dict[str, Any], now: datetime) -> str:
    credits = payload.get("credits")
    if not isinstance(credits, list):
        raise CheckError("The reset-credit response has no credit list.")

    rows = []
    for credit in credits:
        if not isinstance(credit, dict):
            raise CheckError("The reset-credit response contains an invalid credit.")
        status = credit.get("status")
        if not isinstance(status, str) or status.lower() != "available":
            continue

        expiry = parse_expiry(credit.get("expires_at", credit.get("expiresAt")))
        granted = parse_optional_timestamp(
            credit.get("granted_at", credit.get("grantedAt"))
        )
        plan_support = credit.get("is_supported_by_plan")
        if plan_support is True:
            plan_support_label = "Yes"
        elif plan_support is False:
            plan_support_label = "No"
        else:
            plan_support_label = "Unknown"

        rows.append(
            (
                expiry,
                markdown_cell(credit.get("title")),
                markdown_cell(credit.get("reset_type")),
                format_local_timestamp(granted),
                format_local_timestamp(expiry),
                format_distance(expiry, now),
                plan_support_label,
            )
        )

    rows.sort(key=lambda row: row[0])
    checked_at = format_local_timestamp(now)
    available_count = payload.get("available_count", len(rows))
    total_earned_count = payload.get("total_earned_count", "—")

    lines = [
        "## Codex reset credits",
        "",
        f"- **Checked:** {checked_at}",
        f"- **Available:** {markdown_cell(available_count)}",
        f"- **Total earned:** {markdown_cell(total_earned_count)}",
    ]

    if not rows:
        lines.extend(["", "No available reset credits."])
        return "\n".join(lines)

    headers = ("#", "Reset", "Type", "Granted", "Expires", "Remaining", "Plan supported")
    table_rows = [
        (str(index), *row[1:]) for index, row in enumerate(rows, start=1)
    ]
    widths = [
        max(3, *(len(value) for value in column))
        for column in zip(headers, *table_rows)
    ]
    widths[0] = max(widths[0], 4)
    widths[-1] = max(widths[-1], 5)

    row_template = "| " + " | ".join(f"{{:<{width}}}" for width in widths) + " |"
    separators = ["-" * width for width in widths]
    separators[0] = "-" * (widths[0] - 1) + ":"
    separators[-1] = ":" + "-" * (widths[-1] - 2) + ":"
    lines.extend(
        (
            "",
            row_template.format(*headers),
            row_template.format(*separators),
            *(row_template.format(*row) for row in table_rows),
        )
    )

    return "\n".join(lines)


def check(alerts_enabled: bool = True) -> None:
    access_token, account_id = load_credentials()
    payload = fetch_credits(access_token, account_id)
    expiries = available_expiries(payload)

    now = datetime.now(timezone.utc)
    expiring = [expiry for expiry in expiries if expiry - now < WARNING_WINDOW]
    print(format_metadata(payload, now))

    if not expiring:
        print("\n**Expiry check:** No available reset expires within 48 hours.")
        return

    local_timezone = datetime.now().astimezone().tzinfo
    lines = [
        f"{len(expiring)} of {len(expiries)} available reset credit(s) "
        "expire within 48 hours:"
    ]
    for index, expiry in enumerate(expiring, start=1):
        local_expiry = expiry.astimezone(local_timezone)
        lines.append(
            f"{index}. {local_expiry:%Y-%m-%d %H:%M:%S %Z} "
            f"({format_distance(expiry, now)})"
        )

    if alerts_enabled:
        show_alert(
            "Codex reset credits expiring",
            "\n".join(lines),
            "warning",
        )
        print(
            f"\n**Expiry check:** Displayed an alert for "
            f"{len(expiring)} reset credit(s)."
        )
    else:
        print(
            f"\n**Expiry check:** {len(expiring)} reset credit(s) expire within "
            "48 hours; the alert was suppressed for this run."
        )


def main(alerts_enabled: bool = True) -> int:
    try:
        check(alerts_enabled=alerts_enabled)
    except AlertTimeoutError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    except CheckError as error:
        message = str(error)
        if alerts_enabled:
            try:
                show_alert("Codex reset credit check failed", message, "critical")
            except Exception:
                print(
                    "ERROR: The reset-credit check failed and its alert could not "
                    "be displayed.",
                    file=sys.stderr,
                )
            else:
                print(f"ERROR: {message}", file=sys.stderr)
        else:
            print(f"ERROR: {message}", file=sys.stderr)
        return 1
    except Exception as error:
        message = f"The reset-credit check failed unexpectedly ({type(error).__name__})."
        if alerts_enabled:
            try:
                show_alert("Codex reset credit check failed", message, "critical")
            except Exception:
                print(
                    "ERROR: The reset-credit check failed unexpectedly and its "
                    "alert could not be displayed.",
                    file=sys.stderr,
                )
            else:
                print(f"ERROR: {message}", file=sys.stderr)
        else:
            print(f"ERROR: {message}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    argument_parser = argparse.ArgumentParser()
    argument_parser.add_argument(
        "--no-alert",
        action="store_true",
        help="Do not display macOS alerts during this run.",
    )
    arguments = argument_parser.parse_args()
    raise SystemExit(main(alerts_enabled=not arguments.no_alert))
