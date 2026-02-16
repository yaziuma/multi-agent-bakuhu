"""Tests for storage layer."""

import tempfile
from pathlib import Path

import pytest

from kb.models import Chunk, ChunkMetadata
from kb.storage import FTSStore, SQLiteVecStore


@pytest.fixture
def sample_chunks():
    """Create sample chunks for testing."""
    chunks = []
    for i in range(3):
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
            content=f"This is test content {i} about knowledge base",
            metadata=metadata,
            parent_id=None if i == 0 else "chunk_0",
            sibling_ids=[f"chunk_{j}" for j in range(3) if j != i],
        )
        chunks.append(chunk)
    return chunks


def test_sqlite_vec_store_upsert(sample_chunks):
    """Test SQLiteVec store upsert."""
    with tempfile.TemporaryDirectory() as tmpdir:
        store = SQLiteVecStore(
            db_path=Path(tmpdir) / "test_vec.db",
            embedding_model="sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
        )

        # First insert
        count = store.upsert(sample_chunks)
        assert count == 3

        # Re-insert with same hashes (should skip)
        count = store.upsert(sample_chunks)
        assert count == 0

        # Modify one chunk
        modified = sample_chunks[0].model_copy(deep=True)
        modified.content = "Modified content"
        modified.metadata.chunk_hash = "new_hash"

        count = store.upsert([modified])
        assert count == 1

        store.close()


def test_sqlite_vec_store_search(sample_chunks):
    """Test SQLiteVec vector search."""
    with tempfile.TemporaryDirectory() as tmpdir:
        store = SQLiteVecStore(
            db_path=Path(tmpdir) / "test_vec.db",
            embedding_model="sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
        )

        store.upsert(sample_chunks)

        # Search
        results = store.search("knowledge base", limit=2)
        assert len(results) <= 2
        assert all("id" in r for r in results)
        assert all("content" in r for r in results)

        store.close()


def test_fts_store_upsert(sample_chunks):
    """Test FTS store upsert."""
    with tempfile.TemporaryDirectory() as tmpdir:
        store = FTSStore(db_path=Path(tmpdir) / "test_fts.db")

        # First insert
        count = store.upsert(sample_chunks)
        assert count == 3

        # Re-insert with same hashes (should skip)
        count = store.upsert(sample_chunks)
        assert count == 0

        # Modify one chunk
        modified = sample_chunks[0].model_copy(deep=True)
        modified.content = "Modified content"
        modified.metadata.chunk_hash = "new_hash"

        count = store.upsert([modified])
        assert count == 1

        store.close()


def test_fts_store_search(sample_chunks):
    """Test FTS full-text search."""
    with tempfile.TemporaryDirectory() as tmpdir:
        store = FTSStore(db_path=Path(tmpdir) / "test_fts.db")

        store.upsert(sample_chunks)

        # Search
        results = store.search("knowledge", limit=2)
        assert len(results) <= 2
        assert all("id" in r for r in results)
        assert all("content" in r for r in results)

        store.close()


def test_fts_store_get_by_id(sample_chunks):
    """Test getting chunk by ID."""
    with tempfile.TemporaryDirectory() as tmpdir:
        store = FTSStore(db_path=Path(tmpdir) / "test_fts.db")

        store.upsert(sample_chunks)

        # Get existing chunk
        chunk = store.get_by_id("chunk_0")
        assert chunk is not None
        assert chunk["id"] == "chunk_0"
        assert "This is test content 0" in chunk["content"]

        # Get non-existing chunk
        chunk = store.get_by_id("nonexistent")
        assert chunk is None

        store.close()


def test_stores_stats(sample_chunks):
    """Test getting storage statistics."""
    with tempfile.TemporaryDirectory() as tmpdir:
        # SQLiteVec stats
        vec_store = SQLiteVecStore(
            db_path=Path(tmpdir) / "test_vec.db",
            embedding_model="sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
        )
        vec_store.upsert(sample_chunks)
        vec_stats = vec_store.get_stats()
        assert vec_stats["total_chunks"] == 3
        assert "embedding_model" in vec_stats

        vec_store.close()

        # FTS stats
        fts_store = FTSStore(db_path=Path(tmpdir) / "test_fts.db")
        fts_store.upsert(sample_chunks)
        fts_stats = fts_store.get_stats()
        assert fts_stats["total_chunks"] == 3
        assert "chunk_types" in fts_stats

        fts_store.close()
