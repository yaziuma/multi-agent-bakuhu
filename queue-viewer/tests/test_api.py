"""Tests for knowledge base API."""

import tempfile
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

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


@pytest.fixture
def test_search_instance(sample_chunks):
    """Create test search instance."""
    with tempfile.TemporaryDirectory() as tmpdir:
        search = HybridSearch(
            vec_db_path=Path(tmpdir) / "test_vec.db",
            fts_db_path=Path(tmpdir) / "test_fts.db",
            embedding_model="sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
        )
        search.upsert(sample_chunks)

        # Override global search instance
        import routers.kb

        original_search = routers.kb._search_instance
        routers.kb._search_instance = search

        yield search

        # Restore original
        routers.kb._search_instance = original_search
        search.close()


@pytest.fixture
def client():
    """Create test client."""
    from main import app

    return TestClient(app)


def test_search_endpoint(client, test_search_instance):
    """Test /api/kb/search endpoint."""
    response = client.get("/api/kb/search?q=Python&limit=2")
    assert response.status_code == 200

    data = response.json()
    assert "results" in data
    assert "total" in data
    assert "query" in data
    assert data["query"] == "Python"
    assert len(data["results"]) <= 2

    if data["results"]:
        result = data["results"][0]
        assert "id" in result
        assert "content" in result
        assert "path" in result


def test_search_endpoint_llm_format(client, test_search_instance):
    """Test /api/kb/search with LLM format."""
    response = client.get("/api/kb/search?q=Python&limit=2&format=llm")
    assert response.status_code == 200

    data = response.json()
    assert "llm_context" in data
    assert "<kb_search" in data["llm_context"]
    assert "<document" in data["llm_context"]
    assert "Python" in data["llm_context"]


def test_search_endpoint_with_filters(client, test_search_instance):
    """Test /api/kb/search with filters."""
    response = client.get(
        "/api/kb/search?q=Python&limit=5&path_filter=test_0.md&chunk_type_filter=markdown"
    )
    assert response.status_code == 200

    data = response.json()
    assert "results" in data
    if data["results"]:
        assert all(r["path"] == "test_0.md" for r in data["results"])
        assert all(r["chunk_type"] == "markdown" for r in data["results"])


def test_stats_endpoint(client, test_search_instance):
    """Test /api/kb/stats endpoint."""
    response = client.get("/api/kb/stats")
    assert response.status_code == 200

    data = response.json()
    assert "vector_store" in data
    assert "fts_store" in data
    assert data["vector_store"]["total_chunks"] == 3
    assert data["fts_store"]["total_chunks"] == 3


def test_get_document_endpoint(client, test_search_instance):
    """Test /api/kb/doc/{doc_id} endpoint."""
    # Get existing document
    response = client.get("/api/kb/doc/chunk_0")
    assert response.status_code == 200

    data = response.json()
    assert data["id"] == "chunk_0"
    assert "content" in data
    assert "path" in data
    assert "breadcrumb" in data

    # Get non-existing document
    response = client.get("/api/kb/doc/nonexistent")
    assert response.status_code == 404
