// Exact geometric predicates, shared by convex_union.cpp and locoh.cpp.
//
// The basic predicate is the sign of the cross product (b - a) x (d - c),
// which, with c = a, tells on which side of the line from a to b the point d
// lies (positive on the left, negative on the right, zero on the line). It is
// computed in floating point, with Shewchuk's (1997) bound on its rounding
// error; only when the bound cannot tell the sign is it computed exactly, as
// an "expansion" (a sum of doubles that represents a number with no rounding
// error, built with error-free transformations).
//
// The predicates assume IEEE double arithmetic, with round-to-nearest, and
// that the products of differences of coordinates neither overflow nor
// underflow (convex_union.cpp checks the magnitude of the coordinates).
// Contracting a * b + c into a fused multiply-add does not change their
// results (the error-free transformations use std::fma explicitly, or no
// products at all, and contraction only makes the floating-point estimates
// more accurate), but -ffast-math (which reorders additions) would break
// them.
//
// Shewchuk, J. R. (1997). Adaptive precision floating-point arithmetic and
// fast robust geometric predicates. Discrete & Computational Geometry, 18,
// 305-363.

#ifndef TIDYTRACKS_EXACT_PREDICATES_H
#define TIDYTRACKS_EXACT_PREDICATES_H

#include <cmath>
#include <limits>
#include <vector>

namespace exact_predicates {

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
inline void grow(std::vector<double>& e, double b) {
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
inline std::vector<double> cross_exact(double ax, double ay, double bx,
                                       double by, double cx, double cy,
                                       double dx, double dy) {
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

// The side of c relative to the line from a to b: 1 on the left, -1 on the
// right, 0 on the line.
inline int orientation(double ax, double ay, double bx, double by, double cx,
                       double cy) {
  const Approx approx = cross_approx(ax, ay, bx, by, ax, ay, cx, cy);
  return cross_sign(approx, ax, ay, bx, by, ax, ay, cx, cy);
}

// Whether a coordinate is safe for the predicates: 0, or a magnitude between
// 2^-100 and 2^100. The predicates multiply up to four differences of
// coordinates (when comparing crossings along an edge), whose products must
// neither overflow nor underflow; with such coordinates, the differences are
// at most 2^101, and at least 2^-152 unless zero, which keeps every product
// and every rounding error well within the range of doubles.
inline bool safe_coordinate(double v) {
  static const double lowest = std::ldexp(1.0, -100);
  static const double highest = std::ldexp(1.0, 100);
  const double a = std::fabs(v);
  return a == 0.0 || (a >= lowest && a <= highest);
}

} // namespace exact_predicates

#endif
