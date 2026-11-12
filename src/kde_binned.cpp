// The binned kernel density estimate of hr_tt_kde(method = "binned"), in two
// steps, both called by kde_density_binned():
//
// 1. Linear binning of the locations onto a regular grid (kde_linbin_cpp()).
//    Each location is split between the (up to) four grid points that
//    surround it, with weights that decrease linearly with its distance from
//    each of them along x and along y (bilinear weights, which sum to 1).
//    This is the linear binning of KernSmooth::bkde2D() (Wand 1994), whose
//    own implementation is not exported by KernSmooth.
// 2. Smoothing of the binned counts with the kernel (kde_convolve_cpp()).
//    The Gaussian kernel is separable (the kernel in 2D is the product of a
//    kernel along x and one along y), so the 2D convolution is a convolution
//    along x followed by one along y. Each is computed directly, over the
//    grid points within reach of the (truncated) kernel only, and skipping
//    the empty bins, so that it takes a time proportional to the number of
//    cells within reach of the locations times the width of the kernel.
//    KernSmooth::bkde2D() instead computes the 2D convolution with fast
//    Fourier transforms, on a grid padded to a power of 2 along each axis,
//    which takes longer.

#include <Rcpp.h>

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <vector>

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

//' Smoothing of binned counts with a separable kernel
//'
//' Internal function called by `kde_density_binned()`: convolves the binned
//' counts with the kernel along x, and then along y, and returns the result
//' at the centres of the cells of the grid. A grid point of the binned counts
//' contributes to a cell if their distance (in cells) is within the
//' half-width of the kernel along that axis, with the weight of the kernel at
//' that distance.
//'
//' @param counts the binned counts, as returned by `kde_linbin_cpp()`, with
//'   one row per grid point along x and one column per grid point along y.
//' @param wx,wy the weights of the kernel along x and along y, at 0, 1, ...,
//'   half-width grid points from its centre (as from
//'   `kde_kernel_weights()`).
//' @param ncx,ncy the number of cells of the grid along x and along y.
//' @param offx,offy the number of grid points of the binned counts before
//'   the centre of the first cell of the grid, along x and along y (the
//'   centre of cell `i` is grid point `i + offx`, both 0-based).
//' @returns A matrix with one row per cell along x (from west to east) and
//'   one column per cell along y (from south to north).
//' @keywords internal
//' @noRd
// [[Rcpp::export]]
Rcpp::NumericMatrix kde_convolve_cpp(Rcpp::NumericMatrix counts,
                                     Rcpp::NumericVector wx,
                                     Rcpp::NumericVector wy, int ncx, int ncy,
                                     int offx, int offy) {
  if (wx.size() < 1 || wy.size() < 1) {
    Rcpp::stop("the kernel must have at least one weight along each axis");
  }
  if (ncx < 1 || ncy < 1) {
    Rcpp::stop("the grid must have at least one cell along each axis");
  }
  const int nbx = counts.nrow(), nby = counts.ncol();
  const int lx = wx.size() - 1, ly = wy.size() - 1;
  const double *cnt = counts.begin();
  const double *kx = wx.begin();
  const double *ky = wy.begin();

  // 1) Along x: tmp(i, b) is the sum over the grid points a of
  // wx[|i + offx - a|] * counts(a, b). Each non-empty bin is spread onto the
  // cells within the half-width of the kernel; the grid points along y with
  // no locations (empty columns of counts) are flagged, to be skipped along
  // y, as are the cells along x that the kernel does not reach (outside
  // [i_min, i_max]).
  std::vector<double> tmp(static_cast<size_t>(ncx) * nby, 0.0);
  std::vector<char> used(nby, 0);
  int i_min = ncx, i_max = -1;
  for (int b = 0; b < nby; ++b) {
    const double *cb = cnt + static_cast<size_t>(b) * nbx;
    double *tb = tmp.data() + static_cast<size_t>(b) * ncx;
    for (int a = 0; a < nbx; ++a) {
      const double c = cb[a];
      if (c == 0.0) {
        continue;
      }
      // the cell whose centre is grid point a (it may be outside the grid)
      const int centre = a - offx;
      const int i0 = std::max(0, centre - lx);
      const int i1 = std::min(ncx - 1, centre + lx);
      if (i0 > i1) {
        continue;
      }
      used[b] = 1;
      i_min = std::min(i_min, i0);
      i_max = std::max(i_max, i1);
      for (int i = i0; i <= i1; ++i) {
        tb[i] += c * kx[std::abs(i - centre)];
      }
    }
  }

  // 2) Along y: z(i, j) is the sum over the grid points b of
  // wy[|j + offy - b|] * tmp(i, b), added one (non-empty) column of tmp at a
  // time, along the cells within reach of the kernel along x
  Rcpp::NumericMatrix z(ncx, ncy);
  double *zp = z.begin();
  for (int b = 0; b < nby; ++b) {
    if (!used[b]) {
      continue;
    }
    const double *tb = tmp.data() + static_cast<size_t>(b) * ncx;
    const int centre = b - offy;
    const int j0 = std::max(0, centre - ly);
    const int j1 = std::min(ncy - 1, centre + ly);
    for (int j = j0; j <= j1; ++j) {
      const double w = ky[std::abs(j - centre)];
      double *zj = zp + static_cast<size_t>(j) * ncx;
      for (int i = i_min; i <= i_max; ++i) {
        zj[i] += w * tb[i];
      }
    }
  }
  return z;
}
