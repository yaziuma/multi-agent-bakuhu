"""LanceDB vector storage for knowledge base."""

from pathlib import Path

import lancedb
import pyarrow as pa
from sentence_transformers import SentenceTransformer

from kb.models import Chunk


class LanceDBStore:
    """Vector storage using LanceDB."""

    def __init__(
        self,
        db_path: str | Path = ".lancedb",
        table_name: str = "chunks",
        embedding_model: str = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
    ):
        """
        Initialize LanceDB store.

        Args:
            db_path: Path to LanceDB database directory
            table_name: Name of the table to store chunks
            embedding_model: Hugging Face model ID for embeddings
                           Default is lightweight multilingual model (~470MB)
                           Alternative: BAAI/bge-m3 (more accurate, ~2.2GB)
        """
        self.db_path = Path(db_path)
        self.table_name = table_name
        self.db = lancedb.connect(str(self.db_path))

        # Load embedding model
        self.model = SentenceTransformer(embedding_model)
        self.embedding_dim = self.model.get_sentence_embedding_dimension()

        # Initialize table if needed
        self._init_table()

    def _init_table(self):
        """Initialize LanceDB table with schema."""
        # Check if table exists
        table_names = self.db.table_names()
        if self.table_name not in table_names:
            # Create empty table with schema
            schema = pa.schema(
                [
                    pa.field("id", pa.string()),
                    pa.field("content", pa.string()),
                    pa.field("path", pa.string()),
                    pa.field("chunk_type", pa.string()),
                    pa.field("breadcrumb", pa.list_(pa.string())),
                    pa.field("line_start", pa.int32()),
                    pa.field("line_end", pa.int32()),
                    pa.field("file_mtime", pa.float64()),
                    pa.field("chunk_hash", pa.string()),
                    pa.field("parent_id", pa.string()),
                    pa.field("sibling_ids", pa.list_(pa.string())),
                    pa.field("vector", pa.list_(pa.float32(), self.embedding_dim)),
                ]
            )
            self.db.create_table(self.table_name, schema=schema)

    def upsert(self, chunks: list[Chunk]) -> int:
        """
        Insert or update chunks.

        Performs change detection using chunk_hash:
        - If chunk with same ID exists and hash matches: skip
        - If chunk with same ID exists but hash differs: update
        - If chunk doesn't exist: insert

        Args:
            chunks: List of chunks to upsert

        Returns:
            Number of chunks inserted/updated
        """
        if not chunks:
            return 0

        table = self.db.open_table(self.table_name)

        # Get existing chunks for change detection
        existing_ids = set()
        existing_hashes = {}
        try:
            # Fetch all existing IDs and hashes
            existing = table.to_pandas()
            if not existing.empty:
                existing_ids = set(existing["id"])
                existing_hashes = dict(
                    zip(existing["id"], existing["chunk_hash"], strict=True)
                )
        except Exception:
            # Table might be empty
            pass

        # Filter chunks that need to be updated
        chunks_to_update = []
        for chunk in chunks:
            # Check if update is needed
            if chunk.id not in existing_ids:
                # New chunk - always insert
                chunks_to_update.append(chunk)
            elif existing_hashes.get(chunk.id) != chunk.metadata.chunk_hash:
                # Hash mismatch - update needed
                chunks_to_update.append(chunk)
            # else: Skip - chunk unchanged

        if not chunks_to_update:
            return 0

        # Generate embeddings
        contents = [chunk.content for chunk in chunks_to_update]
        embeddings = self.model.encode(contents, show_progress_bar=False)

        # Prepare data for LanceDB
        records = []
        for chunk, embedding in zip(chunks_to_update, embeddings, strict=True):
            records.append(
                {
                    "id": chunk.id,
                    "content": chunk.content,
                    "path": chunk.metadata.path,
                    "chunk_type": chunk.metadata.chunk_type,
                    "breadcrumb": chunk.metadata.breadcrumb,
                    "line_start": chunk.metadata.line_start,
                    "line_end": chunk.metadata.line_end,
                    "file_mtime": chunk.metadata.file_mtime,
                    "chunk_hash": chunk.metadata.chunk_hash,
                    "parent_id": chunk.parent_id or "",
                    "sibling_ids": chunk.sibling_ids or [],
                    "vector": embedding.tolist(),
                }
            )

        # Delete existing records with same IDs
        ids_to_delete = [
            chunk.id for chunk in chunks_to_update if chunk.id in existing_ids
        ]
        if ids_to_delete:
            # Delete in batches
            for chunk_id in ids_to_delete:
                table.delete(f'id = "{chunk_id}"')

        # Insert new records
        table.add(records)

        return len(chunks_to_update)

    def search(
        self,
        query: str,
        limit: int = 10,
        path_filter: str | None = None,
        chunk_type_filter: str | None = None,
    ) -> list[dict]:
        """
        Vector similarity search.

        Args:
            query: Search query text
            limit: Maximum number of results
            path_filter: Filter by file path (exact match)
            chunk_type_filter: Filter by chunk type (markdown/yaml)

        Returns:
            List of search results with scores
        """
        table = self.db.open_table(self.table_name)

        # Generate query embedding
        query_embedding = self.model.encode([query], show_progress_bar=False)[0]

        # Build search
        search = table.search(query_embedding.tolist()).limit(limit)

        # Apply filters
        if path_filter:
            search = search.where(f'path = "{path_filter}"')
        if chunk_type_filter:
            search = search.where(f'chunk_type = "{chunk_type_filter}"')

        # Execute search
        results = search.to_list()

        return results

    def get_by_id(self, chunk_id: str) -> dict | None:
        """
        Get chunk by ID.

        Args:
            chunk_id: Chunk ID

        Returns:
            Chunk data or None if not found
        """
        table = self.db.open_table(self.table_name)

        try:
            result = table.search().where(f'id = "{chunk_id}"').limit(1).to_list()
            if result:
                return result[0]
        except Exception:
            pass

        return None

    def get_stats(self) -> dict:
        """
        Get storage statistics.

        Returns:
            Dictionary with stats (total_chunks, etc.)
        """
        table = self.db.open_table(self.table_name)

        try:
            df = table.to_pandas()
            total = len(df)

            stats = {
                "total_chunks": total,
                "embedding_model": self.model.get_config_dict().get(
                    "model_name_or_path", "unknown"
                ),
                "embedding_dim": self.embedding_dim,
            }

            if total > 0:
                stats["chunk_types"] = df["chunk_type"].value_counts().to_dict()
                stats["latest_mtime"] = float(df["file_mtime"].max())

            return stats
        except Exception as e:
            return {"error": str(e), "total_chunks": 0}
