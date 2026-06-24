#!/usr/bin/env python3
"""Register with acme-d.sunet.se and output hiera-eyaml compatible YAML.

Optionally adds the required CNAME record via knotctl if the user owns
the zone that fulldomain falls under.
"""

import json
import subprocess
import sys
import urllib.error
import urllib.request

REGISTER_URL = "https://acme-d.sunet.se/register"


def get_knotctl_zones() -> list[str] | None:
    """Return the list of zones the current knotctl user owns, or None on error."""
    try:
        result = subprocess.run(
            ["knotctl", "--json", "user"],
            capture_output=True, text=True, check=True,
        )
        data = json.loads(result.stdout)
        # Normalise to trailing-dot form
        return [z if z.endswith(".") else z + "." for z in data.get("zones", [])]
    except FileNotFoundError:
        return None  # knotctl not installed
    except (subprocess.CalledProcessError, json.JSONDecodeError, KeyError) as e:
        print(f"Warning: could not query knotctl zones: {e}", file=sys.stderr)
        return None


def find_matching_zone(fulldomain: str, zones: list[str]) -> str | None:
    """Return the longest zone that is a suffix of fulldomain, or None."""
    # Ensure fulldomain has a trailing dot for clean suffix matching
    if not fulldomain.endswith("."):
        fulldomain += "."
    # Pick the most specific (longest) matching zone
    matches = [z for z in zones if fulldomain.endswith("." + z) or fulldomain == z]
    return max(matches, key=len) if matches else None


def add_knotctl_cname(zone: str, fulldomain: str, domain: str, ttl: int = 300) -> None:
    """Add the _acme-challenge CNAME record via knotctl."""
    # Strip the zone suffix from fulldomain to get just the subdomain label,
    # then build the _acme-challenge record name from the user-supplied domain.
    # e.g. domain=geteduroam-test-radius-1-dco.geteduroam.sunet.se
    #   -> record name: _acme-challenge.geteduroam-test-radius-1-dco.geteduroam.sunet.se
    #
    # knotctl wants the record name relative to the zone (without trailing dot):
    #   -n _acme-challenge.<left-of-zone>

    # Build the full _acme-challenge owner name
    record_name = f"_acme-challenge.{domain}"

    # Ensure fulldomain has a trailing dot (CNAME target must be absolute)
    cname_target = fulldomain if fulldomain.endswith(".") else fulldomain + "."

    # Strip trailing dot from zone for the -z argument
    zone_arg = zone.rstrip(".")

    cmd = [
        "knotctl", "add",
        "-z", zone_arg,
        "-d", cname_target,
        "-n", record_name,
        "-r", "CNAME",
        "-t", str(ttl),
    ]

    print(f"\nRunning: {' '.join(cmd)}", file=sys.stderr)
    try:
        subprocess.run(cmd, check=True)
        print("✓ CNAME record added successfully.", file=sys.stderr)
    except FileNotFoundError:
        print("Error: knotctl not found in PATH.", file=sys.stderr)
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"Error: knotctl exited with code {e.returncode}.", file=sys.stderr)
        sys.exit(1)


def register(domain: str, skip_knotctl: bool = False, ttl: int = 300) -> None:
    print("Registering with acme-d.sunet.se...", file=sys.stderr)

    try:
        req = urllib.request.Request(REGISTER_URL, data=b"", method="POST")
        with urllib.request.urlopen(req) as resp:
            raw = resp.read()
    except urllib.error.URLError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    data = json.loads(raw)

    print("--- raw register response ---", file=sys.stderr)
    print(json.dumps(data, indent=2), file=sys.stderr)
    print("--- hiera-eyaml ---", file=sys.stderr)

    password_wrapped = f"DEC::PKCS7[{data['password']}]!"

    lines = [
        "certbot_acmed_clients:",
        f"  {domain}:",
        f"    allowfrom: {json.dumps(data['allowfrom'])}",
        f"    fulldomain: {data['fulldomain']}",
        f"    password: {password_wrapped}",
        f"    subdomain: {data['subdomain']}",
        f"    username: {data['username']}",
    ]
    print("\n".join(lines))

    if skip_knotctl:
        return

    # --- knotctl integration ---
    zones = get_knotctl_zones()
    if zones is None:
        print("\nknotctl not available, skipping DNS record creation.", file=sys.stderr)
        return

    zone = find_matching_zone(domain, zones)
    if zone is None:
        print(
            f"\nNote: domain '{domain}' does not match any of your "
            f"knotctl zones — skipping DNS record creation.",
            file=sys.stderr,
        )
        return

    print(f"\nMatched zone: {zone}", file=sys.stderr)
    add_knotctl_cname(zone, data["fulldomain"], domain, ttl=ttl)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Register with acme-d.sunet.se and optionally add the CNAME via knotctl."
    )
    parser.add_argument("domain", help="The domain to register (e.g. myhost.example.com)")
    parser.add_argument(
        "--no-knotctl", action="store_true",
        help="Skip knotctl DNS record creation even if the zone is available.",
    )
    parser.add_argument(
        "--ttl", type=int, default=300,
        help="TTL for the CNAME record (default: 300).",
    )
    args = parser.parse_args()

    register(args.domain, skip_knotctl=args.no_knotctl, ttl=args.ttl)
