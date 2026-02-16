"""Tests for hybrid search."""

import tempfile
from pathlib import Path

import pytest

from kb.models import Chunk, ChunkMetadata
from kb.search import HybridSearch


@pytest.fixture
def sample_chunks():
    """Create sample chunks for testing."""
    chunks = []
    contents = [
        "Python is a programming language",
        "FastAPI is a web framework for Python",
        "LanceDB is a vector database",
    ]
    for i, content in enumerate(contents):
        metadata = ChunkMetadata(
            path=f"test_{i}.md",
            chunk_type="markdown",
            breadcrumb=["Test", f"Section {i}"],
            line_start=i * 10 + 1,
            line_end=i * 10 + 10,
            file_mtime=1234567890.0,
            chunk_hash=f"hash_{i}",
        )
        chunk = Chunk(
            id=f"chunk_{i}",
            content=content,
            metadata=metadata,
        )
        chunks.append(chunk)
    return chunks


def test_hybrid_search_basic(sample_chunks):
    """Test basic hybrid search."""
    with tempfile.TemporaryDirectory() as tmpdir:
        search = HybridSearch(
            vec_db_path=Path(tmpdir) / "test_vec.db",
            fts_db_path=Path(tmpdir) / "test_fts.db",
            embedding_model="sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
        )

        # Index chunks
        result = search.upsert(sample_chunks)
        assert result["vector_updated"] == 3
        assert result["fts_updated"] == 3

        # Search
        results = search.search("Python programming", limit=2)
        assert len(results) <= 2
        assert all("rrf_score" in r for r in results)
        assert results[0]["id"] in ["chunk_0", "chunk_1"]

        search.close()


def test_hybrid_search_with_filters(sample_chunks):
    """Test hybrid search with filters."""
    with tempfile.TemporaryDirectory() as tmpdir:
        search = HybridSearch(
            vec_db_path=Path(tmpdir) / "test_vec.db",
            fts_db_path=Path(tmpdir) / "test_fts.db",
            embedding_model="sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
        )

        search.upsert(sample_chunks)

        # Search with path filter
        results = search.search("Python", limit=5, path_filter="test_0.md")
        assert len(results) <= 1
        if results:
            assert results[0]["path"] == "test_0.md"

        search.close()


def test_hybrid_search_get_by_id(sample_chunks):
    """Test getting chunk by ID."""
    with tempfile.TemporaryDirectory() as tmpdir:
        search = HybridSearch(
            vec_db_path=Path(tmpdir) / "test_vec.db",
            fts_db_path=Path(tmpdir) / "test_fts.db",
            embedding_model="sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
        )

        search.upsert(sample_chunks)

        # Get existing chunk
        chunk = search.get_by_id("chunk_0")
        assert chunk is not None
        assert chunk["id"] == "chunk_0"

        # Get non-existing chunk
        chunk = search.get_by_id("nonexistent")
        assert chunk is None

        search.close()


def test_hybrid_search_stats(sample_chunks):
    """Test getting search statistics."""
    with tempfile.TemporaryDirectory() as tmpdir:
        search = HybridSearch(
            vec_db_path=Path(tmpdir) / "test_vec.db",
            fts_db_path=Path(tmpdir) / "test_fts.db",
            embedding_model="sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
        )

        search.upsert(sample_chunks)

        stats = search.get_stats()
        assert "vector_store" in stats
        assert "fts_store" in stats
        assert stats["vector_store"]["total_chunks"] == 3
        assert stats["fts_store"]["total_chunks"] == 3

        search.close()
