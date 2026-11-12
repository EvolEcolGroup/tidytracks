// Union of convex polygons: the isopleths of LoCoH without GEOS.
//
// The isopleths of LoCoH are unions of up to thousands of small, heavily
// overlapping convex hulls. GEOS (via sf::st_union()) merges such polygons
// two by two (a cascaded union), with one full overlay (noding, building a
// planar graph, labelling it and extracting the result) for each hull; with
// hulls of a few vertices, the fixed cost of each overlay dominates. This file
// computes the union directly from the edges of the hulls, which only works
// because the hulls are convex:
//   1. each edge of each hull is clipped against the other hulls that overlap
//      it: the parts of the edge that no other hull covers are pieces of the
//      boundary of the union (where two hulls share part of an edge and lie on
//      the same side of it, that part is kept for one of them only);
//   2. the pieces are linked, end to end, into rings, which go round the
//      union with its interior on their left: anticlockwise for the outer
//      rings (shells) and clockwise for the holes;
//   3. each hole is assigned to the smallest shell that contains it.
// The isopleths of several levels are nested (each is the union of the
// smallest hulls), so the edges are clipped once, against all the hulls of
// the largest isopleth, and the pieces of each isopleth are then picked out
// from the hulls that it contains.
//
// All the decisions (on which side of a line a point lies, and in which order
// two points lie along an edge) are taken with exact predicates (section 1),
// so that they are consistent with each other. The points where the boundary
// switches from one hull to another are the crossings of two edges, which are
// referred to by the two edges (section 3); their coordinates are only
// computed for the output, with the same formula as GEOS. If the pieces do not
// link into rings (which should only happen in degenerate cases, such as
// three edges crossing at the same point, when the same point can be referred
// to by different pairs of edges), the union is not built, and the caller
// falls back to GEOS.

#include "convex_union.h"

#include <Rcpp.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
#include <numeric>
#include <unordered_map>
#include <utility>
#include <vector>

namespace convex_union {

namespace {

// ---------------------------------------------------------------------------
// 1. Exact predicates
// ---------------------------------------------------------------------------
//
// The basic predicate is the sign of the cross product (b - a) x (d - c),
// which, with c = a, tells on which side of the line from a to b the point d
// lies (positive on the left, negative on the right, zero on the line). It is
// computed in floating point, with Shewchuk's (1997) bound on its rounding
// error; only when the bound cannot tell the sign is it computed exactly, as
// an "expansion" (a sum of doubles that represents a number with no rounding
// error, built with error-free transformations).
//
// Shewchuk, J. R. (1997). Adaptive precision floating-point arithmetic and
// fast robust geometric predicates. Discrete & Computational Geometry, 18,
// 305-363.

constexpr double kEps = std::numeric_limits<double>::epsilon() / 2.0;
// bound on the relative rounding error of (b - a) x (d - c), as a proportion
// of |(bx - ax) * (dy - cy)| + |(by - ay) * (dx - cx)|
constexpr double kCrossBound = (3.0 + 16.0 * kEps) * kEps;

inline int sign_of(double v) { return (v > 0.0) - (v < 0.0); }

// a + b = x + y exactly, with x the rounded sum (Knuth's two-sum)
inline void two_sum(double a, double b, double& x, double& y) {
  x = a + b;
  const double b_virtual = x - a;
  const double a_virtual = x - b_virtual;
  y = (a - a_virtual) + (b - b_virtual);
}

// a - b = x + y exactly, with x the rounded difference
inline void two_diff(double a, double b, double& x, double& y) {
  x = a - b;
  const double b_virtual = a - x;
  const double a_virtual = x + b_virtual;
  y = (a - a_virtual) + (b_virtual - b);
}

// a * b = x + y exactly, with x the rounded product (std::fma computes
// a * b - x with a single rounding, which is then exact)
inline void two_product(double a, double b, double& x, double& y) {
  x = a * b;
  y = std::fma(a, b, -x);
}

// Add b to the expansion e[0], ..., e[n - 1] (whose components do not overlap
// and are sorted by increasing magnitude), in place (Shewchuk's
// Grow-Expansion, leaving out zero components). e must have room for n + 1
// components.
inline void grow(double* e, int& n, double b) {
  double q = b;
  int k = 0;
  for (int i = 0; i < n; ++i) {
    const double ei = e[i];
    double sum;
    double err;
    two_sum(q, ei, sum, err);
    if (err != 0.0) {
      e[k++] = err;
    }
    q = sum;
  }
  if (q != 0.0) {
    e[k++] = q;
  }
  n = k;
}

// The same for an expansion stored in a vector, which grows as needed.
void grow(std::vector<double>& e, double b) {
  int n = static_cast<int>(e.size());
  e.push_back(0.0);
  grow(e.data(), n, b);
  e.resize(n);
}

// The sign of an expansion is that of its largest component, the last one.
inline int sign_of(const double* e, int n) {
  return n == 0 ? 0 : sign_of(e[n - 1]);
}

// (b - a) x (d - c), exactly, as an expansion (of at most 16 components).
std::vector<double> cross_exact(double ax, double ay, double bx, double by,
                                double cx, double cy, double dx, double dy) {
  // each difference is exactly hi + lo
  double ux[2];
  double uy[2];
  double vx[2];
  double vy[2];
  two_diff(bx, ax, ux[0], ux[1]);
  two_diff(by, ay, uy[0], uy[1]);
  two_diff(dx, cx, vx[0], vx[1]);
  two_diff(dy, cy, vy[0], vy[1]);
  double e[17];
  int n = 0;
  for (int i = 0; i < 2; ++i) {
    for (int j = 0; j < 2; ++j) {
      double hi;
      double lo;
      two_product(ux[i], vy[j], hi, lo);
      grow(e, n, lo);
      grow(e, n, hi);
      two_product(uy[i], vx[j], hi, lo);
      grow(e, n, -lo);
      grow(e, n, -hi);
    }
  }
  return std::vector<double>(e, e + n);
}

// The product of two expansions, exactly.
std::vector<double> product(const std::vector<double>& e,
                            const std::vector<double>& f) {
  std::vector<double> out;
  for (const double a : e) {
    for (const double b : f) {
      double hi;
      double lo;
      two_product(a, b, hi, lo);
      grow(out, lo);
      grow(out, hi);
    }
  }
  return out;
}

// (b - a) x (d - c) in floating point, with a bound on its rounding error.
struct Approx {
  double value;
  double error;
};

inline Approx cross_approx(double ax, double ay, double bx, double by,
                           double cx, double cy, double dx, double dy) {
  const double l = (bx - ax) * (dy - cy);
  const double r = (by - ay) * (dx - cx);
  return {l - r, kCrossBound * (std::fabs(l) + std::fabs(r))};
}

// The sign of (b - a) x (d - c), given its approximation: from the
// approximation if the error bound allows it, or else from the exact value.
// (An error bound of zero means that both products are exactly zero, as the
// difference of two doubles is only zero if they are equal, and the products
// of differences of coordinates do not underflow.)
inline int cross_sign(const Approx& approx, double ax, double ay, double bx,
                      double by, double cx, double cy, double dx, double dy) {
  if (approx.value > approx.error) {
    return 1;
  }
  if (-approx.value > approx.error) {
    return -1;
  }
  if (approx.error == 0.0) {
    return 0;
  }
  const std::vector<double> e = cross_exact(ax, ay, bx, by, cx, cy, dx, dy);
  return sign_of(e.data(), static_cast<int>(e.size()));
}

// ---------------------------------------------------------------------------
// 2. Clipping an edge against a convex polygon
// ---------------------------------------------------------------------------
//
// Along an edge from a to b, the points where the edge starts or stops being
// covered by a polygon ("breakpoints") are either vertices that lie exactly
// on the edge (a and b included), or crossings of the edge with an edge of
// the polygon whose ends lie strictly on either side of it.

struct Breakpoint {
  int v;          // the vertex, or -1 for a crossing
  int g1, g2;     // crossing: the ends of the edge crossed
  int s1;         // crossing: the side of g1 relative to the edge
  int sa, sb;     // crossing: the sides of a and b relative to g1 -> g2
  Approx oa, ob;  // crossing: (g2 - g1) x (a - g1) and (g2 - g1) x (b - g1)
};

class Edge {
public:
  Edge(const double* x, const double* y, int a, int b)
      : x_(x), y_(y), a_(a), b_(b), ax_(x[a]), ay_(y[a]), bx_(x[b]),
        by_(y[b]), dx_(x[b] - x[a]), dy_(y[b] - y[a]),
        dir_x_(sign_of(x[b] - x[a])), dir_y_(sign_of(y[b] - y[a])) {}

  // The side of the vertex v relative to the edge: 1 on the left, -1 on the
  // right, 0 on the line through a and b.
  int side(int v) const {
    // the ends of the edge are on its line (the test below would only find
    // it out with exact arithmetic for b, as dx * dy - dy * dx has a
    // non-zero error bound)
    if (v == a_ || v == b_) {
      return 0;
    }
    const double l = dx_ * (y_[v] - ay_);
    const double r = dy_ * (x_[v] - ax_);
    const Approx approx = {l - r, kCrossBound * (std::fabs(l) + std::fabs(r))};
    return cross_sign(approx, ax_, ay_, bx_, by_, ax_, ay_, x_[v], y_[v]);
  }

  Breakpoint vertex(int v) const {
    Breakpoint p;
    p.v = v;
    return p;
  }

  // The crossing of the edge with g1 -> g2, where s1 is the side of g1.
  Breakpoint crossing(int g1, int g2, int s1) const {
    Breakpoint p;
    p.v = -1;
    p.g1 = g1;
    p.g2 = g2;
    p.s1 = s1;
    p.oa = cross_approx(x_[g1], y_[g1], x_[g2], y_[g2], x_[g1], y_[g1], ax_,
                        ay_);
    p.sa = cross_sign(p.oa, x_[g1], y_[g1], x_[g2], y_[g2], x_[g1], y_[g1],
                      ax_, ay_);
    p.ob = cross_approx(x_[g1], y_[g1], x_[g2], y_[g2], x_[g1], y_[g1], bx_,
                        by_);
    p.sb = cross_sign(p.ob, x_[g1], y_[g1], x_[g2], y_[g2], x_[g1], y_[g1],
                      bx_, by_);
    return p;
  }

  // The order of two breakpoints along the edge, from a to b: -1 if p comes
  // before q, 1 if it comes after, 0 if they are the same point.
  int compare(const Breakpoint& p, const Breakpoint& q) const {
    if (p.v >= 0 && q.v >= 0) {
      return compare_vertices(p.v, q.v);
    }
    if (p.v >= 0) {
      return compare_vertex_crossing(p.v, q);
    }
    if (q.v >= 0) {
      return -compare_vertex_crossing(q.v, p);
    }
    return compare_crossings(p, q);
  }

  // The part of the edge whose right side is inside the convex polygon with
  // vertices g[0], ..., g[m - 1] (anticlockwise). If that part is not empty,
  // returns true, with its ends in lo and hi. Where an edge of the polygon
  // lies along this edge, on the same side of it (both polygons on the left),
  // that part of the boundary must only be kept once: it counts as covered if
  // `owner` is true (the other polygon keeps it). If the polygon only touches
  // the edge from the right, at one of its vertices (inside the edge), also
  // returns true, with lo and hi both at that vertex: the boundary of the
  // union may touch itself there, so the edge must have a node there, for the
  // rings to be split there (as GEOS does). `side` is scratch space.
  bool covered(const int* g, int m, bool owner, std::vector<int>& side,
               Breakpoint& lo, Breakpoint& hi) const {
    side.resize(m);
    bool left = false;
    bool right = false;
    for (int j = 0; j < m; ++j) {
      side[j] = this->side(g[j]);
      left = left || side[j] > 0;
      right = right || side[j] < 0;
    }
    const Breakpoint start = vertex(a_);
    const Breakpoint end = vertex(b_);
    if (left && right) {
      // the line through the edge crosses the interior of the polygon: going
      // anticlockwise round the polygon, it enters where the vertices go from
      // the left of the edge to its right, and leaves where they go from the
      // right to the left (either through an edge of the polygon, or through
      // a vertex on the line)
      Breakpoint entry;
      Breakpoint exit;
      for (int j = 0; j < m; ++j) {
        const int k = (j + 1) % m;
        if (side[j] > 0 && side[k] < 0) {
          entry = crossing(g[j], g[k], 1);
        } else if (side[j] > 0 && side[k] == 0) {
          entry = vertex(g[k]);
        } else if (side[j] < 0 && side[k] > 0) {
          exit = crossing(g[j], g[k], -1);
        } else if (side[j] < 0 && side[k] == 0) {
          exit = vertex(g[k]);
        }
      }
      // keep the part of the chord (entry, exit) that is on the edge
      if (compare(exit, start) <= 0 || compare(entry, end) >= 0) {
        return false;
      }
      lo = compare(entry, start) <= 0 ? start : entry;
      hi = compare(exit, end) >= 0 ? end : exit;
      return true;
    }
    // otherwise, the polygon is on one side of the line, and covers part of
    // the edge only if one of its edges lies along the line
    for (int j = 0; j < m; ++j) {
      const int k = (j + 1) % m;
      if (side[j] != 0 || side[k] != 0) {
        continue;
      }
      if (left) {
        // on the left: the two edges go the same way
        if (!owner) {
          return false;
        }
        lo = compare_vertices(g[j], a_) > 0 ? vertex(g[j]) : start;
        hi = compare_vertices(g[k], b_) < 0 ? vertex(g[k]) : end;
      } else {
        // on the right: the two edges go opposite ways
        lo = compare_vertices(g[k], a_) > 0 ? vertex(g[k]) : start;
        hi = compare_vertices(g[j], b_) < 0 ? vertex(g[j]) : end;
      }
      return compare_vertices(lo.v, hi.v) < 0;
    }
    // a polygon on the right that touches the line at a single vertex
    if (right) {
      for (int j = 0; j < m; ++j) {
        if (side[j] == 0 && compare_vertices(g[j], a_) > 0 &&
            compare_vertices(g[j], b_) < 0) {
          lo = hi = vertex(g[j]);
          return true;
        }
      }
    }
    return false;
  }

private:
  const double* x_;
  const double* y_;
  int a_, b_;
  double ax_, ay_, bx_, by_;
  double dx_, dy_;
  int dir_x_, dir_y_;

  // Two vertices on the line through a and b: compare their x coordinates
  // (or their y coordinates if the line is vertical), which is exact.
  int compare_vertices(int u, int w) const {
    if (u == w) {
      return 0;
    }
    if (dir_x_ != 0) {
      return dir_x_ * ((x_[u] > x_[w]) - (x_[u] < x_[w]));
    }
    return dir_y_ * ((y_[u] > y_[w]) - (y_[u] < y_[w]));
  }

  // A vertex v on the line and the crossing c with g1 -> g2. Along the line,
  // (g2 - g1) x (p - g1) is zero at c, and is proportional to the distance
  // from c (counted positively from a towards b), with the sign of
  // (g2 - g1) x (b - a), which is the side s1 of g1 relative to the edge (as
  // g1 and g2 are on either side of it). So v comes after c if its side
  // relative to g1 -> g2, times s1, is positive.
  int compare_vertex_crossing(int v, const Breakpoint& c) const {
    int side_v;
    if (v == a_) {
      side_v = c.sa;
    } else if (v == b_) {
      side_v = c.sb;
    } else {
      const Approx approx =
        cross_approx(x_[c.g1], y_[c.g1], x_[c.g2], y_[c.g2], x_[c.g1],
                     y_[c.g1], x_[v], y_[v]);
      side_v = cross_sign(approx, x_[c.g1], y_[c.g1], x_[c.g2], y_[c.g2],
                          x_[c.g1], y_[c.g1], x_[v], y_[v]);
    }
    return side_v * c.s1;
  }

  // Two crossings: the crossing with g1 -> g2 is at the fraction
  // t = |oa| / (|oa| + |ob|) of the edge, so that the order of two crossings
  // p and q is the sign of |oa_p| * |ob_q| - |oa_q| * |ob_p|.
  int compare_crossings(const Breakpoint& p, const Breakpoint& q) const {
    if ((p.g1 == q.g1 && p.g2 == q.g2) || (p.g1 == q.g2 && p.g2 == q.g1)) {
      return 0;
    }
    const double pa = std::fabs(p.oa.value);
    const double pb = std::fabs(p.ob.value);
    const double qa = std::fabs(q.oa.value);
    const double qb = std::fabs(q.ob.value);
    const double l = pa * qb;
    const double r = qa * pb;
    // bound on the error of l - r, from the errors of the four values and
    // the rounding of the products and of the difference
    const double error =
      (pa * q.ob.error + qb * p.oa.error + p.oa.error * q.ob.error +
       qa * p.ob.error + pb * q.oa.error + q.oa.error * p.ob.error) *
        (1.0 + 8.0 * kEps) +
      4.0 * kEps * (l + r);
    const double diff = l - r;
    if (diff > error) {
      return 1;
    }
    if (-diff > error) {
      return -1;
    }
    // too close to call in floating point: compute exactly
    std::vector<double> e_pa = orient_exact(p, ax_, ay_, p.sa);
    std::vector<double> e_pb = orient_exact(p, bx_, by_, p.sb);
    std::vector<double> e_qa = orient_exact(q, ax_, ay_, q.sa);
    std::vector<double> e_qb = orient_exact(q, bx_, by_, q.sb);
    std::vector<double> e = product(e_pa, e_qb);
    for (const double c : product(e_qa, e_pb)) {
      grow(e, -c);
    }
    return sign_of(e.data(), static_cast<int>(e.size()));
  }

  // |(g2 - g1) x (point - g1)| exactly, given its sign
  std::vector<double> orient_exact(const Breakpoint& c, double px, double py,
                                   int sign) const {
    std::vector<double> e =
      cross_exact(x_[c.g1], y_[c.g1], x_[c.g2], y_[c.g2], x_[c.g1], y_[c.g1],
                  px, py);
    if (sign < 0) {
      for (double& component : e) {
        component = -component;
      }
    }
    return e;
  }
};

// ---------------------------------------------------------------------------
// 3. Nodes: the ends of the pieces of the boundary
// ---------------------------------------------------------------------------
//
// A node is a vertex, or the crossing of two edges (each given by its two
// ends), whatever the hulls these edges belong to. When two breakpoints on
// the same edge are found to be the same point (e.g. two edges that cross
// it at the same point), their nodes are merged (with a union-find), so that
// the pieces that end there are linked together.

struct CrossingKey {
  int k[4];
  bool operator==(const CrossingKey& o) const {
    return k[0] == o.k[0] && k[1] == o.k[1] && k[2] == o.k[2] &&
           k[3] == o.k[3];
  }
};

struct CrossingKeyHash {
  std::size_t operator()(const CrossingKey& key) const {
    // FNV-1a
    std::uint64_t h = 1469598103934665603ULL;
    for (int i = 0; i < 4; ++i) {
      h ^= static_cast<std::uint32_t>(key.k[i]);
      h *= 1099511628211ULL;
    }
    return static_cast<std::size_t>(h);
  }
};

// The intersection of the lines through (p1, p2) and (q1, q2), computed as
// GEOS does (algorithm::Intersection::intersection(), with the coordinates
// taken relative to the middle of the overlap of the bounding boxes of the
// two segments, to reduce rounding errors), and replaced by the nearest end
// of a segment if rounding puts it outside the bounding boxes of the
// segments (as in GEOS's LineIntersector).
void intersection(double p1x, double p1y, double p2x, double p2y, double q1x,
                  double q1y, double q2x, double q2y, double& ix,
                  double& iy) {
  const double min_x =
    std::max(std::min(p1x, p2x), std::min(q1x, q2x));
  const double max_x =
    std::min(std::max(p1x, p2x), std::max(q1x, q2x));
  const double min_y =
    std::max(std::min(p1y, p2y), std::min(q1y, q2y));
  const double max_y =
    std::min(std::max(p1y, p2y), std::max(q1y, q2y));
  const double mid_x = (min_x + max_x) / 2.0;
  const double mid_y = (min_y + max_y) / 2.0;
  const double a1x = p1x - mid_x;
  const double a1y = p1y - mid_y;
  const double a2x = p2x - mid_x;
  const double a2y = p2y - mid_y;
  const double b1x = q1x - mid_x;
  const double b1y = q1y - mid_y;
  const double b2x = q2x - mid_x;
  const double b2y = q2y - mid_y;
  const double px = a1y - a2y;
  const double py = a2x - a1x;
  const double pw = a1x * a2y - a2x * a1y;
  const double qx = b1y - b2y;
  const double qy = b2x - b1x;
  const double qw = b1x * b2y - b2x * b1y;
  const double xw = py * qw - qy * pw;
  const double yw = qx * pw - px * qw;
  const double w = px * qy - qx * py;
  ix = xw / w + mid_x;
  iy = yw / w + mid_y;
  const bool in_envelopes =
    std::isfinite(ix) && std::isfinite(iy) &&
    ix >= std::min(p1x, p2x) && ix <= std::max(p1x, p2x) &&
    iy >= std::min(p1y, p2y) && iy <= std::max(p1y, p2y) &&
    ix >= std::min(q1x, q2x) && ix <= std::max(q1x, q2x) &&
    iy >= std::min(q1y, q2y) && iy <= std::max(q1y, q2y);
  if (in_envelopes) {
    return;
  }
  // the end of a segment nearest to the other segment
  auto segment_distance = [](double px0, double py0, double ax0, double ay0,
                             double bx0, double by0) {
    const double dx = bx0 - ax0;
    const double dy = by0 - ay0;
    const double len2 = dx * dx + dy * dy;
    double t = len2 > 0.0 ? ((px0 - ax0) * dx + (py0 - ay0) * dy) / len2 : 0.0;
    t = std::min(1.0, std::max(0.0, t));
    return std::hypot(px0 - (ax0 + t * dx), py0 - (ay0 + t * dy));
  };
  const double ends[4][2] = {{p1x, p1y}, {p2x, p2y}, {q1x, q1y}, {q2x, q2y}};
  double best = std::numeric_limits<double>::infinity();
  for (int i = 0; i < 4; ++i) {
    const double d = i < 2 ? segment_distance(ends[i][0], ends[i][1], q1x,
                                              q1y, q2x, q2y)
                           : segment_distance(ends[i][0], ends[i][1], p1x,
                                              p1y, p2x, p2y);
    if (d < best) {
      best = d;
      ix = ends[i][0];
      iy = ends[i][1];
    }
  }
}

class Nodes {
public:
  Nodes(const double* x, const double* y, std::size_t n_points)
      : x_(x), y_(y), vertex_node_(n_points, -1) {}

  // the node at the vertex v
  int vertex(int v) {
    if (vertex_node_[v] < 0) {
      vertex_node_[v] = add(x_[v], y_[v], true);
    }
    return vertex_node_[v];
  }

  // the node at the crossing of the edges a-b and g1-g2 (in either
  // direction)
  int crossing(int a, int b, int g1, int g2) {
    int s[2][2] = {{std::min(a, b), std::max(a, b)},
                   {std::min(g1, g2), std::max(g1, g2)}};
    if (s[1][0] < s[0][0] || (s[1][0] == s[0][0] && s[1][1] < s[0][1])) {
      std::swap(s[0][0], s[1][0]);
      std::swap(s[0][1], s[1][1]);
    }
    const CrossingKey key = {{s[0][0], s[0][1], s[1][0], s[1][1]}};
    const auto found = crossing_node_.find(key);
    if (found != crossing_node_.end()) {
      return found->second;
    }
    double ix;
    double iy;
    intersection(x_[s[0][0]], y_[s[0][0]], x_[s[0][1]], y_[s[0][1]],
                 x_[s[1][0]], y_[s[1][0]], x_[s[1][1]], y_[s[1][1]], ix, iy);
    const int id = add(ix, iy, false);
    crossing_node_.emplace(key, id);
    return id;
  }

  int find(int i) {
    while (parent_[i] != i) {
      parent_[i] = parent_[parent_[i]];
      i = parent_[i];
    }
    return i;
  }

  void merge(int i, int j) {
    i = find(i);
    j = find(j);
    if (i != j) {
      parent_[std::max(i, j)] = std::min(i, j);
    }
  }

  // Once all the nodes are known: the coordinates of each set of merged
  // nodes are those of a vertex if there is one among them (as they are
  // exact), or else those of the first node created.
  void finish() {
    const int n = static_cast<int>(parent_.size());
    std::vector<int> chosen(n, -1);
    for (int i = 0; i < n; ++i) {
      const int r = find(i);
      if (chosen[r] < 0 || (is_vertex_[i] && !is_vertex_[chosen[r]])) {
        chosen[r] = i;
      }
    }
    rx_.assign(n, 0.0);
    ry_.assign(n, 0.0);
    for (int i = 0; i < n; ++i) {
      if (chosen[i] >= 0) {
        rx_[i] = nx_[chosen[i]];
        ry_[i] = ny_[chosen[i]];
      }
    }
  }

  // coordinates of a node that is the root of its set (after finish())
  double x(int root) const { return rx_[root]; }
  double y(int root) const { return ry_[root]; }

private:
  const double* x_;
  const double* y_;
  std::vector<int> vertex_node_;
  std::unordered_map<CrossingKey, int, CrossingKeyHash> crossing_node_;
  std::vector<int> parent_;
  std::vector<double> nx_, ny_;
  std::vector<char> is_vertex_;
  std::vector<double> rx_, ry_;

  int add(double x, double y, bool is_vertex) {
    const int id = static_cast<int>(parent_.size());
    parent_.push_back(id);
    nx_.push_back(x);
    ny_.push_back(y);
    is_vertex_.push_back(is_vertex ? 1 : 0);
    return id;
  }
};

// A piece of the boundary of the union: from node `from` to node `to`,
// along the edge from vertex a to vertex b (whose direction is used to sort
// the pieces round a node).
struct Piece {
  int from, to;
  int a, b;
};

// ---------------------------------------------------------------------------
// 4. Linking the pieces into rings, and the rings into polygons
// ---------------------------------------------------------------------------

// Directions of edges (from vertex p to vertex q), sorted by angle,
// anticlockwise from the direction of the positive x axis.
class DirectionOrder {
public:
  DirectionOrder(const double* x, const double* y) : x_(x), y_(y) {}

  // -1 if the direction p -> q comes before r -> s, 1 if it comes after, 0
  // if they are the same direction
  int compare(int p, int q, int r, int s) const {
    const int h1 = half(p, q);
    const int h2 = half(r, s);
    if (h1 != h2) {
      return h1 < h2 ? -1 : 1;
    }
    const Approx approx =
      cross_approx(x_[p], y_[p], x_[q], y_[q], x_[r], y_[r], x_[s], y_[s]);
    // r -> s is anticlockwise from p -> q if the cross product is positive
    return -cross_sign(approx, x_[p], y_[p], x_[q], y_[q], x_[r], y_[r],
                       x_[s], y_[s]);
  }

private:
  const double* x_;
  const double* y_;

  // 0 for directions in [0, pi), 1 for directions in [pi, 2 pi)
  int half(int p, int q) const {
    const double dx = x_[q] - x_[p];
    const double dy = y_[q] - y_[p];
    return (dy > 0.0 || (dy == 0.0 && dx > 0.0)) ? 0 : 1;
  }
};

// Twice the signed area of a ring (positive if anticlockwise).
double ring_area2(const std::vector<double>& rx,
                  const std::vector<double>& ry) {
  double area = 0.0;
  const std::size_t n = rx.size();
  for (std::size_t i = 0, j = n - 1; i < n; j = i++) {
    area += rx[j] * ry[i] - rx[i] * ry[j];
  }
  return area;
}

// Whether the point (px, py) is inside the ring (crossing number test).
bool point_in_ring(double px, double py, const std::vector<double>& rx,
                   const std::vector<double>& ry) {
  bool inside = false;
  const std::size_t n = rx.size();
  for (std::size_t i = 0, j = n - 1; i < n; j = i++) {
    if ((ry[i] > py) != (ry[j] > py) &&
        px < (rx[j] - rx[i]) * (py - ry[i]) / (ry[j] - ry[i]) + rx[i]) {
      inside = !inside;
    }
  }
  return inside;
}

// Link the pieces of the boundary of one union into rings, and the rings
// into polygons. Returns false if the pieces do not form closed rings.
bool assemble(const std::vector<Piece>& pieces, Nodes& nodes,
              const double* x, const double* y, MultiPolygon& out) {
  out.clear();
  const int n_pieces = static_cast<int>(pieces.size());
  if (n_pieces == 0) {
    return true;
  }
  // the nodes, numbered from 0, with their outgoing pieces
  std::vector<int> from(n_pieces);
  std::vector<int> to(n_pieces);
  std::unordered_map<int, int> local;
  local.reserve(2 * static_cast<std::size_t>(n_pieces));
  auto local_id = [&local](int node) {
    const auto inserted = local.emplace(node, static_cast<int>(local.size()));
    return inserted.first->second;
  };
  for (int i = 0; i < n_pieces; ++i) {
    from[i] = local_id(nodes.find(pieces[i].from));
    to[i] = local_id(nodes.find(pieces[i].to));
    if (from[i] == to[i]) {
      return false;
    }
  }
  const int n_nodes = static_cast<int>(local.size());
  std::vector<int> n_in(n_nodes, 0);
  std::vector<int> out_start(n_nodes + 1, 0);
  for (int i = 0; i < n_pieces; ++i) {
    ++n_in[to[i]];
    ++out_start[from[i] + 1];
  }
  for (int v = 0; v < n_nodes; ++v) {
    // every node must have as many pieces going in as going out
    if (n_in[v] != out_start[v + 1]) {
      return false;
    }
    out_start[v + 1] += out_start[v];
  }
  std::vector<int> out_pieces(n_pieces);
  {
    std::vector<int> fill(out_start.begin(), out_start.end() - 1);
    for (int i = 0; i < n_pieces; ++i) {
      out_pieces[fill[from[i]]++] = i;
    }
  }
  std::vector<int> in_pieces(n_pieces);
  {
    std::vector<int> fill(out_start.begin(), out_start.end() - 1);
    for (int i = 0; i < n_pieces; ++i) {
      in_pieces[fill[to[i]]++] = i;
    }
  }

  // the piece that follows each piece: at a node where the boundary only
  // passes once, the only piece going out; where it passes several times
  // (where the union touches itself at a point), the piece going out that is
  // first clockwise from the piece coming in, which keeps the interior of the
  // union, on the left of both, between them
  std::vector<int> next(n_pieces, -1);
  const DirectionOrder order(x, y);
  struct Ray {
    int p, q;      // direction, from vertex p to vertex q
    int piece;
    bool outgoing;
  };
  std::vector<Ray> rays;
  for (int v = 0; v < n_nodes; ++v) {
    const int start = out_start[v];
    const int degree = out_start[v + 1] - start;
    if (degree == 1) {
      next[in_pieces[start]] = out_pieces[start];
      continue;
    }
    rays.clear();
    for (int j = start; j < start + degree; ++j) {
      const Piece& o = pieces[out_pieces[j]];
      rays.push_back({o.a, o.b, out_pieces[j], true});
      // a piece coming in points, from the node, back along its edge
      const Piece& in = pieces[in_pieces[j]];
      rays.push_back({in.b, in.a, in_pieces[j], false});
    }
    std::sort(rays.begin(), rays.end(), [&order](const Ray& r, const Ray& s) {
      return order.compare(r.p, r.q, s.p, s.q) < 0;
    });
    const int n_rays = static_cast<int>(rays.size());
    for (int j = 0; j < n_rays; ++j) {
      const Ray& r = rays[j];
      const Ray& s = rays[(j + 1) % n_rays];
      // going round the node, pieces must alternate between going in and out,
      // in distinct directions
      if (r.outgoing == s.outgoing || order.compare(r.p, r.q, s.p, s.q) == 0) {
        return false;
      }
      if (s.outgoing == false) {
        // r, going out, is the first piece clockwise from s, coming in
        next[s.piece] = r.piece;
      }
    }
  }

  // Follow the pieces round the boundary of each part of the union. Where
  // the boundary touches itself (e.g. a hole touching the shell at a point),
  // following the pieces in this way goes round both rings in one go, coming
  // back to the node where they touch; as GEOS does, such a "maximal" ring is
  // cut into "minimal" rings, which only visit each node once: the nodes
  // visited so far are kept on a stack, and when the walk comes back to one
  // of them, the nodes since then form a ring, which is taken off the stack.
  std::vector<char> used(n_pieces, 0);
  std::vector<Ring> shells;
  std::vector<Ring> holes;
  std::vector<double> shell_area;
  std::vector<int> stack;
  std::vector<int> on_stack(n_nodes, -1);  // position on the stack, or -1
  // add the ring made of the nodes from position `start` of the stack to its
  // end, and take them off the stack (except the first one)
  auto add_ring = [&](std::size_t start) {
    Ring ring;
    for (std::size_t k = start; k < stack.size(); ++k) {
      const int node = nodes.find(pieces[stack[k]].from);
      const double nx = nodes.x(node);
      const double ny = nodes.y(node);
      // two nodes can round to the same coordinates: keep only one vertex
      if (ring.x.empty() || nx != ring.x.back() || ny != ring.y.back()) {
        ring.x.push_back(nx);
        ring.y.push_back(ny);
      }
      if (k > start) {
        on_stack[from[stack[k]]] = -1;
      }
    }
    stack.resize(start + 1);
    while (ring.x.size() > 1 && ring.x.back() == ring.x.front() &&
           ring.y.back() == ring.y.front()) {
      ring.x.pop_back();
      ring.y.pop_back();
    }
    if (ring.x.size() < 3) {
      return false;
    }
    const double area2 = ring_area2(ring.x, ring.y);
    if (area2 > 0.0) {
      shells.push_back(std::move(ring));
      shell_area.push_back(area2);
    } else if (area2 < 0.0) {
      holes.push_back(std::move(ring));
    } else {
      return false;
    }
    return true;
  };
  for (int i = 0; i < n_pieces; ++i) {
    if (used[i]) {
      continue;
    }
    // the stack holds the pieces of the walk, each standing for its first
    // node
    stack.clear();
    int j = i;
    do {
      if (used[j] || next[j] < 0) {
        return false;
      }
      used[j] = 1;
      const int v = from[j];
      if (on_stack[v] >= 0) {
        // back at node v: the pieces since the previous visit form a ring,
        // and the walk carries on from v (with this piece standing for it)
        const std::size_t start = static_cast<std::size_t>(on_stack[v]);
        if (!add_ring(start)) {
          return false;
        }
        stack[start] = j;
      } else {
        on_stack[v] = static_cast<int>(stack.size());
        stack.push_back(j);
      }
      j = next[j];
    } while (j != i);
    // the rest of the walk, back to its first node
    on_stack[from[stack[0]]] = -1;
    if (!add_ring(0)) {
      return false;
    }
  }

  // assign each hole to the smallest shell that contains it (shells can be
  // nested: a shell can be inside a hole of another shell)
  auto bbox = [](const Ring& ring, double* box) {
    box[0] = *std::min_element(ring.x.begin(), ring.x.end());
    box[1] = *std::max_element(ring.x.begin(), ring.x.end());
    box[2] = *std::min_element(ring.y.begin(), ring.y.end());
    box[3] = *std::max_element(ring.y.begin(), ring.y.end());
  };
  const int n_shells = static_cast<int>(shells.size());
  std::vector<double> shell_box(4 * static_cast<std::size_t>(n_shells));
  for (int s = 0; s < n_shells; ++s) {
    bbox(shells[s], &shell_box[4 * static_cast<std::size_t>(s)]);
  }
  std::vector<std::vector<int>> shell_holes(n_shells);
  std::vector<int> candidates;
  for (int h = 0; h < static_cast<int>(holes.size()); ++h) {
    double box[4];
    bbox(holes[h], box);
    candidates.clear();
    for (int s = 0; s < n_shells; ++s) {
      const double* sb = &shell_box[4 * static_cast<std::size_t>(s)];
      if (sb[0] <= box[0] && sb[1] >= box[1] && sb[2] <= box[2] &&
          sb[3] >= box[3]) {
        candidates.push_back(s);
      }
    }
    int best = -1;
    if (candidates.size() == 1) {
      best = candidates[0];
    } else {
      // test the midpoints of two edges of the hole, which cannot lie on the
      // boundary of a shell (the rings only meet at nodes); both must agree
      const Ring& hole = holes[h];
      const std::size_t n = hole.x.size();
      const std::size_t i1 = n / 2;
      const double m0x = (hole.x[0] + hole.x[1]) / 2.0;
      const double m0y = (hole.y[0] + hole.y[1]) / 2.0;
      const double m1x = (hole.x[i1] + hole.x[(i1 + 1) % n]) / 2.0;
      const double m1y = (hole.y[i1] + hole.y[(i1 + 1) % n]) / 2.0;
      for (const int s : candidates) {
        const bool in0 = point_in_ring(m0x, m0y, shells[s].x, shells[s].y);
        const bool in1 = point_in_ring(m1x, m1y, shells[s].x, shells[s].y);
        if (in0 != in1) {
          return false;
        }
        if (in0 && (best < 0 || shell_area[s] < shell_area[best])) {
          best = s;
        }
      }
    }
    if (best < 0) {
      return false;
    }
    shell_holes[best].push_back(h);
  }

  // the polygons, with their rings closed and oriented as GEOS does (shells
  // clockwise, holes anticlockwise): the opposite of the rings found here
  auto closed_reversed = [](Ring ring) {
    std::reverse(ring.x.begin(), ring.x.end());
    std::reverse(ring.y.begin(), ring.y.end());
    ring.x.push_back(ring.x.front());
    ring.y.push_back(ring.y.front());
    return ring;
  };
  out.reserve(n_shells);
  for (int s = 0; s < n_shells; ++s) {
    Polygon polygon;
    polygon.reserve(1 + shell_holes[s].size());
    polygon.push_back(closed_reversed(std::move(shells[s])));
    for (const int h : shell_holes[s]) {
      polygon.push_back(closed_reversed(std::move(holes[h])));
    }
    out.push_back(std::move(polygon));
  }
  return true;
}

// An interval of an edge covered by a polygon, as the positions of its ends
// among the breakpoints of the edge.
struct Interval {
  int lo, hi;
  int polygon;
};

} // namespace

// ---------------------------------------------------------------------------
// 5. The union
// ---------------------------------------------------------------------------

bool union_of_convex_polygons(const std::vector<double>& x,
                              const std::vector<double>& y,
                              const std::vector<std::size_t>& offsets,
                              const std::vector<int>& vertices,
                              const std::vector<int>& counts,
                              std::vector<MultiPolygon>& out) {
  const int n_levels = static_cast<int>(counts.size());
  out.assign(n_levels, MultiPolygon());
  int n_used = 0;
  for (const int count : counts) {
    n_used = std::max(n_used, count);
  }
  if (n_used == 0) {
    return true;
  }
  const double* px = x.data();
  const double* py = y.data();
  auto size_of = [&offsets](int p) {
    return static_cast<int>(offsets[p + 1] - offsets[p]);
  };
  auto vertices_of = [&offsets, &vertices](int p) {
    return &vertices[offsets[p]];
  };

  // the polygons must be strictly convex, anticlockwise
  for (int p = 0; p < n_used; ++p) {
    const int m = size_of(p);
    const int* g = vertices_of(p);
    if (m < 3) {
      return false;
    }
    for (int j = 0; j < m; ++j) {
      const Edge e(px, py, g[j], g[(j + 1) % m]);
      if (e.side(g[(j + 2) % m]) <= 0) {
        return false;
      }
    }
  }

  // bounding boxes of the polygons
  std::vector<double> box(4 * static_cast<std::size_t>(n_used));
  double mean_size = 0.0;
  for (int p = 0; p < n_used; ++p) {
    const int* g = vertices_of(p);
    double* b = &box[4 * static_cast<std::size_t>(p)];
    b[0] = b[1] = px[g[0]];
    b[2] = b[3] = py[g[0]];
    for (int j = 1; j < size_of(p); ++j) {
      b[0] = std::min(b[0], px[g[j]]);
      b[1] = std::max(b[1], px[g[j]]);
      b[2] = std::min(b[2], py[g[j]]);
      b[3] = std::max(b[3], py[g[j]]);
    }
    mean_size += ((b[1] - b[0]) + (b[3] - b[2])) / 2.0;
  }
  mean_size /= n_used;
  // whether two bounding boxes (xmin, xmax, ymin, ymax) overlap (touching
  // counts, as polygons can share an edge along the side of a box)
  auto boxes_overlap = [](const double* b, const double* c) {
    return c[0] <= b[1] && c[1] >= b[0] && c[2] <= b[3] && c[3] >= b[2];
  };

  // a uniform grid over the bounding boxes, to find the polygons that may
  // overlap a given polygon: each polygon is listed in every cell that its
  // bounding box overlaps. Cells are about the size of an average polygon,
  // but not more numerous than a few times the number of polygons.
  double x0 = box[0];
  double x1 = box[1];
  double y0 = box[2];
  double y1 = box[3];
  for (int p = 1; p < n_used; ++p) {
    const double* b = &box[4 * static_cast<std::size_t>(p)];
    x0 = std::min(x0, b[0]);
    x1 = std::max(x1, b[1]);
    y0 = std::min(y0, b[2]);
    y1 = std::max(y1, b[3]);
  }
  double cell = mean_size > 0.0 ? mean_size : 1.0;
  int nx = 1;
  int ny = 1;
  while (true) {
    nx = static_cast<int>(std::min(1e6, (x1 - x0) / cell)) + 1;
    ny = static_cast<int>(std::min(1e6, (y1 - y0) / cell)) + 1;
    if (static_cast<double>(nx) * ny <= 4.0 * n_used + 16.0) {
      break;
    }
    cell *= 1.5;
  }
  auto cell_x = [x0, cell, nx](double v) {
    return std::min(nx - 1, std::max(0, static_cast<int>((v - x0) / cell)));
  };
  auto cell_y = [y0, cell, ny](double v) {
    return std::min(ny - 1, std::max(0, static_cast<int>((v - y0) / cell)));
  };
  // the cells are stored in "compressed sparse row" form (as the neighbour
  // sets in locoh.cpp): first count the polygons in each cell, then list them,
  // with their bounding boxes (so that a cell can be scanned without looking
  // elsewhere in memory)
  struct CellItem {
    double box[4];
    int polygon;
  };
  std::vector<int> cell_start(static_cast<std::size_t>(nx) * ny + 1, 0);
  for (int p = 0; p < n_used; ++p) {
    const double* b = &box[4 * static_cast<std::size_t>(p)];
    for (int i = cell_x(b[0]); i <= cell_x(b[1]); ++i) {
      for (int j = cell_y(b[2]); j <= cell_y(b[3]); ++j) {
        ++cell_start[static_cast<std::size_t>(i) * ny + j + 1];
      }
    }
  }
  for (std::size_t c = 1; c < cell_start.size(); ++c) {
    cell_start[c] += cell_start[c - 1];
  }
  std::vector<CellItem> cell_items(cell_start.back());
  {
    std::vector<int> fill(cell_start.begin(), cell_start.end() - 1);
    for (int p = 0; p < n_used; ++p) {
      const double* b = &box[4 * static_cast<std::size_t>(p)];
      for (int i = cell_x(b[0]); i <= cell_x(b[1]); ++i) {
        for (int j = cell_y(b[2]); j <= cell_y(b[3]); ++j) {
          const std::size_t c = static_cast<std::size_t>(i) * ny + j;
          CellItem& item = cell_items[fill[c]++];
          std::copy(b, b + 4, item.box);
          item.polygon = p;
        }
      }
    }
  }

  Nodes nodes(px, py, x.size());
  std::vector<std::vector<Piece>> pieces(n_levels);

  // scratch space, reused for every polygon and edge
  std::vector<int> candidates;
  std::vector<double> candidate_box;
  std::vector<int> seen(n_used, -1);
  std::vector<int> side;
  std::vector<Breakpoint> breakpoints;
  std::vector<int> sorted;
  std::vector<int> position;
  std::vector<int> group_start;
  std::vector<int> group_node;
  std::vector<Interval> intervals;

  for (int h = 0; h < n_used; ++h) {
    if (h % 1000 == 0) {
      Rcpp::checkUserInterrupt();
    }
    const int m = size_of(h);
    const int* hv = vertices_of(h);
    const double* hb = &box[4 * static_cast<std::size_t>(h)];

    // the polygons whose bounding box overlaps that of this polygon, with
    // their bounding boxes (copied, so that they are next to each other in
    // memory when they are scanned for each edge)
    candidates.clear();
    candidate_box.clear();
    for (int i = cell_x(hb[0]); i <= cell_x(hb[1]); ++i) {
      for (int j = cell_y(hb[2]); j <= cell_y(hb[3]); ++j) {
        const std::size_t c = static_cast<std::size_t>(i) * ny + j;
        for (int k = cell_start[c]; k < cell_start[c + 1]; ++k) {
          const CellItem& item = cell_items[k];
          if (!boxes_overlap(item.box, hb) || item.polygon == h ||
              seen[item.polygon] == h) {
            continue;
          }
          seen[item.polygon] = h;
          candidates.push_back(item.polygon);
          candidate_box.insert(candidate_box.end(), item.box, item.box + 4);
        }
      }
    }
    // the polygons that are in every union that this polygon is in: those
    // that come before the first union (by size) that contains it
    int in_all = n_used;
    for (const int count : counts) {
      if (count > h) {
        in_all = std::min(in_all, count);
      }
    }

    for (int k = 0; k < m; ++k) {
      const int a = hv[k];
      const int b = hv[(k + 1) % m];
      const Edge e(px, py, a, b);
      const double eb[4] = {std::min(px[a], px[b]), std::max(px[a], px[b]),
                            std::min(py[a], py[b]), std::max(py[a], py[b])};

      // the parts of the edge covered by each other polygon; if one of the
      // polygons that are in every union that this one is in covers all of
      // it, the edge is not on the boundary of any union. (`g < h` decides
      // which of two polygons keeps the part of an edge that they share.)
      breakpoints.clear();
      intervals.clear();
      breakpoints.push_back(e.vertex(a));
      breakpoints.push_back(e.vertex(b));
      bool all_covered = false;
      // the polygons that could cover the whole edge (they are in every
      // union, and their bounding box contains the edge) are tried first,
      // then the other polygons whose bounding box overlaps the edge
      for (int pass = 0; pass < 2 && !all_covered; ++pass) {
        for (std::size_t i = 0; i < candidates.size(); ++i) {
          const int g = candidates[i];
          const double* gb = &candidate_box[4 * i];
          const bool may_cover_all = g < in_all && gb[0] <= eb[0] &&
                                     gb[1] >= eb[1] && gb[2] <= eb[2] &&
                                     gb[3] >= eb[3];
          if (may_cover_all != (pass == 0) || !boxes_overlap(gb, eb)) {
            continue;
          }
          Breakpoint lo;
          Breakpoint hi;
          if (!e.covered(vertices_of(g), size_of(g), g < h, side, lo, hi)) {
            continue;
          }
          if (may_cover_all && lo.v == a && hi.v == b) {
            all_covered = true;
            break;
          }
          const int n_breakpoints = static_cast<int>(breakpoints.size());
          intervals.push_back({n_breakpoints, n_breakpoints + 1, g});
          breakpoints.push_back(lo);
          breakpoints.push_back(hi);
        }
      }
      if (all_covered) {
        continue;
      }

      // sort the breakpoints along the edge, and number their positions
      // (breakpoints at the same point share a position)
      const int n_breakpoints = static_cast<int>(breakpoints.size());
      sorted.resize(n_breakpoints);
      std::iota(sorted.begin(), sorted.end(), 0);
      std::sort(sorted.begin(), sorted.end(), [&](int i, int j) {
        return e.compare(breakpoints[i], breakpoints[j]) < 0;
      });
      position.resize(n_breakpoints);
      group_start.clear();
      group_start.push_back(0);
      position[sorted[0]] = 0;
      for (int i = 1; i < n_breakpoints; ++i) {
        if (e.compare(breakpoints[sorted[i - 1]], breakpoints[sorted[i]]) <
            0) {
          group_start.push_back(i);
        }
        position[sorted[i]] = static_cast<int>(group_start.size()) - 1;
      }
      const int n_positions = static_cast<int>(group_start.size());
      group_start.push_back(n_breakpoints);
      group_node.assign(n_positions, -1);
      for (Interval& interval : intervals) {
        interval.lo = position[interval.lo];
        interval.hi = position[interval.hi];
      }
      std::sort(intervals.begin(), intervals.end(),
                [](const Interval& i, const Interval& j) {
                  return i.lo < j.lo;
                });

      // the node at a position: the breakpoints there are the same point,
      // so their nodes are merged
      auto node_at = [&](int pos) {
        if (group_node[pos] < 0) {
          int node = -1;
          for (int i = group_start[pos]; i < group_start[pos + 1]; ++i) {
            const Breakpoint& p = breakpoints[sorted[i]];
            const int id =
              p.v >= 0 ? nodes.vertex(p.v) : nodes.crossing(a, b, p.g1, p.g2);
            if (node < 0) {
              node = id;
            } else {
              nodes.merge(node, id);
            }
          }
          group_node[pos] = node;
        }
        return group_node[pos];
      };

      // the pieces of the edge on the boundary of each union that contains
      // this polygon: the parts not covered by the polygons in that union
      // (an interval of zero length, where a polygon touches the edge, splits
      // the piece that it falls in)
      for (int l = 0; l < n_levels; ++l) {
        if (h >= counts[l]) {
          continue;
        }
        int current = 0;
        for (const Interval& interval : intervals) {
          if (interval.polygon >= counts[l]) {
            continue;
          }
          if (interval.lo > current) {
            pieces[l].push_back(
              {node_at(current), node_at(interval.lo), a, b});
          }
          current = std::max(current, interval.hi);
        }
        if (current < n_positions - 1) {
          pieces[l].push_back(
            {node_at(current), node_at(n_positions - 1), a, b});
        }
      }
    }
  }

  // link the pieces of each union into polygons
  nodes.finish();
  for (int l = 0; l < n_levels; ++l) {
    if (!assemble(pieces[l], nodes, px, py, out[l])) {
      return false;
    }
  }
  return true;
}

} // namespace convex_union
