// Local Convex Hull (LoCoH) home range estimation: the computational core.
//
// LoCoH (Getz & Wilmers 2004; Getz et al. 2007) builds one convex hull per
// location, from that location (the "root") and a set of its neighbours.
// The hulls are then sorted from the smallest to the largest area, and the
// isopleth for a given level is the union of the smallest hulls that, between
// them, contain the requested proportion of the locations.
//
// This file does everything except the final union of the hulls, which is
// left to GEOS (via the `sf` package) on the R side:
//   1. a 2-d k-d tree for fast neighbour queries (k nearest neighbours, and
//      all neighbours within a distance);
//   2. the neighbour set of each root, for the three flavours of LoCoH:
//      - "k": the root and its `n` nearest neighbours;
//      - "r": all locations within distance `n` of the root;
//      - "a": the locations closest to the root whose distances to the root
//        sum to at most `n` (the "adaptive" LoCoH), found with a nearest
//        neighbour search that is widened until the set is complete;
//   3. the convex hull of each neighbour set (Andrew's monotone chain), with
//      its area and perimeter;
//   4. the ordering of the hulls by area, the cumulative proportion of
//      locations covered as hulls are added, and the number of hulls needed
//      for each requested level.
//
// The rules follow the implementation of `amt::hr_locoh()`, so that the two
// give the same isopleths:
//   - "k" uses `n` neighbours in addition to the root (`adehabitatHR` uses
//     `k - 1` neighbours instead);
//   - distances are compared as `sqrt(dx^2 + dy^2) <= n`, exactly as in R;
//   - the cumulative sum of distances for "a" is accumulated in long double,
//     as R's `cumsum()` does;
//   - hulls with the same area keep the order of their roots (as R's
//     `order()` does), and the level is matched to the number of hulls whose
//     coverage is closest to it (as `which.min(abs(coverage - level))`).

#include <Rcpp.h>

#include <algorithm>
#include <cmath>
#include <queue>
#include <string>
#include <utility>
#include <vector>

namespace {

// ---------------------------------------------------------------------------
// 1. A static 2-d k-d tree
// ---------------------------------------------------------------------------
//
// The tree never changes after it is built, so it is stored as a flat vector
// of nodes over a permutation of the point indices: each node owns a
// contiguous range [lo, hi) of that permutation. Each node also stores the
// bounding box of its points, which gives a tight lower bound on the distance
// from a query to any point in the node, and lets whole nodes be skipped.
class KdTree {
public:
  // Build the tree over the points (x[i], y[i]), i = 0, ..., n - 1. The
  // coordinates are not copied, so they must outlive the tree.
  KdTree(const double* x, const double* y, int n) : x_(x), y_(y), idx_(n) {
    // start from the identity permutation; building the tree reorders it
    for (int i = 0; i < n; ++i) {
      idx_[i] = i;
    }
    // a balanced tree with leaves of up to kLeafSize points has about
    // 2 * n / kLeafSize nodes; reserve that to avoid reallocations
    nodes_.reserve(2 * static_cast<std::size_t>(n) / kLeafSize + 2);
    if (n > 0) {
      build(0, n);
    }
  }

  // Find the `k` nearest neighbours of the query point (qx, qy), ignoring the
  // point with index `exclude` (the root itself; use -1 to keep all points).
  // On return, `out` holds the indices of the neighbours, sorted by distance
  // and, for equal distances, by index (so that the result does not depend
  // on how the tree was built).
  void knn(double qx, double qy, int k, int exclude,
           std::vector<int>& out) const {
    out.clear();
    if (k <= 0 || nodes_.empty()) {
      return;
    }
    // max-heap of (squared distance, index): the top is the worst of the
    // best candidates found so far, i.e. the one to drop when a better
    // candidate turns up; pairs compare by distance first, then by index
    std::priority_queue<std::pair<double, int>> heap;
    knn_search(0, qx, qy, static_cast<std::size_t>(k), exclude, heap);
    // pop the heap from the worst to the best candidate, filling `out` back
    // to front so that it ends up sorted from the nearest to the farthest
    out.resize(heap.size());
    for (std::size_t i = heap.size(); i > 0; --i) {
      out[i - 1] = heap.top().second;
      heap.pop();
    }
  }

  // Find all points within distance `r` of the query point (qx, qy),
  // including the query point itself if it is one of the points. Points are
  // kept when sqrt(dx^2 + dy^2) <= r, the same test as amt (testing squared
  // distances instead could disagree for points exactly on the boundary).
  // The indices are returned in no particular order.
  void within(double qx, double qy, double r, std::vector<int>& out) const {
    out.clear();
    if (nodes_.empty()) {
      return;
    }
    within_search(0, qx, qy, r, out);
  }

  // Squared distance between the query point (qx, qy) and the point `i`.
  // dx and dy are computed as (point - query), as amt does in R, so that the
  // results match bit for bit.
  double dist2(int i, double qx, double qy) const {
    const double dx = x_[i] - qx;
    const double dy = y_[i] - qy;
    return dx * dx + dy * dy;
  }

private:
  // Nodes with at most this many points are not split any further: scanning
  // a few points linearly is faster than descending more levels of the tree.
  static constexpr int kLeafSize = 12;

  struct Node {
    int lo, hi;                     // range of idx_ owned by the node
    int left, right;                // children (-1 for a leaf)
    double xmin, xmax, ymin, ymax;  // bounding box of the node's points
  };

  const double* x_;
  const double* y_;
  std::vector<int> idx_;    // permutation of the point indices
  std::vector<Node> nodes_; // nodes_[0] is the root of the tree

  // Recursively build the node owning idx_[lo, hi) and return its position
  // in nodes_.
  int build(int lo, int hi) {
    Node node;
    node.lo = lo;
    node.hi = hi;
    node.left = -1;
    node.right = -1;
    // compute the bounding box of the points in the node
    node.xmin = node.xmax = x_[idx_[lo]];
    node.ymin = node.ymax = y_[idx_[lo]];
    for (int j = lo + 1; j < hi; ++j) {
      const int i = idx_[j];
      node.xmin = std::min(node.xmin, x_[i]);
      node.xmax = std::max(node.xmax, x_[i]);
      node.ymin = std::min(node.ymin, y_[i]);
      node.ymax = std::max(node.ymax, y_[i]);
    }
    // store the node now (its children are filled in below); note that we
    // must refer to it by position, since push_back can move the vector
    const int id = static_cast<int>(nodes_.size());
    nodes_.push_back(node);
    if (hi - lo > kLeafSize) {
      // split along the axis in which the points are most spread out, at
      // the median point, so that the two halves have the same size;
      // std::nth_element puts the median in place in linear time, with the
      // smaller points before it and the larger ones after it
      const bool split_x = (node.xmax - node.xmin) >= (node.ymax - node.ymin);
      const double* coord = split_x ? x_ : y_;
      const int mid = lo + (hi - lo) / 2;
      std::nth_element(
        idx_.begin() + lo, idx_.begin() + mid, idx_.begin() + hi,
        [coord](int a, int b) { return coord[a] < coord[b]; });
      const int left = build(lo, mid);
      const int right = build(mid, hi);
      nodes_[id].left = left;
      nodes_[id].right = right;
    }
    return id;
  }

  // Squared distance from the query point to the nearest point of a node's
  // bounding box (0 if the query is inside the box). Since rounding is
  // monotonic, this is never larger than the squared distance computed (by
  // dist2()) for any point in the box, so it is safe to use for pruning.
  static double box_dist2(const Node& node, double qx, double qy) {
    double dx = 0.0;
    double dy = 0.0;
    if (qx < node.xmin) {
      dx = node.xmin - qx;
    } else if (qx > node.xmax) {
      dx = qx - node.xmax;
    }
    if (qy < node.ymin) {
      dy = node.ymin - qy;
    } else if (qy > node.ymax) {
      dy = qy - node.ymax;
    }
    return dx * dx + dy * dy;
  }

  void knn_search(int id, double qx, double qy, std::size_t k, int exclude,
                  std::priority_queue<std::pair<double, int>>& heap) const {
    const Node& node = nodes_[id];
    // skip the node if it cannot hold a better candidate than the worst one
    // kept so far; the comparison is strict because a point at exactly that
    // distance may still win the tie with a smaller index
    if (heap.size() == k && box_dist2(node, qx, qy) > heap.top().first) {
      return;
    }
    if (node.left < 0) {
      // leaf: try every point in it
      for (int j = node.lo; j < node.hi; ++j) {
        const int i = idx_[j];
        if (i == exclude) {
          continue;
        }
        const std::pair<double, int> cand(dist2(i, qx, qy), i);
        if (heap.size() < k) {
          heap.push(cand);
        } else if (cand < heap.top()) {
          // better than the current worst: replace it
          heap.pop();
          heap.push(cand);
        }
      }
      return;
    }
    // inner node: visit the child closer to the query first, as it is the
    // more likely to hold the neighbours; this shrinks the search radius
    // early, so the other child is more often skipped altogether
    const double d_left = box_dist2(nodes_[node.left], qx, qy);
    const double d_right = box_dist2(nodes_[node.right], qx, qy);
    if (d_left <= d_right) {
      knn_search(node.left, qx, qy, k, exclude, heap);
      knn_search(node.right, qx, qy, k, exclude, heap);
    } else {
      knn_search(node.right, qx, qy, k, exclude, heap);
      knn_search(node.left, qx, qy, k, exclude, heap);
    }
  }

  void within_search(int id, double qx, double qy, double r,
                     std::vector<int>& out) const {
    const Node& node = nodes_[id];
    // skip the node if even its nearest corner is farther than r; the test
    // on the square root mirrors the test applied to the points below
    if (std::sqrt(box_dist2(node, qx, qy)) > r) {
      return;
    }
    if (node.left < 0) {
      // leaf: keep the points within distance r
      for (int j = node.lo; j < node.hi; ++j) {
        const int i = idx_[j];
        if (std::sqrt(dist2(i, qx, qy)) <= r) {
          out.push_back(i);
        }
      }
      return;
    }
    within_search(node.left, qx, qy, r, out);
    within_search(node.right, qx, qy, r, out);
  }
};

// ---------------------------------------------------------------------------
// 2. Neighbour sets
// ---------------------------------------------------------------------------
//
// The neighbour sets of all roots are stored in "compressed sparse row"
// form: the members of the set of root i are
// members[offsets[i]], ..., members[offsets[i + 1] - 1]. This avoids
// allocating one vector per root.
struct NeighbourSets {
  std::vector<std::size_t> offsets;
  std::vector<int> members;
};

// For the adaptive LoCoH ("a"), the number of nearest neighbours searched
// first; it is doubled for as long as needed (see find_neighbours()). Sets
// usually hold no more than a few tens of locations, so this is small.
constexpr int kInitialK = 16;

// Compute the neighbour set of every root. Each set includes the root itself.
NeighbourSets find_neighbours(const double* x, const double* y, int n_pts,
                              const std::string& type, double n) {
  const KdTree tree(x, y, n_pts);
  NeighbourSets sets;
  sets.offsets.reserve(static_cast<std::size_t>(n_pts) + 1);
  sets.offsets.push_back(0);
  if (type == "k") {
    // every set has the root plus k neighbours, so the size is known
    sets.members.reserve(static_cast<std::size_t>(n_pts) *
                         (static_cast<std::size_t>(n) + 1));
  }
  // scratch vectors, reused for every root to avoid reallocations
  std::vector<int> nb;
  std::vector<std::pair<double, int>> by_dist;

  for (int i = 0; i < n_pts; ++i) {
    // let the user interrupt long computations (checking every point would
    // be wasteful, as the check itself takes time)
    if (i % 1000 == 0) {
      Rcpp::checkUserInterrupt();
    }
    if (type == "k") {
      // the root and its n nearest neighbours (excluding the root itself,
      // but including any other location with the same coordinates)
      tree.knn(x[i], y[i], static_cast<int>(n), i, nb);
      sets.members.push_back(i);
      sets.members.insert(sets.members.end(), nb.begin(), nb.end());
    } else if (type == "r") {
      // all locations within distance n of the root (the root included,
      // as it is at distance 0)
      tree.within(x[i], y[i], n, nb);
      sets.members.insert(sets.members.end(), nb.begin(), nb.end());
    } else {
      // type "a": take locations from the nearest to the farthest while the
      // sum of their distances to the root is at most n.
      //
      // All such locations are within distance n of the root, but in dense
      // data there can be thousands of locations within that distance and
      // only a handful in the set. So, rather than sorting every location
      // within distance n, we search for the k nearest locations, and double
      // k until the set is known to be complete.
      int k = std::min(n_pts, kInitialK);
      std::size_t m = 0;  // number of locations in the set
      while (true) {
        // the k nearest locations, the root included (at distance 0)
        tree.knn(x[i], y[i], k, -1, nb);
        // sort them by distance, breaking ties by index as R's order() does
        // (they come sorted by squared distance, but two squared distances
        // can round to the same distance, so sort again)
        by_dist.clear();
        for (int j : nb) {
          by_dist.emplace_back(std::sqrt(tree.dist2(j, x[i], y[i])), j);
        }
        std::sort(by_dist.begin(), by_dist.end());
        // accumulate in long double, as R's cumsum() does, and round each
        // partial sum to double before comparing it, as R does when it
        // stores the result of cumsum(); distances are non-negative, so the
        // partial sums never decrease and we can stop at the first one above
        // n: the set is then by_dist[0], ..., by_dist[m - 1]
        long double cum = 0.0L;
        for (m = 0; m < by_dist.size(); ++m) {
          cum += by_dist[m].first;
          if (static_cast<double>(cum) > n) {
            break;
          }
        }
        // The set is complete if we searched all locations, or if the first
        // location left out (by_dist[m]) is strictly closer than the
        // farthest location found: any location not found is at least as
        // far as the farthest one found, so it would come after by_dist[m]
        // and be left out too. Otherwise (all locations found are in the
        // set, or the first left out ties with the farthest one, so a
        // location not found could come before it), search more widely.
        if (k == n_pts ||
            (m < by_dist.size() && by_dist[m].first < by_dist.back().first)) {
          break;
        }
        k = std::min(n_pts, 2 * k);
      }
      for (std::size_t j = 0; j < m; ++j) {
        sets.members.push_back(by_dist[j].second);
      }
    }
    sets.offsets.push_back(sets.members.size());
  }
  return sets;
}

// ---------------------------------------------------------------------------
// 3. Convex hulls
// ---------------------------------------------------------------------------

struct Point {
  double x, y;
  // lexicographic order (by x, then y), needed by the monotone chain
  bool operator<(const Point& o) const {
    return x < o.x || (x == o.x && y < o.y);
  }
  bool operator==(const Point& o) const { return x == o.x && y == o.y; }
};

// Twice the signed area of the triangle (o, a, b): positive if o -> a -> b
// turns counter-clockwise, negative if clockwise, zero if collinear.
inline double cross(const Point& o, const Point& a, const Point& b) {
  return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
}

// Convex hull of a set of points with Andrew's monotone chain algorithm,
// O(m log m) for m points. The hull is returned in counter-clockwise order
// (the orientation of exterior rings in simple features), without repeating
// the first vertex and without collinear vertices (as GEOS does). Degenerate
// sets give fewer than 3 vertices: 1 if all points coincide, 2 (the two
// extremes) if they are all on a line.
std::vector<Point> convex_hull(std::vector<Point> pts) {
  // sort the points and drop duplicates, which would otherwise create
  // zero-length edges
  std::sort(pts.begin(), pts.end());
  pts.erase(std::unique(pts.begin(), pts.end()), pts.end());
  const std::size_t m = pts.size();
  if (m < 3) {
    return pts;
  }
  std::vector<Point> hull(2 * m);
  std::size_t h = 0;
  // lower hull: sweep from left to right, popping the last vertex while it
  // does not make a strict counter-clockwise (left) turn
  for (std::size_t i = 0; i < m; ++i) {
    while (h >= 2 && cross(hull[h - 2], hull[h - 1], pts[i]) <= 0) {
      --h;
    }
    hull[h++] = pts[i];
  }
  // upper hull: sweep back from right to left, in the same way; `lower`
  // stops the popping from eating into the lower hull
  const std::size_t lower = h + 1;
  for (std::size_t i = m - 1; i > 0; --i) {
    while (h >= lower && cross(hull[h - 2], hull[h - 1], pts[i - 1]) <= 0) {
      --h;
    }
    hull[h++] = pts[i - 1];
  }
  // the last vertex is the first one again (the leftmost point); drop it
  hull.resize(h - 1);
  return hull;
}

// Area (by the shoelace formula) and perimeter of a convex polygon given by
// its vertices in counter-clockwise order. A segment (2 vertices) has area 0
// and a perimeter of twice its length (it is a polygon that goes there and
// back again), and a single point has area and perimeter 0.
void area_perimeter(const std::vector<Point>& hull, double& area,
                    double& perimeter) {
  area = 0.0;
  perimeter = 0.0;
  const std::size_t m = hull.size();
  if (m < 2) {
    return;
  }
  for (std::size_t i = 0; i < m; ++i) {
    const Point& a = hull[i];
    const Point& b = hull[(i + 1) % m];  // wrap around to close the ring
    area += a.x * b.y - b.x * a.y;
    perimeter += std::hypot(b.x - a.x, b.y - a.y);
  }
  area = std::fabs(area) / 2.0;
}

// Turn a hull into an `sf` geometry (an `sfg` object): a POLYGON, or, for
// degenerate hulls, a LINESTRING or a POINT. Polygon rings must be closed,
// so the first vertex is repeated at the end. The coordinates are shifted by
// (-shift_x, -shift_y) (see locoh_cpp() for why).
SEXP hull_to_sfg(const std::vector<Point>& hull, double shift_x,
                 double shift_y) {
  const int m = static_cast<int>(hull.size());
  if (m == 1) {
    Rcpp::NumericVector pt = Rcpp::NumericVector::create(hull[0].x - shift_x,
                                                         hull[0].y - shift_y);
    pt.attr("class") = Rcpp::CharacterVector::create("XY", "POINT", "sfg");
    return pt;
  }
  if (m == 2) {
    Rcpp::NumericMatrix line(2, 2);
    for (int i = 0; i < 2; ++i) {
      line(i, 0) = hull[i].x - shift_x;
      line(i, 1) = hull[i].y - shift_y;
    }
    line.attr("class") =
      Rcpp::CharacterVector::create("XY", "LINESTRING", "sfg");
    return line;
  }
  // an R matrix is stored by column: x coordinates first, then y
  Rcpp::NumericMatrix ring(m + 1, 2);
  for (int i = 0; i <= m; ++i) {
    const Point& p = hull[i % m];  // i == m closes the ring
    ring(i, 0) = p.x - shift_x;
    ring(i, 1) = p.y - shift_y;
  }
  Rcpp::List polygon = Rcpp::List::create(ring);
  polygon.attr("class") = Rcpp::CharacterVector::create("XY", "POLYGON", "sfg");
  return polygon;
}

// Check the inputs shared by the exported functions.
void check_inputs(const Rcpp::NumericVector& x, const Rcpp::NumericVector& y,
                  const std::string& type, double n) {
  if (x.size() != y.size()) {
    Rcpp::stop("x and y must have the same length");
  }
  for (R_xlen_t i = 0; i < x.size(); ++i) {
    if (!std::isfinite(x[i]) || !std::isfinite(y[i])) {
      Rcpp::stop("coordinates must be finite");
    }
  }
  if (type != "k" && type != "r" && type != "a") {
    Rcpp::stop("type must be one of \"k\", \"r\" or \"a\"");
  }
  if (!std::isfinite(n) || n <= 0) {
    Rcpp::stop("n must be a positive number");
  }
  if (type == "k" && (n != std::floor(n) || n >= x.size())) {
    Rcpp::stop("for type \"k\", n must be a whole number smaller than the "
               "number of locations");
  }
}

} // namespace

// ---------------------------------------------------------------------------
// 4. Exported functions
// ---------------------------------------------------------------------------

//' Neighbour sets used by LoCoH
//'
//' Internal function, exported for testing: returns the neighbour set of
//' each location, as used to build its local convex hull.
//'
//' @param x,y numeric vectors of coordinates.
//' @param type the type of LoCoH: `"k"`, `"r"` or `"a"`.
//' @param n the parameter of the LoCoH (number of neighbours for `"k"`,
//'   radius for `"r"`, maximum sum of distances for `"a"`).
//' @returns A list with one integer vector (of 1-based indices) per location.
//'   For `"k"`, the root comes first and is followed by its neighbours, from
//'   the nearest to the farthest; for `"r"`, the order is arbitrary; for
//'   `"a"`, locations are sorted by their distance to the root.
//' @keywords internal
//' @noRd
// [[Rcpp::export]]
Rcpp::List locoh_neighbours_cpp(Rcpp::NumericVector x, Rcpp::NumericVector y,
                                std::string type, double n) {
  check_inputs(x, y, type, n);
  const int n_pts = static_cast<int>(x.size());
  const NeighbourSets sets = find_neighbours(x.begin(), y.begin(), n_pts,
                                             type, n);
  Rcpp::List out(n_pts);
  for (int i = 0; i < n_pts; ++i) {
    Rcpp::IntegerVector v(sets.members.begin() + sets.offsets[i],
                          sets.members.begin() + sets.offsets[i + 1]);
    // convert to R's 1-based indices
    for (R_xlen_t j = 0; j < v.size(); ++j) {
      v[j] += 1;
    }
    out[i] = v;
  }
  return out;
}

//' Local convex hulls, sorted by area, and the hulls needed for each level
//'
//' This internal function does the heavy lifting for [hr_tt_locoh()]: it
//' finds the neighbours of each location, builds the local convex hulls,
//' sorts them by area and works out how many of the smallest hulls are
//' needed to cover each level. The union of those hulls (the isopleth) is
//' computed in R.
//'
//' @param x,y numeric vectors of coordinates.
//' @param type the type of LoCoH: `"k"`, `"r"` or `"a"`.
//' @param n the parameter of the LoCoH (number of neighbours for `"k"`,
//'   radius for `"r"`, maximum sum of distances for `"a"`).
//' @param levels numeric vector of levels (proportions of locations).
//' @param buffer the distance by which hulls will be buffered; hulls are
//'   sorted by their area after buffering.
//' @param shift_x,shift_y the hulls are returned in coordinates relative to
//'   this point. All the computations are done in the original coordinates
//'   (so that they match amt exactly); only the returned hulls are shifted.
//'   GEOS, which computes the union of the hulls, loses precision with large
//'   coordinates (e.g. projected coordinates in the millions): small
//'   details, such as a buffer of 1e-5, are then distorted.
//' @returns A list with:
//' - `n_hulls`: for each level, the number of (smallest) hulls whose union
//'   is the isopleth;
//' - `coverage`: for each level, the proportion of locations in those hulls;
//' - `hulls`: the `max(n_hulls)` smallest hulls, from the smallest to the
//'   largest, as a list of `sfg` objects (POLYGON, or LINESTRING or POINT
//'   for degenerate hulls with no area), in shifted coordinates;
//' - `degenerate`: a logical vector, `TRUE` for the hulls with no area;
//' - `root`: the (1-based) index of the root location of each hull.
//' @keywords internal
//' @noRd
// [[Rcpp::export]]
Rcpp::List locoh_cpp(Rcpp::NumericVector x, Rcpp::NumericVector y,
                     std::string type, double n, Rcpp::NumericVector levels,
                     double buffer, double shift_x, double shift_y) {
  check_inputs(x, y, type, n);
  if (!std::isfinite(buffer) || buffer < 0) {
    Rcpp::stop("buffer must be a non-negative number");
  }
  const int n_pts = static_cast<int>(x.size());
  const double* px = x.begin();
  const double* py = y.begin();

  // --- neighbour sets ------------------------------------------------------
  const NeighbourSets sets = find_neighbours(px, py, n_pts, type, n);

  // --- one convex hull per root --------------------------------------------
  std::vector<std::vector<Point>> hulls(n_pts);
  // the key used to sort the hulls (see below)
  std::vector<double> key(n_pts);
  std::vector<Point> pts;  // scratch vector, reused for every root
  for (int i = 0; i < n_pts; ++i) {
    if (i % 1000 == 0) {
      Rcpp::checkUserInterrupt();
    }
    // gather the coordinates of the neighbour set of root i
    pts.clear();
    for (std::size_t j = sets.offsets[i]; j < sets.offsets[i + 1]; ++j) {
      const int k = sets.members[j];
      pts.push_back(Point{px[k], py[k]});
    }
    hulls[i] = convex_hull(pts);
    double area = 0.0;
    double perimeter = 0.0;
    area_perimeter(hulls[i], area, perimeter);
    // amt buffers every hull before measuring its area. For a convex
    // polygon, the area after buffering by b is exactly (Steiner formula)
    //   area + perimeter * b + pi * b^2,
    // so we can get the same ordering without buffering anything. The
    // pi * b^2 term is the same for all hulls and is left out. With b > 0,
    // this also orders degenerate hulls sensibly: points before segments,
    // and short segments before long ones.
    key[i] = area + perimeter * buffer;
  }

  // --- sort the hulls by area ----------------------------------------------
  // `order` holds the roots, from the smallest hull to the largest one; a
  // stable sort keeps roots with equal areas in their original order, as
  // R's order() does
  std::vector<int> order(n_pts);
  for (int i = 0; i < n_pts; ++i) {
    order[i] = i;
  }
  std::stable_sort(order.begin(), order.end(),
                   [&key](int a, int b) { return key[a] < key[b]; });

  // --- cumulative proportion of locations covered --------------------------
  // coverage[j] is the proportion of locations that belong to (the
  // neighbour set of) at least one of the j + 1 smallest hulls. Locations
  // count once, however many hulls they belong to.
  std::vector<char> seen(n_pts, 0);
  std::vector<double> coverage(n_pts);
  int n_seen = 0;
  for (int j = 0; j < n_pts; ++j) {
    const int root = order[j];
    for (std::size_t m = sets.offsets[root]; m < sets.offsets[root + 1];
         ++m) {
      const int k = sets.members[m];
      if (!seen[k]) {
        seen[k] = 1;
        ++n_seen;
      }
    }
    coverage[j] = static_cast<double>(n_seen) / n_pts;
  }

  // --- number of hulls for each level --------------------------------------
  // the isopleth for a level is the union of the j smallest hulls, where j
  // gives the coverage closest to the level (the first such j if there are
  // ties, i.e. the smallest isopleth)
  const R_xlen_t n_levels = levels.size();
  Rcpp::IntegerVector n_hulls(n_levels);
  Rcpp::NumericVector level_coverage(n_levels);
  int max_hulls = 0;
  for (R_xlen_t l = 0; l < n_levels; ++l) {
    int best = 0;
    for (int j = 1; j < n_pts; ++j) {
      // strict comparison, to keep the first of equally good candidates
      if (std::fabs(coverage[j] - levels[l]) <
          std::fabs(coverage[best] - levels[l])) {
        best = j;
      }
    }
    n_hulls[l] = best + 1;
    level_coverage[l] = coverage[best];
    max_hulls = std::max(max_hulls, best + 1);
  }

  // --- return the hulls needed by the largest isopleth ---------------------
  // only the max_hulls smallest hulls take part in any isopleth, so the
  // other hulls are not converted to R objects
  Rcpp::List hull_sfg(max_hulls);
  Rcpp::LogicalVector degenerate(max_hulls);
  Rcpp::IntegerVector root(max_hulls);
  for (int j = 0; j < max_hulls; ++j) {
    const std::vector<Point>& hull = hulls[order[j]];
    hull_sfg[j] = hull_to_sfg(hull, shift_x, shift_y);
    degenerate[j] = hull.size() < 3;
    root[j] = order[j] + 1;  // 1-based index for R
  }

  return Rcpp::List::create(
    Rcpp::Named("n_hulls") = n_hulls,
    Rcpp::Named("coverage") = level_coverage,
    Rcpp::Named("hulls") = hull_sfg,
    Rcpp::Named("degenerate") = degenerate,
    Rcpp::Named("root") = root);
}

//' Convex hull of a set of points
//'
//' Internal function, exported for testing the convex hull code used by
//' LoCoH.
//'
//' @param x,y numeric vectors of coordinates.
//' @returns A two-column matrix with the vertices of the hull, in
//'   counter-clockwise order, with the first vertex not repeated.
//' @keywords internal
//' @noRd
// [[Rcpp::export]]
Rcpp::NumericMatrix convex_hull_cpp(Rcpp::NumericVector x,
                                    Rcpp::NumericVector y) {
  if (x.size() != y.size()) {
    Rcpp::stop("x and y must have the same length");
  }
  std::vector<Point> pts;
  pts.reserve(x.size());
  for (R_xlen_t i = 0; i < x.size(); ++i) {
    pts.push_back(Point{x[i], y[i]});
  }
  const std::vector<Point> hull = convex_hull(pts);
  Rcpp::NumericMatrix out(static_cast<int>(hull.size()), 2);
  for (std::size_t i = 0; i < hull.size(); ++i) {
    out(static_cast<int>(i), 0) = hull[i].x;
    out(static_cast<int>(i), 1) = hull[i].y;
  }
  return out;
}
