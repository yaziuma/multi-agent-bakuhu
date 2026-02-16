#!/usr/bin/env python3
"""Add queue/ directory to existing knowledge base index."""

import time
from pathlib import Path

from kb.indexer import Indexer

def main():
    """Index queue/ directory."""
    queue_dir = Path("../queue").resolve()

    if not queue_dir.exists():
        print(f"Error: {queue_dir} does not exist")
        return 1

    print(f"Indexing files from: {queue_dir}")
    print("=" * 60)

    start_time = time.time()
    indexer = Indexer(source_dir=queue_dir)
    stats = indexer.index_all()
    elapsed = time.time() - start_time

    print("=" * 60)
    print("Indexing complete!")
    print(f"  Files processed: {stats['files_processed']}")
    print(f"  Files skipped: {stats['files_skipped']}")
    print(f"  Chunks created: {stats['chunks_created']}")
    print(f"  Chunks updated: {stats['chunks_updated']}")
    print(f"  Errors: {len(stats['errors'])}")
    print(f"  Elapsed time: {elapsed:.2f}s")

    if stats["errors"]:
        print("\nErrors:")
        for error in stats["errors"][:10]:
            print(f"  - {error['file']}: {error['error']}")

    # Print final stats
    final_stats = indexer.search.get_stats()
    print("\nFinal statistics:")
    print(f"  Vector store: {final_stats['vector_store']}")
    print(f"  FTS store: {final_stats['fts_store']}")

    return 0

if __name__ == "__main__":
    exit(main())
