// Profile of the C++ code of hr_tt_locoh(), and a prototype of a parallel
// (OpenMP) neighbour search and hull construction. Compiled and run by
// locoh_profile_cpp.R, which puts src/ on the include path.
//
// [[Rcpp::plugins(openmp)]]
#include "locoh.cpp"  // the package's code (everything but the exports)

#include <chrono>
#ifdef _OPENMP
#include <omp.h>
#endif

namespace {
using Clock = std::chrono::steady_clock;
double elapsed_ms(Clock::time_point from, Clock::time_point to) {
  return std::chrono::duration<double, std::milli>(to - from).count();
}
}  // namespace

// Time each phase of locoh_cpp(), for the hulls needed by one level.
// [[Rcpp::export]]
Rcpp::NumericVector locoh_phases(Rcpp::NumericVector x, Rcpp::NumericVector y,
                                 std::string type, double n, double level) {
  const int n_pts = static_cast<int>(x.size());
  const double* px = x.begin();
  const double* py = y.begin();

  // building the tree on its own (find_neighbours() builds it again)
  const auto t0 = Clock::now();
  const KdTree tree(px, py, n_pts);
  const auto t1 = Clock::now();
  const NeighbourSets sets = find_neighbours(px, py, n_pts, type, n);
  const auto t2 = Clock::now();

  // hulls, with their areas
  std::vector<std::vector<Point>> hulls(n_pts);
  std::vector<double> key(n_pts);
  std::vector<Point> pts;
  for (int i = 0; i < n_pts; ++i) {
    pts.clear();
    for (std::size_t j = sets.offsets[i]; j < sets.offsets[i + 1]; ++j) {
      pts.push_back(Point{px[sets.members[j]], py[sets.members[j]]});
    }
    hulls[i] = convex_hull(pts);
    double area = 0.0;
    double perimeter = 0.0;
    area_perimeter(hulls[i], area, perimeter);
    key[i] = area;
  }
  const auto t3 = Clock::now();

  // sorting, coverage and level
  std::vector<int> order(n_pts);
  for (int i = 0; i < n_pts; ++i) {
    order[i] = i;
  }
  std::stable_sort(order.begin(), order.end(),
                   [&key](int a, int b) { return key[a] < key[b]; });
  std::vector<char> seen(n_pts, 0);
  std::vector<double> coverage(n_pts);
  int n_seen = 0;
  for (int j = 0; j < n_pts; ++j) {
    for (std::size_t m = sets.offsets[order[j]];
         m < sets.offsets[order[j] + 1]; ++m) {
      if (!seen[sets.members[m]]) {
        seen[sets.members[m]] = 1;
        ++n_seen;
      }
    }
    coverage[j] = static_cast<double>(n_seen) / n_pts;
  }
  int best = 0;
  for (int j = 1; j < n_pts; ++j) {
    if (std::fabs(coverage[j] - level) < std::fabs(coverage[best] - level)) {
      best = j;
    }
  }
  const auto t4 = Clock::now();

  // conversion of the hulls to R objects
  Rcpp::List out(best + 1);
  for (int j = 0; j <= best; ++j) {
    out[j] = hull_to_sfg(hulls[order[j]], 0.0, 0.0);
  }
  const auto t5 = Clock::now();

  return Rcpp::NumericVector::create(
    Rcpp::Named("tree_ms") = elapsed_ms(t0, t1),
    Rcpp::Named("neighbours_ms") = elapsed_ms(t1, t2),
    Rcpp::Named("hulls_ms") = elapsed_ms(t2, t3),
    Rcpp::Named("sort_levels_ms") = elapsed_ms(t3, t4),
    Rcpp::Named("r_objects_ms") = elapsed_ms(t4, t5));
}

// Prototype: the neighbour search (type "k") and the hulls in parallel, one
// location per iteration. The tree is only read once it is built, so the
// threads can share it; each thread has its own scratch vectors, and each
// location its own vector of neighbours (rather than the shared CSR layout,
// which is filled in order). R's API must not be called from the threads.
// [[Rcpp::export]]
double locoh_knn_hulls_parallel(Rcpp::NumericVector x, Rcpp::NumericVector y,
                                int k, int threads) {
  const int n_pts = static_cast<int>(x.size());
  const double* px = x.begin();
  const double* py = y.begin();
  const auto t0 = Clock::now();
  const KdTree tree(px, py, n_pts);
  std::vector<std::vector<int>> members(n_pts);
  std::vector<std::vector<Point>> hulls(n_pts);
  std::vector<double> key(n_pts);
#ifdef _OPENMP
#pragma omp parallel num_threads(threads)
#endif
  {
    std::vector<int> nb;
    std::vector<Point> pts;
#ifdef _OPENMP
#pragma omp for schedule(dynamic, 256)
#endif
    for (int i = 0; i < n_pts; ++i) {
      tree.knn(px[i], py[i], k, i, nb);
      members[i].reserve(nb.size() + 1);
      members[i].push_back(i);
      members[i].insert(members[i].end(), nb.begin(), nb.end());
      pts.clear();
      for (int m : members[i]) {
        pts.push_back(Point{px[m], py[m]});
      }
      hulls[i] = convex_hull(pts);
      double area = 0.0;
      double perimeter = 0.0;
      area_perimeter(hulls[i], area, perimeter);
      key[i] = area;
    }
  }
  (void) threads;  // unused without OpenMP
  return elapsed_ms(t0, Clock::now());
}
