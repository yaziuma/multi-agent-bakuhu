"""Knowledge base API router."""

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from kb.search import HybridSearch

router = APIRouter(prefix="/api/kb", tags=["knowledge-base"])

# Global search instance
_search_instance = None


def get_search() -> HybridSearch:
    """Get or create search instance."""
    global _search_instance
    if _search_instance is None:
        _search_instance = HybridSearch()
    return _search_instance


class SearchResult(BaseModel):
    """Search result item."""

    id: str
    content: str
    path: str
    chunk_type: str
    breadcrumb: list[str]
    line_start: int
    line_end: int
    rrf_score: float | None = None
    rank: float | None = None


class SearchResponse(BaseModel):
    """Search response."""

    results: list[SearchResult]
    total: int
    query: str


class StatsResponse(BaseModel):
    """Statistics response."""

    vector_store: dict
    fts_store: dict


class ChunkResponse(BaseModel):
    """Chunk detail response."""

    id: str
    content: str
    path: str
    chunk_type: str
    breadcrumb: list[str]
    line_start: int
    line_end: int
    chunk_hash: str
    file_mtime: float | None = None
    parent_id: str | None = None
    sibling_ids: list[str] = Field(default_factory=list)


@router.get("/search")
async def search_kb(
    q: str = Query(..., description="Search query"),
    limit: int = Query(10, ge=1, le=100, description="Maximum number of results"),
    format: str = Query("json", description="Output format: json or llm"),
    path_filter: str | None = Query(None, description="Filter by file path"),
    chunk_type_filter: str | None = Query(
        None, description="Filter by chunk type (markdown/yaml)"
    ),
):
    """
    Search knowledge base with hybrid search.

    Supports two output formats:
    - json: Standard JSON response with results array
    - llm: XML-formatted context optimized for LLM consumption

    Query syntax:
    - project:xxx query → Filter by project (e.g., "project:pyprolog test")
    - cmd_XXX → Auto-boost FTS weight for exact command ID match
    """
    search = get_search()

    # Parse project: prefix
    query = q
    if "project:" in query:
        parts = query.split(maxsplit=1)
        if parts[0].startswith("project:"):
            project_name = parts[0][8:]  # Remove "project:" prefix
            query = parts[1] if len(parts) > 1 else ""
            # Convert project name to path filter
            path_filter = f"../context/{project_name}"

    # Detect cmd_ID pattern and adjust weights
    import re
    cmd_id_pattern = r'\bcmd_\d+\b'
    has_cmd_id = bool(re.search(cmd_id_pattern, query))

    # Auto-adjust weights for cmd_ID queries
    vector_weight = 0.3 if has_cmd_id else 0.7
    fts_weight = 0.7 if has_cmd_id else 0.3

    try:
        results = search.search(
            query=query,
            limit=limit,
            path_filter=path_filter,
            chunk_type_filter=chunk_type_filter,
            vector_weight=vector_weight,
            fts_weight=fts_weight,
        )

        if format == "llm":
            # LLM-optimized XML format
            xml_output = _format_llm_context(results, q)
            return {"llm_context": xml_output}

        # Standard JSON format
        search_results = [
            SearchResult(
                id=r["id"],
                content=r["content"],
                path=r["path"],
                chunk_type=r["chunk_type"],
                breadcrumb=r.get("breadcrumb", []),
                line_start=r["line_start"],
                line_end=r["line_end"],
                rrf_score=r.get("rrf_score"),
                rank=r.get("rank"),
            )
            for r in results
        ]

        return SearchResponse(
            results=search_results, total=len(search_results), query=q
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Search failed: {e}") from e


@router.get("/stats", response_model=StatsResponse)
async def get_stats():
    """Get knowledge base statistics."""
    search = get_search()

    try:
        stats = search.get_stats()
        return StatsResponse(
            vector_store=stats["vector_store"], fts_store=stats["fts_store"]
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get stats: {e}") from e


@router.get("/doc/{doc_id}", response_model=ChunkResponse)
async def get_document(doc_id: str):
    """Get specific document chunk by ID."""
    search = get_search()

    try:
        chunk = search.get_by_id(doc_id)

        if not chunk:
            raise HTTPException(status_code=404, detail="Document not found")

        return ChunkResponse(
            id=chunk["id"],
            content=chunk["content"],
            path=chunk["path"],
            chunk_type=chunk["chunk_type"],
            breadcrumb=chunk.get("breadcrumb", []),
            line_start=chunk["line_start"],
            line_end=chunk["line_end"],
            chunk_hash=chunk["chunk_hash"],
            file_mtime=chunk.get("file_mtime"),
            parent_id=chunk.get("parent_id"),
            sibling_ids=chunk.get("sibling_ids", []),
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to get document: {e}"
        ) from e


def _format_llm_context(results: list[dict], query: str) -> str:
    """
    Format search results as XML for LLM consumption.

    Args:
        results: Search results
        query: Original query

    Returns:
        XML-formatted string
    """
    xml_parts = [
        f'<kb_search query="{query}">',
        "  <instruction>以下のドキュメント断片を参考に回答してください。</instruction>",
        "",
    ]

    for rank, result in enumerate(results, start=1):
        breadcrumb_text = " > ".join(result.get("breadcrumb", []))
        xml_parts.append(f'  <document source="{result["path"]}" rank="{rank}">')
        if breadcrumb_text:
            xml_parts.append(f"    <context>{breadcrumb_text}</context>")
        xml_parts.append(f"    <content>\n{result['content']}\n    </content>")
        xml_parts.append("  </document>")
        xml_parts.append("")

    xml_parts.append("</kb_search>")

    return "\n".join(xml_parts)
