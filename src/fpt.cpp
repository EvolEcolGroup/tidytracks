// First passage time (FPT): the time that an animal takes to cross a circle of
// a given radius centred on each of its locations (Fauchald & Tveraa 2003).
//
// This is the definition of adehabitatLT::fpt(). The difference is in the
// search for the first location outside each circle: adehabitatLT restarts it
// from the centre of the circle for each radius, whilst here, as a larger
// circle cannot be left before a smaller one, it carries on from where the
// previous radius stopped. The search also skips, in one step, whole blocks
// of locations that lie inside the circle (see BlockBoxes), which gives the
// same results as checking each location.

#include <Rcpp.h>

#include <algorithm>
#include <cmath>
#include <vector>

// Bounding boxes of aligned blocks of consecutive locations, at several
// levels: blocks of 16 locations, of 256, of 4096, and so on, as long as a
// block holds fewer locations than the track. Without them, the search for
// the crossing of a circle checks every location until the track leaves the
// circle, which costs time proportional to the length of the track for each
// location when the track stays long within the circle (e.g. a long rest, or
// a circle as large as the whole track, which is never left): the FPT of a
// whole track then takes time proportional to the square of its length. A
// block whose bounding box lies inside the circle cannot hold the crossing,
// so the search skips it in one step.
struct BlockBoxes {
  // log2 of the number of locations per block, at each level (4, 8, 12, ...)
  std::vector<int> shift;
  // the bounding box of each block, at each level
  std::vector<std::vector<double>> x_min, x_max, y_min, y_max;
};

static BlockBoxes make_block_boxes(const double *x, const double *y, int n) {
  BlockBoxes boxes;
  // blocks of 16^level locations: 16 keeps the boxes tight at the lowest
  // level, whilst the number of levels grows only with the log of n
  for (int shift = 4; shift < 31 && (1L << shift) < n; shift += 4) {
    const int n_blocks = static_cast<int>(((n - 1L) >> shift) + 1);
    std::vector<double> x_min(n_blocks, R_PosInf), x_max(n_blocks, R_NegInf);
    std::vector<double> y_min(n_blocks, R_PosInf), y_max(n_blocks, R_NegInf);
    for (int j = 0; j < n; ++j) {
      const int b = j >> shift;
      x_min[b] = std::min(x_min[b], x[j]);
      x_max[b] = std::max(x_max[b], x[j]);
      y_min[b] = std::min(y_min[b], y[j]);
      y_max[b] = std::max(y_max[b], y[j]);
    }
    boxes.shift.push_back(shift);
    boxes.x_min.push_back(x_min);
    boxes.x_max.push_back(x_max);
    boxes.y_min.push_back(y_min);
    boxes.y_max.push_back(y_max);
  }
  return boxes;
}

// Whether all the locations of block b at a level are closer than the radius
// to (xi, yi), i.e. whether the corner of its bounding box farthest from
// (xi, yi) is. The distance to the corner is computed in the same way as that
// to a location, and rounding is monotonic, so no location of the block can
// have a larger computed distance; the bound `inside_sq` is also a little
// smaller than the squared radius, in case the compiler contracts one of the
// two expressions into a fused multiply-add.
static inline bool block_inside(const BlockBoxes &boxes, int level, int b,
                                double xi, double yi, double inside_sq) {
  const double dx = std::max(std::fabs(boxes.x_min[level][b] - xi),
                             std::fabs(boxes.x_max[level][b] - xi));
  const double dy = std::max(std::fabs(boxes.y_min[level][b] - yi),
                             std::fabs(boxes.y_max[level][b] - yi));
  return dx * dx + dy * dy < inside_sq;
}

// The time from location i to the crossing of each circle centred on it,
// walking along the track in steps of `dir` (1 forwards, -1 backwards). The
// crossing is found by linear interpolation between the last location inside
// the circle and the first one outside it. Radii must be in increasing order;
// circles that the track does not leave get NA.
static void time_to_crossing(const double *x, const double *y, const double *t,
                             int n, int i, int dir, const double *radii,
                             int n_radii, const BlockBoxes &boxes,
                             double *out) {
  const int n_levels = boxes.shift.size();
  int pos = i + dir;
  for (int k = 0; k < n_radii; ++k) {
    const double radius_sq = radii[k] * radii[k];
    const double inside_sq = radius_sq * (1.0 - 1e-12);
    double dist_sq = 0.0;
    while (pos >= 0 && pos < n) {
      // a block can be skipped if pos is its first location (forwards) or its
      // last (backwards); `edge` is then a multiple of the block size
      const int edge = dir == 1 ? pos : pos + 1;
      if (n_levels > 0 && (edge & 15) == 0) {
        // try the largest block first
        bool skipped = false;
        for (int level = n_levels - 1; level >= 0; --level) {
          const int shift = boxes.shift[level];
          if ((edge & ((1 << shift) - 1)) == 0 &&
              block_inside(boxes, level, pos >> shift, x[i], y[i],
                           inside_sq)) {
            pos += dir * (1 << shift);
            skipped = true;
            break;
          }
        }
        if (skipped) {
          continue;
        }
      }
      const double dx = x[pos] - x[i];
      const double dy = y[pos] - y[i];
      dist_sq = dx * dx + dy * dy;
      if (dist_sq >= radius_sq) {
        break;
      }
      pos += dir;
    }
    if (pos < 0 || pos >= n) {
      // the track never leaves this circle, nor any larger one
      for (; k < n_radii; ++k) {
        out[k] = NA_REAL;
      }
      return;
    }
    const int prev = pos - dir;
    const double dx = x[prev] - x[i];
    const double dy = y[prev] - y[i];
    const double dist = std::sqrt(dist_sq);
    const double dist_prev = std::sqrt(dx * dx + dy * dy);
    const double time = std::fabs(t[pos] - t[i]);
    const double time_prev = std::fabs(t[prev] - t[i]);
    out[k] = time_prev +
             (time - time_prev) * (radii[k] - dist_prev) / (dist - dist_prev);
  }
}

//' First passage time of the locations of one track
//'
//' Internal function called by `fpt_matrix()`.
//'
//' @param x,y numeric vectors of projected coordinates, in time order, without
//'   missing values.
//' @param t numeric vector of times, in seconds.
//' @param radii numeric vector of radii, in the units of the coordinates, in
//'   increasing order.
//' @returns A matrix with one row per location and one column per radius, with
//'   the time taken to cross the circle centred on the location, and `NA` if
//'   the track does not leave the circle both before and after the location.
//' @keywords internal
//' @noRd
// [[Rcpp::export]]
Rcpp::NumericMatrix fpt_cpp(Rcpp::NumericVector x, Rcpp::NumericVector y,
                            Rcpp::NumericVector t, Rcpp::NumericVector radii) {
  if (x.size() != y.size() || x.size() != t.size()) {
    Rcpp::stop("x, y and t must have the same length");
  }
  const int n = x.size();
  const int n_radii = radii.size();
  Rcpp::NumericMatrix res(n, n_radii);
  std::vector<double> after(n_radii);
  std::vector<double> before(n_radii);
  // the bounding boxes of the blocks of locations, computed once per track
  const BlockBoxes boxes = make_block_boxes(x.begin(), y.begin(), n);
  for (int i = 0; i < n; ++i) {
    // let the user interrupt long computations: the time per location grows
    // with the length of the track, as the search for the crossing of a large
    // circle can run to its ends (checking every location would be wasteful,
    // as the check itself takes time)
    if (i % 1000 == 0) {
      Rcpp::checkUserInterrupt();
    }
    time_to_crossing(x.begin(), y.begin(), t.begin(), n, i, 1, radii.begin(),
                     n_radii, boxes, after.data());
    time_to_crossing(x.begin(), y.begin(), t.begin(), n, i, -1, radii.begin(),
                     n_radii, boxes, before.data());
    for (int k = 0; k < n_radii; ++k) {
      res(i, k) = after[k] + before[k];
    }
  }
  return res;
}
