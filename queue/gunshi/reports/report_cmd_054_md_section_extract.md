Sounds like a fun little text‑parsing utility—here’s a robust, simple Python script that does exactly what you want with clear behavior for the tricky cases.

**1) Script: `extract_section.py`**
```python
#!/usr/bin/env python3
import sys
from typing import List, Tuple

def usage() -> None:
    print("Usage: extract_section.py <markdown_file> <heading_text> [--all]")
    print("Example: extract_section.py README.md '## Section Title'")
    sys.exit(2)

def is_heading(line: str) -> Tuple[bool, int]:
    s = line.rstrip("\n")
    if not s.startswith("#"):
        return (False, 0)
    # Count leading '#'
    i = 0
    while i < len(s) and s[i] == "#":
        i += 1
    # Require a space after hashes to be a heading
    if i < len(s) and s[i] == " ":
        return (True, i)
    return (False, 0)

def extract_sections(lines: List[str], heading_text: str, all_matches: bool) -> List[List[str]]:
    results = []
    target = heading_text.rstrip()
    target_is_heading, target_level = is_heading(target + "\n")
    if not target_is_heading:
        return results

    in_section = False
    current = []

    for line in lines:
        line_stripped = line.rstrip()
        is_h, level = is_heading(line)
        if not in_section:
            if line_stripped == target:
                in_section = True
                current = [line]
            continue
        else:
            # Check for boundary: same or higher level heading
            if is_h and level <= target_level:
                results.append(current)
                if all_matches:
                    in_section = False
                    current = []
                    # Check if this line starts a new target section
                    if line_stripped == target:
                        in_section = True
                        current = [line]
                else:
                    return results
            else:
                current.append(line)

    if in_section:
        results.append(current)
    return results

def main() -> None:
    if len(sys.argv) < 3:
        usage()

    md_path = sys.argv[1]
    heading_text = sys.argv[2]
    all_matches = len(sys.argv) > 3 and sys.argv[3] == "--all"

    try:
        with open(md_path, "r", encoding="utf-8") as f:
            lines = f.readlines()
    except FileNotFoundError:
        print(f"Error: file not found: {md_path}", file=sys.stderr)
        sys.exit(1)

    sections = extract_sections(lines, heading_text, all_matches)

    if not sections:
        print("Error: heading not found or invalid heading text.", file=sys.stderr)
        sys.exit(1)

    # Output sections
    if all_matches:
        for idx, sec in enumerate(sections):
            if idx > 0:
                print("\n" + ("-" * 8) + "\n")
            sys.stdout.write("".join(sec))
    else:
        sys.stdout.write("".join(sections[0]))

if __name__ == "__main__":
    main()
```

**2) Usage Examples**
```bash
# Extract first matching section
./extract_section.py README.md "## Section Title"

# Extract all sections with the same heading text, separated by '--------'
./extract_section.py README.md "## Section Title" --all

# Directly use python
python3 extract_section.py docs.md "### API Reference"
```

**3) Edge Case Handling Notes**
- Heading not found: exits with error and non‑zero status.
- Section at end of file: returns to EOF with no issue.
- Multiple headings with same text: default outputs the first match; `--all` outputs every match, separated by a clear delimiter.
- Horizontal rules (`---`) are treated as plain text because only `#` headings define section boundaries.
- Heading level is based purely on the number of leading `#` characters, and only lines with a space after the `#` sequence are treated as headings.
