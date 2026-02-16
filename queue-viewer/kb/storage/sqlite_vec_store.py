"""SQLite-vec vector storage for knowledge base (LanceDB alternative)."""

import sqlite3
from pathlib import Path

import numpy as np
import sqlite_vec
from sentence_transformers import SentenceTransformer

from kb.models import Chunk


class SQLiteVecStore:
    """Vector storage using SQLite + sqlite-vec extension."""

    def __init__(
        self,
        db_path: str | Path = "kb_vec.db",
        table_name: str = "chunks",
        embedding_model: str = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
    ):
        """
        Initialize SQLite-vec store.

        Args:
            db_path: Path to SQLite database file
            table_name: Name of the table to store chunks
            embedding_model: Hugging Face model ID for embeddings
                           Default is lightweight multilingual model (~470MB)
                           Alternative: BAAI/bge-m3 (more accurate, ~2.2GB)
        """
        self.db_path = Path(db_path)
        self.table_name = table_name
        self.vec_table_name = f"{table_name}_vec"
        self.embedding_model = embedding_model

        # Load embedding model
        self.model = SentenceTransformer(embedding_model)
        self.embedding_dim = self.model.get_sentence_embedding_dimension()

        # Connect to database and load extension
        self.conn = sqlite3.connect(str(self.db_path), check_same_thread=False)
        self.conn.enable_load_extension(True)
        sqlite_vec.load(self.conn)
        self.conn.enable_load_extension(False)

        # Initialize tables
        self._init_tables()

    def _init_tables(self):
        """Initialize tables with schema."""
        # Metadata table
        self.conn.execute(
            f"""
            CREATE TABLE IF NOT EXISTS {self.table_name} (
                id TEXT PRIMARY KEY,
                content TEXT NOT NULL,
                path TEXT NOT NULL,
                chunk_type TEXT NOT NULL,
                breadcrumb TEXT NOT NULL,
                line_start INTEGER NOT NULL,
                line_end INTEGER NOT NULL,
                file_mtime REAL NOT NULL,
                chunk_hash TEXT NOT NULL,
                parent_id TEXT,
                sibling_ids TEXT
            )
        """
        )

        # Vector table using sqlite-vec
        self.conn.execute(
            f"""
            CREATE VIRTUAL TABLE IF NOT EXISTS {self.vec_table_name}
            USING vec0(
                chunk_id TEXT PRIMARY KEY,
                embedding float[{self.embedding_dim}]
            )
        """
        )

        self.conn.commit()

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

        # Get existing chunks for change detection
        existing_hashes = {}
        cursor = self.conn.execute(f"SELECT id, chunk_hash FROM {self.table_name}")
        for row in cursor:
            existing_hashes[row[0]] = row[1]

        # Filter chunks that need to be updated
        chunks_to_update = []
        for chunk in chunks:
            if chunk.id not in existing_hashes:
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

        # Upsert chunks
        for chunk, embedding in zip(chunks_to_update, embeddings, strict=True):
            # Delete existing chunk if it exists
            self.conn.execute(
                f"DELETE FROM {self.table_name} WHERE id = ?", (chunk.id,)
            )
            self.conn.execute(
                f"DELETE FROM {self.vec_table_name} WHERE chunk_id = ?",
                (chunk.id,),
            )

            # Insert metadata
            breadcrumb_json = "|".join(chunk.metadata.breadcrumb)
            sibling_ids_json = "|".join(chunk.sibling_ids or [])

            self.conn.execute(
                f"""
                INSERT INTO {self.table_name}
                (id, content, path, chunk_type, breadcrumb, line_start, line_end,
                 file_mtime, chunk_hash, parent_id, sibling_ids)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
                (
                    chunk.id,
                    chunk.content,
                    chunk.metadata.path,
                    chunk.metadata.chunk_type,
                    breadcrumb_json,
                    chunk.metadata.line_start,
                    chunk.metadata.line_end,
                    chunk.metadata.file_mtime,
                    chunk.metadata.chunk_hash,
                    chunk.parent_id or "",
                    sibling_ids_json,
                ),
            )

            # Insert vector
            embedding_bytes = embedding.astype(np.float32).tobytes()
            self.conn.execute(
                f"""
                INSERT INTO {self.vec_table_name} (chunk_id, embedding)
                VALUES (?, ?)
            """,
                (chunk.id, embedding_bytes),
            )

        self.conn.commit()

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
        # Generate query embedding
        query_embedding = self.model.encode([query], show_progress_bar=False)[0]
        query_bytes = query_embedding.astype(np.float32).tobytes()

        # Build SQL query
        sql = f"""
            SELECT
                m.id,
                m.content,
                m.path,
                m.chunk_type,
                m.breadcrumb,
                m.line_start,
                m.line_end,
                m.file_mtime,
                m.chunk_hash,
                m.parent_id,
                m.sibling_ids,
                v.distance
            FROM {self.vec_table_name} v
            JOIN {self.table_name} m ON v.chunk_id = m.id
            WHERE v.embedding MATCH ? AND k = ?
        """

        params = [query_bytes, limit]

        # Apply filters
        if path_filter:
            sql += " AND m.path LIKE ?"
            params.append(f"%{path_filter}%")
        if chunk_type_filter:
            sql += " AND m.chunk_type = ?"
            params.append(chunk_type_filter)

        sql += " ORDER BY v.distance"

        # Execute search
        cursor = self.conn.execute(sql, params)

        results = []
        for row in cursor:
            results.append(
                {
                    "id": row[0],
                    "content": row[1],
                    "path": row[2],
                    "chunk_type": row[3],
                    "breadcrumb": row[4].split("|") if row[4] else [],
                    "line_start": row[5],
                    "line_end": row[6],
                    "file_mtime": row[7],
                    "chunk_hash": row[8],
                    "parent_id": row[9] if row[9] else None,
                    "sibling_ids": row[10].split("|") if row[10] else [],
                    "_distance": row[11],
                }
            )

        return results

    def get_by_id(self, chunk_id: str) -> dict | None:
        """
        Get chunk by ID.

        Args:
            chunk_id: Chunk ID

        Returns:
            Chunk data or None if not found
        """
        cursor = self.conn.execute(
            f"""
            SELECT id, content, path, chunk_type, breadcrumb, line_start, line_end,
                   file_mtime, chunk_hash, parent_id, sibling_ids
            FROM {self.table_name}
            WHERE id = ?
        """,
            (chunk_id,),
        )

        row = cursor.fetchone()
        if row:
            return {
                "id": row[0],
                "content": row[1],
                "path": row[2],
                "chunk_type": row[3],
                "breadcrumb": row[4].split("|") if row[4] else [],
                "line_start": row[5],
                "line_end": row[6],
                "file_mtime": row[7],
                "chunk_hash": row[8],
                "parent_id": row[9] if row[9] else None,
                "sibling_ids": row[10].split("|") if row[10] else [],
            }

        return None

    def get_stats(self) -> dict:
        """
        Get storage statistics.

        Returns:
            Dictionary with stats (total_chunks, etc.)
        """
        try:
            cursor = self.conn.execute(f"SELECT COUNT(*) FROM {self.table_name}")
            total = cursor.fetchone()[0]

            stats = {
                "total_chunks": total,
                "embedding_model": self.embedding_model,
                "embedding_dim": self.embedding_dim,
            }

            if total > 0:
                # Get chunk type counts
                cursor = self.conn.execute(
                    f"SELECT chunk_type, COUNT(*) FROM {self.table_name} GROUP BY chunk_type"
                )
                stats["chunk_types"] = {row[0]: row[1] for row in cursor}

                # Get latest mtime
                cursor = self.conn.execute(
                    f"SELECT MAX(file_mtime) FROM {self.table_name}"
                )
                stats["latest_mtime"] = cursor.fetchone()[0]

            return stats
        except Exception as e:
            return {"error": str(e), "total_chunks": 0}

    def close(self):
        """Close database connection."""
        self.conn.close()
