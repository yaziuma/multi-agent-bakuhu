"""YAML parser for knowledge base."""

import os
import re
from pathlib import Path
from typing import Any

import yaml

from kb.models import Chunk, ChunkMetadata


class YAMLParser:
    """Parser for YAML files with flattening."""

    def __init__(self):
        """Initialize YAML parser."""
        pass

    def parse(self, file_path: str | Path) -> list[Chunk]:
        """
        Parse YAML file into chunks.

        Args:
            file_path: Path to YAML file

        Returns:
            List of chunks with flattened key-value pairs
        """
        file_path = Path(file_path)
        if not file_path.exists():
            raise FileNotFoundError(f"File not found: {file_path}")

        content = file_path.read_text(encoding="utf-8")
        file_mtime = os.path.getmtime(file_path)

        # Parse YAML
        try:
            data = yaml.safe_load(content)
        except yaml.YAMLError as e:
            raise ValueError(f"Invalid YAML: {e}") from e

        if data is None:
            return []

        # Extract comments
        comments = self._extract_comments(content)

        # Flatten structure
        flattened = self._flatten(data)

        # Create chunks
        chunks = []

        for key, value in flattened.items():
            # Find line number for this key
            line_num = self._find_key_line(content, key)

            # Build chunk content
            chunk_content = f"{key}: {value}"

            # Add comment if exists
            if line_num in comments:
                chunk_content = f"# {comments[line_num]}\n{chunk_content}"

            # Build breadcrumb from key hierarchy
            breadcrumb = key.split(".")

            metadata = ChunkMetadata(
                path=str(file_path),
                chunk_type="yaml",
                breadcrumb=breadcrumb,
                line_start=line_num,
                line_end=line_num,
                file_mtime=file_mtime,
                chunk_hash=Chunk.generate_hash(chunk_content),
            )

            chunk_id = Chunk.generate_id(str(file_path), chunk_content)

            chunks.append(
                Chunk(
                    id=chunk_id,
                    content=chunk_content,
                    metadata=metadata,
                )
            )

        # Build relationships
        chunks = self._build_relationships(chunks)

        return chunks

    def _flatten(
        self, data: Any, parent_key: str = "", sep: str = "."
    ) -> dict[str, str]:
        """
        Flatten nested YAML structure.

        Example:
            db:
              host: localhost
              port: 5432
        Becomes:
            db.host: localhost
            db.port: 5432

        Args:
            data: YAML data (dict or list)
            parent_key: Parent key prefix
            sep: Separator for key hierarchy

        Returns:
            Flattened dict with dot-separated keys
        """
        items = {}

        if isinstance(data, dict):
            for k, v in data.items():
                new_key = f"{parent_key}{sep}{k}" if parent_key else k
                if isinstance(v, (dict, list)):
                    items.update(self._flatten(v, new_key, sep=sep))
                else:
                    items[new_key] = str(v)
        elif isinstance(data, list):
            for i, item in enumerate(data):
                new_key = f"{parent_key}[{i}]"
                if isinstance(item, (dict, list)):
                    items.update(self._flatten(item, new_key, sep=sep))
                else:
                    items[new_key] = str(item)
        else:
            items[parent_key] = str(data)

        return items

    def _extract_comments(self, content: str) -> dict[int, str]:
        """
        Extract comments from YAML file.

        Returns:
            Dict mapping line number to comment text
        """
        comments = {}
        lines = content.split("\n")

        for line_num, line in enumerate(lines, start=1):
            # Match line with comment
            match = re.search(r"#\s*(.+)$", line)
            if match:
                comment_text = match.group(1).strip()
                comments[line_num] = comment_text

        return comments

    def _find_key_line(self, content: str, key: str) -> int:
        """
        Find line number for a given flattened key.

        Args:
            content: YAML file content
            key: Flattened key (e.g., "db.host")

        Returns:
            Line number (1-indexed)
        """
        # For nested keys, search for the leaf key
        leaf_key = key.split(".")[-1].split("[")[0]  # Remove array index if present

        lines = content.split("\n")
        for line_num, line in enumerate(lines, start=1):
            # Match key at start of line (with possible indentation)
            if re.match(rf"^\s*{re.escape(leaf_key)}\s*:", line):
                return line_num

        return 1  # Fallback

    def _build_relationships(self, chunks: list[Chunk]) -> list[Chunk]:
        """Build parent-child and sibling relationships for YAML chunks."""
        if not chunks:
            return chunks

        # Assign parent_id based on breadcrumb hierarchy
        for chunk in chunks:
            breadcrumb = chunk.metadata.breadcrumb
            if len(breadcrumb) > 1:
                parent_breadcrumb = breadcrumb[:-1]
                # Find parent with matching breadcrumb
                for potential_parent in chunks:
                    if potential_parent.metadata.breadcrumb == parent_breadcrumb:
                        chunk.parent_id = potential_parent.id
                        break

        # Assign sibling_ids (same parent)
        for chunk in chunks:
            siblings = [
                c.id
                for c in chunks
                if c.id != chunk.id
                and len(c.metadata.breadcrumb) == len(chunk.metadata.breadcrumb)
                and c.metadata.breadcrumb[:-1] == chunk.metadata.breadcrumb[:-1]
            ]
            chunk.sibling_ids = siblings

        return chunks
