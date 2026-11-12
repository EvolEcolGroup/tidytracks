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
// strictly convex, or if the union cannot be built reliably (see
// convex_union.cpp); the caller should then compute the union in another way.
bool union_of_convex_polygons(const std::vector<double>& x,
                              const std::vector<double>& y,
                              const std::vector<std::size_t>& offsets,
                              const std::vector<int>& vertices,
                              const std::vector<int>& counts,
                              std::vector<MultiPolygon>& out);

} // namespace convex_union

#endif
