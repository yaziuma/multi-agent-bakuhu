"""FTS-only search fallback for systems without compatible CPU for LanceDB."""

from pathlib import Path

from kb.storage.fts_store import FTSStore


class FTSOnlySearch:
    """Full-text search only (fallback when LanceDB is unavailable)."""

    def __init__(
        self,
        fts_db_path: str | Path = "kb_fts.db",
    ):
        """
        Initialize FTS-only search.

        Args:
            fts_db_path: Path to SQLite FTS database
        """
        self.fts_store = FTSStore(db_path=fts_db_path)

    def search(
        self,
        query: str,
        limit: int = 10,
        path_filter: str | None = None,
        chunk_type_filter: str | None = None,
    ) -> list[dict]:
        """
        Full-text search.

        Args:
            query: Search query text
            limit: Maximum number of results to return
            path_filter: Filter by file path
            chunk_type_filter: Filter by chunk type (markdown/yaml)

        Returns:
            List of search results
        """
        results = self.fts_store.search(
            query=query,
            limit=limit,
            path_filter=path_filter,
            chunk_type_filter=chunk_type_filter,
        )

        # Add placeholder rrf_score for API compatibility
        for result in results:
            result["rrf_score"] = abs(
                result.get("rank", -1.0)
            )  # Convert FTS rank to positive score

        return results

    def get_by_id(self, chunk_id: str) -> dict | None:
        """
        Get chunk by ID.

        Args:
            chunk_id: Chunk ID

        Returns:
            Chunk data or None if not found
        """
        return self.fts_store.get_by_id(chunk_id)

    def get_stats(self) -> dict:
        """
        Get statistics.

        Returns:
            Dictionary with stats
        """
        fts_stats = self.fts_store.get_stats()

        return {
            "vector_store": {
                "status": "unavailable",
                "reason": "CPU does not support required instructions (AVX2/AVX512)",
            },
            "fts_store": fts_stats,
        }

    def upsert(self, chunks: list) -> dict:
        """
        Insert/update chunks in FTS store only.

        Args:
            chunks: List of Chunk objects

        Returns:
            Dictionary with counts of updated chunks
        """
        fts_count = self.fts_store.upsert(chunks)

        return {
            "vector_updated": 0,
            "fts_updated": fts_count,
        }

    def close(self):
        """Close database connections."""
        self.fts_store.close()
