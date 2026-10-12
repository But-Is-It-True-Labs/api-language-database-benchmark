from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
source = (root / "postgres/01-init.sql").read_text()
destination = root / "yugabyte/seed.sql"

pattern = re.compile(
    r"INSERT INTO benchmark_(?:parent|child|event)\s+"
    r"SELECT.*?FROM generate_series\(1,\s*(\d+)\) AS n;",
    re.S,
)

parts = []
position = 0
matches = list(pattern.finditer(source))

if len(matches) != 3:
    raise SystemExit("STOP: PostgreSQL seed format changed.")

for match in matches:
    parts.append(source[position:match.start()])
    original = match.group(0)
    total = int(match.group(1))

    for start in range(1, total + 1, 5000):
        end = min(start + 4999, total)
        sql = re.sub(
            r"generate_series\(1,\s*\d+\)",
            f"generate_series({start}, {end})",
            original,
        )
        parts.append(sql + "\n")

    position = match.end()

parts.append(source[position:])
destination.write_text(
    "-- Generated from database/postgres/01-init.sql\n"
    "-- INSERT batches contain at most 5000 records.\n\n"
    + "".join(parts)
)

print(f"Generated {destination}")
