"""Data models for knowledge base chunks."""

import hashlib
from typing import Literal

from pydantic import BaseModel, Field


class ChunkMetadata(BaseModel):
    """Metadata for a document chunk."""

    path: str = Field(description="File path relative to project root")
    chunk_type: Literal["markdown", "yaml"] = Field(description="Type of chunk")
    breadcrumb: list[str] = Field(
        default_factory=list, description="Hierarchical context (H1 > H2 > H3)"
    )
    line_start: int = Field(description="Starting line number (1-indexed)")
    line_end: int = Field(description="Ending line number (inclusive)")
    file_mtime: float = Field(description="File modification time (Unix timestamp)")
    chunk_hash: str = Field(description="SHA1 hash of chunk content")


class Chunk(BaseModel):
    """A document chunk with metadata and relationships."""

    id: str = Field(description="Unique chunk ID (path + hash)")
    content: str = Field(description="Chunk text content")
    metadata: ChunkMetadata = Field(description="Chunk metadata")
    parent_id: str | None = Field(
        default=None, description="Parent chunk ID (upper heading level)"
    )
    sibling_ids: list[str] = Field(
        default_factory=list, description="Sibling chunk IDs (same heading level)"
    )

    @staticmethod
    def generate_id(path: str, content: str) -> str:
        """Generate unique chunk ID from path and content."""
        content_hash = hashlib.sha1(content.encode("utf-8")).hexdigest()[:12]
        safe_path = path.replace("/", "_").replace(".", "_")
        return f"{safe_path}_{content_hash}"

    @staticmethod
    def generate_hash(content: str) -> str:
        """Generate SHA1 hash for chunk content."""
        return hashlib.sha1(content.encode("utf-8")).hexdigest()
