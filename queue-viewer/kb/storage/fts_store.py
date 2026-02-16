"""SQLite FTS5 full-text search storage."""

import sqlite3
from pathlib import Path

from kb.models import Chunk


class FTSStore:
    """Full-text search using SQLite FTS5."""

    def __init__(self, db_path: str | Path = "kb_fts.db"):
        """
        Initialize FTS store.

        Args:
            db_path: Path to SQLite database file
        """
        self.db_path = Path(db_path)
        self.conn = sqlite3.connect(str(self.db_path), check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        self._init_table()

    def _init_table(self):
        """Initialize FTS5 table."""
        cursor = self.conn.cursor()

        # Create FTS5 virtual table
        cursor.execute(
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts
            USING fts5(
                id UNINDEXED,
                content,
                breadcrumb,
                path UNINDEXED,
                chunk_type UNINDEXED,
                line_start UNINDEXED,
                line_end UNINDEXED,
                chunk_hash UNINDEXED,
                tokenize = 'porter unicode61'
            )
        """
        )

        # Create metadata table for chunk data not needed in FTS
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS chunks_metadata (
                id TEXT PRIMARY KEY,
                file_mtime REAL,
                parent_id TEXT,
                sibling_ids TEXT
            )
        """
        )

        self.conn.commit()

    def upsert(self, chunks: list[Chunk]) -> int:
        """
        Insert or update chunks.

        Args:
            chunks: List of chunks to upsert

        Returns:
            Number of chunks inserted/updated
        """
        if not chunks:
            return 0

        cursor = self.conn.cursor()

        # Get existing chunk hashes
        existing_hashes = {}
        cursor.execute("SELECT id, chunk_hash FROM chunks_fts")
        for row in cursor.fetchall():
            existing_hashes[row["id"]] = row["chunk_hash"]

        # Filter chunks that need updating
        chunks_to_update = []
        for chunk in chunks:
            if chunk.id not in existing_hashes:
                chunks_to_update.append(chunk)
            elif existing_hashes[chunk.id] != chunk.metadata.chunk_hash:
                chunks_to_update.append(chunk)

        if not chunks_to_update:
            return 0

        # Delete existing entries
        ids_to_delete = [
            chunk.id for chunk in chunks_to_update if chunk.id in existing_hashes
        ]
        for chunk_id in ids_to_delete:
            cursor.execute("DELETE FROM chunks_fts WHERE id = ?", (chunk_id,))
            cursor.execute("DELETE FROM chunks_metadata WHERE id = ?", (chunk_id,))

        # Insert new entries
        for chunk in chunks_to_update:
            # Join breadcrumb for searchability
            breadcrumb_text = " > ".join(chunk.metadata.breadcrumb)

            # Insert into FTS table
            cursor.execute(
                """
                INSERT INTO chunks_fts (
                    id, content, breadcrumb, path, chunk_type,
                    line_start, line_end, chunk_hash
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
                (
                    chunk.id,
                    chunk.content,
                    breadcrumb_text,
                    chunk.metadata.path,
                    chunk.metadata.chunk_type,
                    chunk.metadata.line_start,
                    chunk.metadata.line_end,
                    chunk.metadata.chunk_hash,
                ),
            )

            # Insert into metadata table
            cursor.execute(
                """
                INSERT INTO chunks_metadata (id, file_mtime, parent_id, sibling_ids)
                VALUES (?, ?, ?, ?)
            """,
                (
                    chunk.id,
                    chunk.metadata.file_mtime,
                    chunk.parent_id or "",
                    ",".join(chunk.sibling_ids),
                ),
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
        Full-text search.

        Args:
            query: Search query text
            limit: Maximum number of results
            path_filter: Filter by file path
            chunk_type_filter: Filter by chunk type

        Returns:
            List of search results with ranks
        """
        cursor = self.conn.cursor()

        # Convert multi-word query to AND search for better matching
        # "word1 word2" → "word1 AND word2"
        words = query.split()
        if len(words) > 1:
            fts_query = " AND ".join(words)
        else:
            fts_query = query

        # Build WHERE clause for filters
        where_clauses = []
        params = [fts_query]

        if path_filter:
            where_clauses.append("path LIKE ?")
            params.append(f"%{path_filter}%")

        if chunk_type_filter:
            where_clauses.append("chunk_type = ?")
            params.append(chunk_type_filter)

        where_sql = ""
        if where_clauses:
            where_sql = f"AND {' AND '.join(where_clauses)}"

        # Execute FTS query
        cursor.execute(
            f"""
            SELECT
                id,
                content,
                breadcrumb,
                path,
                chunk_type,
                line_start,
                line_end,
                chunk_hash,
                rank
            FROM chunks_fts
            WHERE chunks_fts MATCH ?
            {where_sql}
            ORDER BY rank
            LIMIT ?
        """,
            params + [limit],
        )

        results = []
        for row in cursor.fetchall():
            results.append(
                {
                    "id": row["id"],
                    "content": row["content"],
                    "breadcrumb": (
                        row["breadcrumb"].split(" > ") if row["breadcrumb"] else []
                    ),
                    "path": row["path"],
                    "chunk_type": row["chunk_type"],
                    "line_start": row["line_start"],
                    "line_end": row["line_end"],
                    "chunk_hash": row["chunk_hash"],
                    "rank": row["rank"],
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
        cursor = self.conn.cursor()

        cursor.execute(
            """
            SELECT
                f.id, f.content, f.breadcrumb, f.path, f.chunk_type,
                f.line_start, f.line_end, f.chunk_hash,
                m.file_mtime, m.parent_id, m.sibling_ids
            FROM chunks_fts f
            JOIN chunks_metadata m ON f.id = m.id
            WHERE f.id = ?
        """,
            (chunk_id,),
        )

        row = cursor.fetchone()
        if not row:
            return None

        return {
            "id": row["id"],
            "content": row["content"],
            "breadcrumb": row["breadcrumb"].split(" > ") if row["breadcrumb"] else [],
            "path": row["path"],
            "chunk_type": row["chunk_type"],
            "line_start": row["line_start"],
            "line_end": row["line_end"],
            "chunk_hash": row["chunk_hash"],
            "file_mtime": row["file_mtime"],
            "parent_id": row["parent_id"] if row["parent_id"] else None,
            "sibling_ids": (
                row["sibling_ids"].split(",") if row["sibling_ids"] else []
            ),
        }

    def get_stats(self) -> dict:
        """
        Get storage statistics.

        Returns:
            Dictionary with stats
        """
        cursor = self.conn.cursor()

        # Get total count
        cursor.execute("SELECT COUNT(*) as total FROM chunks_fts")
        total = cursor.fetchone()["total"]

        stats = {"total_chunks": total}

        if total > 0:
            # Get chunk type distribution
            cursor.execute(
                """
                SELECT chunk_type, COUNT(*) as count
                FROM chunks_fts
                GROUP BY chunk_type
            """
            )
            chunk_types = {row["chunk_type"]: row["count"] for row in cursor.fetchall()}
            stats["chunk_types"] = chunk_types

            # Get latest mtime
            cursor.execute("SELECT MAX(file_mtime) as max_mtime FROM chunks_metadata")
            max_mtime = cursor.fetchone()["max_mtime"]
            if max_mtime:
                stats["latest_mtime"] = float(max_mtime)

        return stats

    def close(self):
        """Close database connection."""
        self.conn.close()
