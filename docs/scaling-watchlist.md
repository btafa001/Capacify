# Scaling watch-list (M7)

**Status: no action needed at launch volume.** These are read-amplification and
N+1 patterns that are perfectly fine while the market is a few hundred docs, but
will bite on cost/latency as supply grows. Written down now so they're a
deliberate, tracked decision rather than a surprise later. Rough trigger to
revisit: **low thousands of companies / active posts, or the monthly Firestore
read bill becoming noticeable.**

| # | Where | Pattern | Fix when it bites |
|---|-------|---------|-------------------|
| 1 | `lib/core/services/company_service.dart` → `getCompanies()` | Streams the **entire** `companies` collection to every dashboard client (realtime), then filters client-side. Read-per-doc-per-visitor, unbounded client memory. | Bound with `.limit(...)`, add pagination, and push the `verified`/`contentFlagged`/`suspended` filters server-side (mirrors what `getCapacities` already does for the feed — see M11). |
| 2 | `lib/core/services/company_service.dart` → `findGrantedRequestId` | N+1 over the caller's granted requests (a `get()` per request) to locate one. | Store the resolved chat/request id on the caller's side once granted, or query it directly by a compound field instead of scanning. |
| 3 | Favorites feed (`userFavorites` → per-capacity fetch) | Sequential per-doc `get()`s to hydrate each favourited capacity. | Batch with `whereIn` chunks of 10 (same shape as `receivedRequests` / the Art-15 export helper `_collectReceivedRequests`), or denormalise a small card snapshot onto the favourite doc. |
| 4 | Admin tabs (`lib/core/services/admin_service.dart`) | `getAllCompanies()` and the flagged/pending streams read whole collections live. | Fine for a founder-only console at launch; when the collections are large, paginate and/or move to on-demand queries instead of realtime whole-collection snapshots. |

## Notes
- Items 1 and 4 are the same underlying issue (unbounded realtime
  whole-collection `.snapshots()`), just on different collections. The feed
  (`getCapacities`) already got the bounded treatment — these are the reads that
  didn't.
- None of these are correctness bugs; the app returns the right data. They are
  purely cost/latency at scale.
- When picking this up, do items 1 + 3 first (they're on the hottest paths — the
  dashboard and the favourites feed, hit by every signed-in user).
