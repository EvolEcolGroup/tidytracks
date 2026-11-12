// Union of convex polygons, used by the LoCoH code (locoh.cpp) to merge the
// local convex hulls into isopleths without going through GEOS. See
// convex_union.cpp for how it works.

#ifndef TIDYTRACKS_CONVEX_UNION_H
#define TIDYTRACKS_CONVEX_UNION_H

#include <cstddef>
#include <vector>

namespace convex_union {

// A closed ring: its vertices, with the first one repeated at the end.
struct Ring {
  std::vector<double> x;
  std::vector<double> y;
};

// A polygon (its shell, followed by its holes), and a set of polygons.
using Polygon = std::vector<Ring>;
using MultiPolygon = std::vector<Polygon>;

// The work done by union_of_convex_polygons() (see convex_union.cpp): the
// work estimated from a sample of the polygons, the work done (0 if the
// union was not attempted), and the total number of vertices of the
// polygons; and, if the union was not built, why (a code from
// convex_union.cpp, where fail() is called: 1-12 when linking the pieces
// into rings and polygons, 20-24 when checking the polygons, 30-31 when the
// work would exceed the budget).
struct UnionStats {
  double estimated_work = 0.0;
  double work = 0.0;
  double n_vertices = 0.0;
  int failure = 0;
};

// Compute the union of nested sets of strictly convex polygons.
//
// The vertices of the polygons are points of (x, y), referred to by their
// index; two different indices must refer to two different points (i.e.
// duplicated points must share the same index). Polygon p is made of the
// points vertices[offsets[p]], ..., vertices[offsets[p + 1] - 1], in
// anticlockwise order, and must be strictly convex (no repeated or collinear
// vertices). For each value of `counts`, the union of the first counts[l]
// polygons is returned in out[l], with its shells clockwise and its holes
// anticlockwise (the orientation of the polygons returned by GEOS).
//
// Returns false (and leaves `out` unspecified) if the polygons are not
// strictly convex, if their coordinates are too large or too small for the
// exact predicates (beyond 2^100 or 2^-100), if the union cannot be built
// reliably (see convex_union.cpp), or, if `max_work_per_vertex` is positive,
// if building it would take more than about that many units of work per
// vertex of the polygons (see convex_union.cpp); the caller should then
// compute the union in another way. If `stats` is not null, the work is
// reported there.
bool union_of_convex_polygons(const std::vector<double>& x,
                              const std::vector<double>& y,
                              const std::vector<std::size_t>& offsets,
                              const std::vector<int>& vertices,
                              const std::vector<int>& counts,
                              std::vector<MultiPolygon>& out,
                              double max_work_per_vertex = 0.0,
                              UnionStats* stats = nullptr);

} // namespace convex_union

#endif
