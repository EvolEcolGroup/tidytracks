// Linear binning of locations onto a regular grid, for the binned kernel
// density estimate of hr_tt_kde(method = "binned").
//
// Each location is split between the (up to) four grid points that surround
// it, with weights that decrease linearly with its distance from each of them
// along x and along y (bilinear weights, which sum to 1). This is the linear
// binning of KernSmooth::bkde2D() (Wand 1994), whose own implementation is
// not exported by KernSmooth. The binned counts are then smoothed with the
// kernel in R, in kde_density_binned().

#include <Rcpp.h>

#include <algorithm>
#include <cmath>

// Locate a coordinate along one axis of the grid, given in grid units (0 at
// the first grid point, n - 1 at the last one): `i` is the index (0-based) of
// the grid point at or before it, and `f` the fraction of the way to the next
// grid point. A coordinate on the last grid point is placed at the end of the
// last interval (i = n - 2, f = 1), so that the next grid point always exists;
// an axis with a single grid point puts everything on it.
static inline void locate(double g, int n, int &i, double &f) {
  if (n == 1) {
    i = 0;
    f = 0.0;
    return;
  }
  i = std::min(static_cast<int>(std::floor(g)), n - 2);
  f = g - i;
}

//' Linear binning of locations onto a grid
//'
//' Internal function called by `kde_density_binned()`: splits each location
//' between the grid points that surround it, in proportion to how close it
//' is to each of them.
//'
//' @param x,y numeric vectors of coordinates.
//' @param x0,y0 the coordinates of the first grid point along x and along y.
//' @param res the spacing of the grid points (the resolution of the grid).
//' @param nx,ny the number of grid points along x and along y.
//' @returns A matrix of binned counts, with one row per grid point along x
//'   (from west to east) and one column per grid point along y (from south to
//'   north), whose sum is the number of locations. Locations outside the grid
//'   are moved to its nearest edge (`kde_density_binned()` extends the grid so
//'   that the locations it moves are beyond the reach of the kernel).
//' @keywords internal
//' @noRd
// [[Rcpp::export]]
Rcpp::NumericMatrix kde_linbin_cpp(Rcpp::NumericVector x,
                                   Rcpp::NumericVector y, double x0,
                                   double y0, double res, int nx, int ny) {
  if (x.size() != y.size()) {
    Rcpp::stop("x and y must have the same length");
  }
  if (nx < 1 || ny < 1 || !(res > 0)) {
    Rcpp::stop("the grid must have at least one point, and res must be > 0");
  }
  // filled with zeros
  Rcpp::NumericMatrix counts(nx, ny);
  for (R_xlen_t k = 0; k < x.size(); ++k) {
    // the position of the location in grid units, from the first grid point
    double gx = (x[k] - x0) / res;
    double gy = (y[k] - y0) / res;
    // locations without coordinates are skipped (hr_tt_kde() removes them
    // beforehand)
    if (std::isnan(gx) || std::isnan(gy)) {
      continue;
    }
    // locations outside the grid are moved to its nearest edge; this also
    // guards against rounding errors for locations on the edges
    gx = std::min(std::max(gx, 0.0), nx - 1.0);
    gy = std::min(std::max(gy, 0.0), ny - 1.0);
    int ix, iy;
    double fx, fy;
    locate(gx, nx, ix, fx);
    locate(gy, ny, iy, fy);
    // the bilinear weights of the four surrounding grid points (the second
    // grid point along an axis only exists if the axis has more than one)
    counts(ix, iy) += (1.0 - fx) * (1.0 - fy);
    if (nx > 1) {
      counts(ix + 1, iy) += fx * (1.0 - fy);
    }
    if (ny > 1) {
      counts(ix, iy + 1) += (1.0 - fx) * fy;
    }
    if (nx > 1 && ny > 1) {
      counts(ix + 1, iy + 1) += fx * fy;
    }
  }
  return counts;
}
