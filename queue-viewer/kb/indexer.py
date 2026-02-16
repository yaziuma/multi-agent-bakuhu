"""Indexer to build knowledge base from queue directory."""

import time
from pathlib import Path

from kb.parsers.markdown import MarkdownParser
from kb.parsers.yaml import YAMLParser
from kb.search import HybridSearch


class Indexer:
    """Indexer for building knowledge base from files."""

    def __init__(
        self,
        source_dir: str | Path,
        vec_db_path: str | Path = "kb_vec.db",
        fts_db_path: str | Path = "kb_fts.db",
        embedding_model: str = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
    ):
        """
        Initialize indexer.

        Args:
            source_dir: Source directory to index (e.g., queue/)
            vec_db_path: Path to SQLite vector database
            fts_db_path: Path to SQLite FTS database
            embedding_model: Embedding model to use
        """
        self.source_dir = Path(source_dir)
        self.search = HybridSearch(
            vec_db_path=vec_db_path,
            fts_db_path=fts_db_path,
            embedding_model=embedding_model,
        )
        self.md_parser = MarkdownParser()
        self.yaml_parser = YAMLParser()

    def index_all(self, extensions: list[str] | None = None) -> dict:
        """
        Index all files in source directory.

        Args:
            extensions: List of file extensions to index (default: ['.md', '.yaml', '.yml'])

        Returns:
            Dictionary with indexing statistics
        """
        if extensions is None:
            extensions = [".md", ".yaml", ".yml"]

        start_time = time.time()
        stats = {
            "files_processed": 0,
            "files_skipped": 0,
            "chunks_created": 0,
            "chunks_updated": 0,
            "errors": [],
        }

        # Find all matching files
        files_to_index = []
        for ext in extensions:
            files_to_index.extend(self.source_dir.rglob(f"*{ext}"))

        print(f"Found {len(files_to_index)} files to index")

        # Process each file
        for file_path in files_to_index:
            try:
                chunks = self._parse_file(file_path)
                if chunks:
                    # Upsert chunks
                    result = self.search.upsert(chunks)
                    stats["chunks_created"] += result["vector_updated"]
                    stats["chunks_updated"] += result["fts_updated"]
                    stats["files_processed"] += 1
                    print(
                        f"  ✓ {file_path.relative_to(self.source_dir)}: {len(chunks)} chunks"
                    )
                else:
                    stats["files_skipped"] += 1
                    print(f"  ⊘ {file_path.relative_to(self.source_dir)}: no chunks")
            except Exception as e:
                stats["errors"].append(
                    {
                        "file": str(file_path.relative_to(self.source_dir)),
                        "error": str(e),
                    }
                )
                print(f"  ✗ {file_path.relative_to(self.source_dir)}: {e}")

        elapsed = time.time() - start_time
        stats["elapsed_seconds"] = round(elapsed, 2)

        return stats

    def _parse_file(self, file_path: Path) -> list:
        """
        Parse a file into chunks.

        Args:
            file_path: Path to file

        Returns:
            List of Chunk objects
        """
        suffix = file_path.suffix.lower()

        if suffix == ".md":
            return self.md_parser.parse(file_path)
        elif suffix in {".yaml", ".yml"}:
            return self.yaml_parser.parse(file_path)
        else:
            raise ValueError(f"Unsupported file type: {suffix}")


def main():
    """CLI entry point for indexer."""
    import sys

    if len(sys.argv) < 2:
        print("Usage: uv run python -m kb.indexer <source_dir>")
        print("Example: uv run python -m kb.indexer ../queue")
        sys.exit(1)

    source_dir = sys.argv[1]
    if not Path(source_dir).exists():
        print(f"Error: Directory not found: {source_dir}")
        sys.exit(1)

    print(f"Indexing files from: {source_dir}")
    print("=" * 60)

    indexer = Indexer(source_dir=source_dir)
    stats = indexer.index_all()

    print("=" * 60)
    print("Indexing complete!")
    print(f"  Files processed: {stats['files_processed']}")
    print(f"  Files skipped: {stats['files_skipped']}")
    print(f"  Chunks created: {stats['chunks_created']}")
    print(f"  Chunks updated: {stats['chunks_updated']}")
    print(f"  Errors: {len(stats['errors'])}")
    print(f"  Elapsed time: {stats['elapsed_seconds']}s")

    if stats["errors"]:
        print("\nErrors:")
        for error in stats["errors"][:10]:  # Show first 10 errors
            print(f"  - {error['file']}: {error['error']}")

    # Print final stats
    final_stats = indexer.search.get_stats()
    print("\nFinal statistics:")
    print(f"  Vector store: {final_stats['vector_store']}")
    print(f"  FTS store: {final_stats['fts_store']}")


if __name__ == "__main__":
    main()
