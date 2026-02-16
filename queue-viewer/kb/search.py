"""Hybrid search combining vector and full-text search."""

from pathlib import Path

from kb.storage import FTSStore, SQLiteVecStore


class HybridSearch:
    """Hybrid search using RRF (Reciprocal Rank Fusion)."""

    def __init__(
        self,
        vec_db_path: str | Path = "kb_vec.db",
        fts_db_path: str | Path = "kb_fts.db",
        embedding_model: str = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
        rrf_k: int = 60,
    ):
        """
        Initialize hybrid search.

        Args:
            vec_db_path: Path to SQLite vector database
            fts_db_path: Path to SQLite FTS database
            embedding_model: Hugging Face model ID for embeddings
            rrf_k: RRF constant (typically 60)
        """
        self.vector_store = SQLiteVecStore(
            db_path=vec_db_path, embedding_model=embedding_model
        )
        self.fts_store = FTSStore(db_path=fts_db_path)
        self.rrf_k = rrf_k

    def search(
        self,
        query: str,
        limit: int = 10,
        path_filter: str | None = None,
        chunk_type_filter: str | None = None,
        vector_weight: float = 0.7,
        fts_weight: float = 0.3,
    ) -> list[dict]:
        """
        Hybrid search with RRF score fusion.

        Args:
            query: Search query text
            limit: Maximum number of results to return
            path_filter: Filter by file path
            chunk_type_filter: Filter by chunk type (markdown/yaml)
            vector_weight: Weight for vector search (default 0.7)
            fts_weight: Weight for FTS search (default 0.3)

        Returns:
            List of search results sorted by RRF score
        """
        # Fetch more results from each store for better fusion
        fetch_limit = limit * 3

        # Vector search
        vector_results = self.vector_store.search(
            query=query,
            limit=fetch_limit,
            path_filter=path_filter,
            chunk_type_filter=chunk_type_filter,
        )

        # FTS search
        fts_results = self.fts_store.search(
            query=query,
            limit=fetch_limit,
            path_filter=path_filter,
            chunk_type_filter=chunk_type_filter,
        )

        # Calculate RRF scores
        rrf_scores = self._calculate_rrf(
            vector_results, fts_results, vector_weight, fts_weight
        )

        # Sort by RRF score and take top results
        sorted_ids = sorted(
            rrf_scores.keys(), key=lambda x: rrf_scores[x], reverse=True
        )[:limit]

        # Build result list
        results = []
        chunk_map = {}

        # Map chunks by ID
        for result in vector_results:
            chunk_map[result["id"]] = result

        for result in fts_results:
            if result["id"] not in chunk_map:
                chunk_map[result["id"]] = result

        for chunk_id in sorted_ids:
            if chunk_id in chunk_map:
                chunk = chunk_map[chunk_id]
                chunk["rrf_score"] = rrf_scores[chunk_id]
                results.append(chunk)

        return results

    def _calculate_rrf(
        self,
        vector_results: list[dict],
        fts_results: list[dict],
        vector_weight: float,
        fts_weight: float,
    ) -> dict[str, float]:
        """
        Calculate RRF scores.

        RRF formula: score = Σ weight / (k + rank)

        Args:
            vector_results: Results from vector search
            fts_results: Results from FTS search
            vector_weight: Weight for vector search
            fts_weight: Weight for FTS search

        Returns:
            Dictionary mapping chunk ID to RRF score
        """
        rrf_scores = {}

        # Add vector search scores
        for rank, result in enumerate(vector_results, start=1):
            chunk_id = result["id"]
            score = vector_weight / (self.rrf_k + rank)
            rrf_scores[chunk_id] = rrf_scores.get(chunk_id, 0) + score

        # Add FTS search scores
        for rank, result in enumerate(fts_results, start=1):
            chunk_id = result["id"]
            score = fts_weight / (self.rrf_k + rank)
            rrf_scores[chunk_id] = rrf_scores.get(chunk_id, 0) + score

        return rrf_scores

    def get_by_id(self, chunk_id: str) -> dict | None:
        """
        Get chunk by ID.

        Args:
            chunk_id: Chunk ID

        Returns:
            Chunk data or None if not found
        """
        # Try FTS first (has more complete metadata)
        result = self.fts_store.get_by_id(chunk_id)
        if result:
            return result

        # Fallback to vector store
        return self.vector_store.get_by_id(chunk_id)

    def get_stats(self) -> dict:
        """
        Get combined statistics.

        Returns:
            Dictionary with stats from both stores
        """
        vector_stats = self.vector_store.get_stats()
        fts_stats = self.fts_store.get_stats()

        return {
            "vector_store": vector_stats,
            "fts_store": fts_stats,
        }

    def upsert(self, chunks: list) -> dict:
        """
        Insert/update chunks in both stores.

        Args:
            chunks: List of Chunk objects

        Returns:
            Dictionary with counts of updated chunks
        """
        vector_count = self.vector_store.upsert(chunks)
        fts_count = self.fts_store.upsert(chunks)

        return {
            "vector_updated": vector_count,
            "fts_updated": fts_count,
        }

    def close(self):
        """Close database connections."""
        self.fts_store.close()
