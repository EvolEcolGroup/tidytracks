// First passage time (FPT): the time that an animal takes to cross a circle of
// a given radius centred on each of its locations (Fauchald & Tveraa 2003).
//
// This is the definition of adehabitatLT::fpt(). The difference is in the
// search for the first location outside each circle: adehabitatLT restarts it
// from the centre of the circle for each radius, whilst here, as a larger
// circle cannot be left before a smaller one, it carries on from where the
// previous radius stopped.

#include <Rcpp.h>

#include <cmath>
#include <vector>

// The time from location i to the crossing of each circle centred on it,
// walking along the track in steps of `dir` (1 forwards, -1 backwards). The
// crossing is found by linear interpolation between the last location inside
// the circle and the first one outside it. Radii must be in increasing order;
// circles that the track does not leave get NA.
static void time_to_crossing(const double *x, const double *y, const double *t,
                             int n, int i, int dir, const double *radii,
                             int n_radii, double *out) {
  int pos = i + dir;
  for (int k = 0; k < n_radii; ++k) {
    const double radius_sq = radii[k] * radii[k];
    double dist_sq = 0.0;
    while (pos >= 0 && pos < n) {
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
  for (int i = 0; i < n; ++i) {
    time_to_crossing(x.begin(), y.begin(), t.begin(), n, i, 1, radii.begin(),
                     n_radii, after.data());
    time_to_crossing(x.begin(), y.begin(), t.begin(), n, i, -1, radii.begin(),
                     n_radii, before.data());
    for (int k = 0; k < n_radii; ++k) {
      res(i, k) = after[k] + before[k];
    }
  }
  return res;
}
