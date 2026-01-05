#!/usr/bin/env python3
"""Count tests in all test suite files."""
import json
import os
from pathlib import Path

base_dir = Path("C:/Users/14104/llm-benchmarks/test-suites")
total = 0
by_domain = {}

for root, dirs, files in os.walk(base_dir):
    # Skip templates
    if "_templates" in root:
        continue

    for f in files:
        if not f.endswith(".json"):
            continue

        filepath = Path(root) / f
        try:
            with open(filepath, 'r', encoding='utf-8') as fp:
                data = json.load(fp)
                count = len(data.get('cases', []))
                domain = data.get('subdomain', 'unknown')

                if domain not in by_domain:
                    by_domain[domain] = 0
                by_domain[domain] += count
                total += count

                print(f"{f}: {count} tests")
        except Exception as e:
            print(f"ERROR reading {f}: {e}")

print(f"\n{'='*40}")
print("BY DOMAIN:")
for domain, count in sorted(by_domain.items(), key=lambda x: -x[1]):
    print(f"  {domain}: {count}")
print(f"\nTOTAL: {total} tests")
