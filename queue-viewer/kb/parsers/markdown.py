"""Markdown parser for knowledge base."""

import os
import re
from pathlib import Path

from kb.models import Chunk, ChunkMetadata


class MarkdownParser:
    """Parser for Markdown documents with heading-based chunking."""

    def __init__(self, max_chunk_size: int = 2000):
        """
        Initialize Markdown parser.

        Args:
            max_chunk_size: Maximum characters per chunk before recursive split
        """
        self.max_chunk_size = max_chunk_size
        self.heading_pattern = re.compile(r"^(#{1,6})\s+(.+)$", re.MULTILINE)

    def parse(self, file_path: str | Path) -> list[Chunk]:
        """
        Parse Markdown file into chunks.

        Args:
            file_path: Path to Markdown file

        Returns:
            List of chunks with metadata and relationships
        """
        file_path = Path(file_path)
        if not file_path.exists():
            raise FileNotFoundError(f"File not found: {file_path}")

        content = file_path.read_text(encoding="utf-8")
        file_mtime = os.path.getmtime(file_path)

        # Extract heading structure
        headings = self._extract_headings(content)

        # Split into chunks by heading
        chunks = self._create_chunks(content, headings, str(file_path), file_mtime)

        # Establish relationships
        chunks = self._build_relationships(chunks)

        return chunks

    def _extract_headings(self, content: str) -> list[dict]:
        """
        Extract all headings with their positions.

        Returns:
            List of dicts with {level, text, line, pos}
        """
        headings = []
        lines = content.split("\n")

        line_pos = 0
        for line_num, line in enumerate(lines, start=1):
            match = re.match(r"^(#{1,6})\s+(.+)$", line)
            if match:
                level = len(match.group(1))
                text = match.group(2).strip()
                headings.append(
                    {
                        "level": level,
                        "text": text,
                        "line": line_num,
                        "pos": line_pos,
                    }
                )
            line_pos += len(line) + 1  # +1 for newline

        return headings

    def _create_chunks(
        self,
        content: str,
        headings: list[dict],
        file_path: str,
        file_mtime: float,
    ) -> list[Chunk]:
        """Create chunks from heading structure."""
        if not headings:
            # No headings: treat entire file as one chunk
            chunk_content = content
            metadata = ChunkMetadata(
                path=file_path,
                chunk_type="markdown",
                breadcrumb=[],
                line_start=1,
                line_end=len(content.split("\n")),
                file_mtime=file_mtime,
                chunk_hash=Chunk.generate_hash(chunk_content),
            )
            chunk_id = Chunk.generate_id(file_path, chunk_content)
            return [
                Chunk(
                    id=chunk_id,
                    content=chunk_content,
                    metadata=metadata,
                )
            ]

        chunks = []
        lines = content.split("\n")

        for i, heading in enumerate(headings):
            # Build breadcrumb from parent headings
            breadcrumb = self._build_breadcrumb(headings, i)

            # Extract chunk content
            start_line = heading["line"]
            if i + 1 < len(headings):
                end_line = headings[i + 1]["line"] - 1
            else:
                end_line = len(lines)

            chunk_lines = lines[start_line - 1 : end_line]
            chunk_content = "\n".join(chunk_lines)

            # Recursive split if too large
            if len(chunk_content) > self.max_chunk_size:
                sub_chunks = self._recursive_split(
                    chunk_content, start_line, breadcrumb
                )
                for sub_content, sub_start, sub_end in sub_chunks:
                    metadata = ChunkMetadata(
                        path=file_path,
                        chunk_type="markdown",
                        breadcrumb=breadcrumb,
                        line_start=sub_start,
                        line_end=sub_end,
                        file_mtime=file_mtime,
                        chunk_hash=Chunk.generate_hash(sub_content),
                    )
                    chunk_id = Chunk.generate_id(file_path, sub_content)
                    chunks.append(
                        Chunk(
                            id=chunk_id,
                            content=sub_content,
                            metadata=metadata,
                        )
                    )
            else:
                metadata = ChunkMetadata(
                    path=file_path,
                    chunk_type="markdown",
                    breadcrumb=breadcrumb,
                    line_start=start_line,
                    line_end=end_line,
                    file_mtime=file_mtime,
                    chunk_hash=Chunk.generate_hash(chunk_content),
                )
                chunk_id = Chunk.generate_id(file_path, chunk_content)
                chunks.append(
                    Chunk(
                        id=chunk_id,
                        content=chunk_content,
                        metadata=metadata,
                    )
                )

        return chunks

    def _build_breadcrumb(self, headings: list[dict], current_idx: int) -> list[str]:
        """Build breadcrumb from parent headings."""
        breadcrumb = []
        current_level = headings[current_idx]["level"]

        # Walk backwards to find parent headings
        for i in range(current_idx, -1, -1):
            heading = headings[i]
            if heading["level"] < current_level:
                breadcrumb.insert(0, heading["text"])
                current_level = heading["level"]
                if current_level == 1:
                    break

        # Add current heading
        breadcrumb.append(headings[current_idx]["text"])

        return breadcrumb

    def _recursive_split(
        self, content: str, start_line: int, breadcrumb: list[str]
    ) -> list[tuple[str, int, int]]:
        """
        Recursively split large chunk by sentence boundaries.

        Returns:
            List of (content, start_line, end_line) tuples
        """
        # Split by double newline (paragraph), then by sentence
        paragraphs = re.split(r"\n\n+", content)
        sub_chunks = []
        current_chunk = []
        current_size = 0
        current_line = start_line

        for para in paragraphs:
            if current_size + len(para) > self.max_chunk_size and current_chunk:
                # Save current chunk
                chunk_content = "\n\n".join(current_chunk)
                chunk_end_line = current_line + sum(
                    c.count("\n") + 1 for c in current_chunk
                )
                sub_chunks.append((chunk_content, current_line, chunk_end_line - 1))
                current_line = chunk_end_line
                current_chunk = [para]
                current_size = len(para)
            else:
                current_chunk.append(para)
                current_size += len(para)

        # Add remaining
        if current_chunk:
            chunk_content = "\n\n".join(current_chunk)
            chunk_end_line = current_line + sum(
                c.count("\n") + 1 for c in current_chunk
            )
            sub_chunks.append((chunk_content, current_line, chunk_end_line - 1))

        return sub_chunks if sub_chunks else [(content, start_line, start_line)]

    def _build_relationships(self, chunks: list[Chunk]) -> list[Chunk]:
        """Build parent-child and sibling relationships."""
        if not chunks:
            return chunks

        # Group by breadcrumb depth
        chunks_by_depth: dict[int, list[Chunk]] = {}
        for chunk in chunks:
            depth = len(chunk.metadata.breadcrumb)
            if depth not in chunks_by_depth:
                chunks_by_depth[depth] = []
            chunks_by_depth[depth].append(chunk)

        # Assign parent_id
        for chunk in chunks:
            breadcrumb = chunk.metadata.breadcrumb
            if len(breadcrumb) > 1:
                parent_breadcrumb = breadcrumb[:-1]
                # Find parent with matching breadcrumb
                for potential_parent in chunks:
                    if potential_parent.metadata.breadcrumb == parent_breadcrumb:
                        chunk.parent_id = potential_parent.id
                        break

        # Assign sibling_ids
        for _depth, depth_chunks in chunks_by_depth.items():
            for chunk in depth_chunks:
                siblings = [
                    c.id
                    for c in depth_chunks
                    if c.id != chunk.id
                    and c.metadata.breadcrumb[:-1] == chunk.metadata.breadcrumb[:-1]
                ]
                chunk.sibling_ids = siblings

        return chunks
