#' The Moran coefficient
#'
#' @description The Moran coefficient, a measure of spatial autocorrelation (also known as Global Moran's I)
#' @export
#' @param x Numeric vector of input values, length n.
#' @param w An n x n patial connectivity matrix. See \link[geostan]{shape2mat}. 
#' @return The Moran coefficient, a numeric value.
#'
#' @examples
#' library(sf)
#' data(ohio)
#' w <- shape2mat(ohio, snap = 1) # snap=1 catches some misaligned borders (WI-IL)
#' x <- ohio$unemployment
#' mc(x, w)
#'
mc <- function(x, w) {
  if(missing(x) | missing(w)) stop("Must provide data x (length n vector) and n x n spatial weights matrix (w).")
    xbar <- mean(x)
    z <- x - xbar
    ztilde <- as.numeric(w %*% z)
    A <- sum(rowSums(w))
    n <- length(x)
    mc <- as.numeric( n/A * (z %*% ztilde) / (z %*% z))
    return(mc)
}

#' Moran plot
#'
#' @description Plots a set of values against their mean spatially lagged values and gives the Moran coefficient as a measure of spatial autocorrelation. 
#' @export
#' @import ggplot2
#' @param y A numeric vector of length n.
#' @param w An n x n spatial connectivity matrix.
#' @param xlab Label for the x-axis. 
#' @param ylab Label for the y-axis.
#' @param pch Symbol type.
#' @param col Symbol color. 
#' @param size Symbol size.
#' @param alpha Symbol transparency.
#' @param lwd Width of the regression line. 
#' @details For details on the symbol parameters see the documentation for \link[ggplot2]{geom_point}. 
#' @return Returns an object of class \code{gg}, a scatter plot with y on the x-axis and the spatially lagged values on the y-axis (i.e. a Moran plot).
#' @examples
#' library(sf)
#' data(ohio)
#' y <- ohio$unemployment
#' w <- shape2mat(ohio)
#' moran_plot(y, w)
#'
moran_plot <- function(y, w, xlab = "y", ylab = "Spatial Lag", pch = 20, col = "darkred", size = 2, alpha = 1, lwd = 0.5) {
    if (!inherits(y, "numeric")) stop("y must be a numeric vector")
    sqr <- all( dim(w) == length(y) )
    if (!inherits(w, "matrix") | !sqr) stop("w must be an n x n matrix where n = length(y)")
    ylag <- as.numeric(w %*% y)
    sub <- paste0("MC = ", round(mc(y, w),3))
    ggplot(data.frame(y = y,
                      ylag = ylag)) +
    geom_hline(yintercept = mean(ylag),
               lty = 3) +
    geom_vline(xintercept = mean(y),
               lty = 3) +
    geom_point(
        pch = 20,
        colour = col,
        size = size,
        alpha = alpha,
        aes(x = y,
            y = ylag)
    ) +
        geom_smooth(aes(x = y,
                        y = ylag),
                method = lm,
                lwd = lwd,
                col = "black",
                se = FALSE) +
    labs(x = xlab,
         y = ylab,
         subtitle = sub) +
    theme_classic() 
    }

#' Extract eigenfunctions of a connectivity matrix for spatial filtering
#'
#' @export
#' @param C A binary spatial weights matrix. See \link[geostan]{shape2mat} or \link[spdep]{nb2mat}.
#' @param nsa Logical. Default of \code{nsa = FALSE} excludes eigenvectors capturing negative spatial autocorrelation.
#'  Setting \code{nsa = TRUE} will result in a candidate set of EVs that contains eigenvectors representing positive and negative SA.
#' @param threshold Defaults to \code{threshold=0.2} to exclude eigenvectors representing spatial autocorrelation levels that are less than \code{threshold} times the maximum possible Moran coefficient achievable for the given spatial connectivity matrix. If \code{theshold = 0}, the eigenvector of constants (with eigenvalue of zero) will be dropped automatically.
#' @param values Should eigenvalues be returned also? Defaults to \code{FALSE}.
#' @details Returns a set of EVs limited to those with |MC| > \code{threshold} if \code{nsa = TRUE} or MC > \code{threshold} if \code{nsa = FALSE}, along with corresponding eigenvalues (optionally). Given a spatial connectivity matrix C, the function returns eigenvectors from a transformed spatial weights matrix.
#' @source
#'
#' Daniel Griffith and Yongwan Chun. 2014. "Spatial Autocorrelation and Spatial Filtering." in M. M. Fischer and P. Nijkamp (eds.), \emph{Handbook of Regional Science.} Springer.
#'
#' @return A \code{data.frame} of eigenvectors for spatial filtering. If \code{values=TRUE} then a named list is returned with elements \code{eigenvectors} and \code{eigenvalues}.
#'
#' @examples
#' data(ohio)
#' C <- shape2mat(ohio, style = "B")
#' EV <- make_EV(C)
#' 
make_EV <- function(C, nsa = FALSE, threshold = 0.2, values = FALSE) {
  if (!isSymmetric(C)) C <- (t(C) + C) / 2
  N <- nrow(C)
  M <- diag(N) - matrix(1, N, N)/N
  MCM <- M %*% C %*% M
  eigens <- eigen(MCM, symmetric = TRUE)
  if(nsa) {
    idx = abs(eigens$values/eigens$values[1]) >= threshold
  } else idx <- eigens$values/eigens$values[1] >= threshold
  v <- round(eigens$values / eigens$values[1], 12)
  if (any(v == 0)) {
    rmdx <- which(v == 0)
    idx[rmdx] <- FALSE
  }
  EV <- as.data.frame(eigens$vectors[ , idx] )
  colnames(EV) <- paste0("EV", 1:ncol(EV))
  if (values) {
    lambda <- eigens$values[idx]
    return(list(eigenvectors = EV, eigenvalues = lambda))
  } else
    return(EV)
}

#' Create a spatial weights matrix from a spatial object of class \code{sf} or \code{SpatialPolygons} or \code{SpatialPolygonsDataFrame}
#'
#' @export
#' @import spdep
#' @description A wrapper function for a string of \code{spdep} (and other) functions required to convert spatail objects to connectivity matrices
#' @param shape An object of class \code{sf}, \code{SpatialPolygons} or \code{SpatialPolygonsDataFrame}.
#' @param style What kind of coding scheme should be used to create the spatial connectivity matrix? Defaults to "B" for binary; use "W" for row-standardized weights; "C" for globally standardized and "S" for the Tiefelsdorf et al.'s (1999) variance-stabilizing scheme. This is passed internally to \link[spdep]{nb2mat}.
#' @param t Number of time periods. Currently only the binary coding scheme is available for space-time connectivity matrices.
#' @param st.type For space-time data, what type of space-time connectivity structure should be used? Options are "lag" for the lagged specification and (the default) "contemp" for contemporaneous specification.
#' @param zero.policy Are regions with zero neighbors allowed? Default \code{zero.policy = TRUE} (allowing regions to have zero neighbors). Also passed to \link[spdep]{nb2mat}.
#' @param queen Passed to \link[spdep]{poly2nb} to set the contiguity condition. Defaults to \code{TRUE} so that a single shared boundary point between polygons is sufficient for them to be considered neighbors.
#' @param snap Passed to \link[spdep]{poly2nb}; "boundary points less than ‘snap’ distance apart are considered to indicate contiguity." 
#' @return A spatial connectivity matrix
#' @seealso \code{\link{spdep}}
#' @source
#'
#' Griffith, D. A., Chun, Y., Li, B. (2020). Spatial Regression Analysis Using Eigenvector Spatial Filtering. Academic Press, Ch. 8.
#' 
#' Tiefelsdorf, M., Griffith, D. A., Boots, B. (1999). "A variance-stabilizing coding scheme for spatial link matrices." Environment and Planning A, 31, pp. 165-180.
#'
#' @examples
#' data(ohio)
#' C <- shape2mat(ohio, "B")
#' W <- shape2mat(ohio, "W")
#'
#' ## for space-time data
#' ## if you have multiple years with same neighbors
#' ## provide the geography (for a single year!) and number of years \code{t}
#' Cst <- shape2mat(ohio, t = 5)
#' 
shape2mat <- function(shape, style = "B", t = 1, st.type = "contemp", zero.policy = TRUE, queen = TRUE, snap = sqrt(.Machine$double.eps)) {
  shape_class <- class(shape)
  if (!any(c("sf", "SpatialPolygonsDataFrame", "SpatialPolygons") %in% shape_class)) stop("Shape must be of class SpatialPolygonsDataFrame or sf (simple features).")
  if (any(c("SpatialPolygonsDataFrame", "SpatialPolygons") %in% shape_class)) {
      w <- spdep::nb2mat(spdep::poly2nb(shape, queen = queen, snap = snap), style = style, zero.policy = zero.policy)
  }
  if ("sf" %in% shape_class) {
          shape_spdf <- sf::as_Spatial(shape)
          w <- spdep::nb2mat(spdep::poly2nb(shape_spdf, queen = queen, snap = snap), style = style, zero.policy = zero.policy)
  }
  attributes(w)$dimnames <- NULL
  if (t > 1) { 
      if (style != "B") stop ("Only the binary coding scheme (style = 'B') has been implemented for space-time matrices.")
      ## binary temporal connectivity matrix
      s <- nrow(w)
      Ct <- matrix(0, nrow = t, ncol = t)
      for (i in 2:t) Ct[i, i-1] <- Ct[i-1, i] <- 1
      if (st.type == "lag") w = kronecker(Ct, (w + diag(s)))
      if (st.type == "contemp") {
          ## create identify matrices for space and time
          It <- diag(1, nrow = t)
          Is <- diag(1, nrow = s)
          w <- kronecker(It, w) + kronecker(Ct, Is)
      }
      }
  return(w)
}

#' Student t family
#'
#' @export
#' @description create a family object for the Student t likelihood
#' @return An object of class \code{family}
#'
student_t <- function() {
  family <- list(family = "student_t", link = 'identity')
  class(family) <- "family"
  return(family)
}

#' WAIC
#'
#' @description Widely Application Information Criteria (WAIC) for model evalution
#' @export
#' @param fit An \code{geostan_fit} object or any Stan model with a parameter named "log_lik", the pointwise log predictive likelihood
#' @param pointwise Logical, should a vector of values for each observation be returned? Default is \code{FALSE}.
#' @param digits Defaults to 2. Round results to this many digits.
#' @return A vector of length 3 with \code{WAIC}, a rough measure of the effective number of parameters estimated by the model \code{Eff_pars}, and log predictive density (\code{Lpd}). If \code{pointwise = TRUE}, results are returned in a \code{data.frame}.
#' @seealso \code{\link{loo}}
#' @examples
#' data(ohio)
#' fit <- stan_esf(gop_growth ~ 1, data = ohio, C = shape2mat(ohio),
#'                 chains = 1, iter = 400)
#' waic(fit)
#' 
waic <- function(fit, pointwise = FALSE, digits = 2) {
  ll <- as.matrix(fit, pars = "log_lik")
  nsamples <- nrow(ll)
  lpd <- apply(ll, 2, log_sum_exp) - log(nsamples)
  p_waic <- apply(ll, 2, var)
  waic <- -2 * (lpd - p_waic)
  if(pointwise) return(data.frame(waic = waic, eff_pars = p_waic, lpd = lpd))
  res <- c(WAIC = sum(waic), Eff_pars = sum(p_waic), Lpd = sum(lpd))
  return(round(res, digits))
}

#' Expected value of the residual Moran coefficient.
#'
#' @description Expected value for the Moran coefficient of model residuals under the null hypothesis of no spatial autocorrelation.
#' @export
#' @param X model matrix, including column of ones.
#' @param C Connectivity matrix.
#' @source
#'  Chun, Yongwan and Griffith, Daniel A. (2013). Spatial statistics and geostatistics. Sage, p. 18.
#' @return Returns a numeric value.
#'
expected_mc <- function(X, C) {
    n = nrow(X)
    k = ncol(X)
    under <- (n-k) * sum(rowSums(C))
    mc = -n * sum(diag( solve(t(X) %*% X) %*% t(X) %*% C %*% X )) / under
    return(as.numeric(mc))
}

#' Expected dimensions of an eigenvector spatial filter
#'
#' @description Provides an informed guess for the number of eigenvectors required to remove spatial autocorrelation from a regression.
#' For \link[geostan]{stan_esf} the result can be
#' used to set the hyper parameter \code{p0}, controlling the hyper-prior scale parameter for the global shrinkage parameter in the regularized horseshoe prior.
#' @export
#' @importFrom stats model.matrix residuals lm
#' @param formula Model formula.
#' @param data The data used to fit the model; must be coercible to a dataframe for use in \code{model.matrix}.
#' @param C An N x N binary connectivity matrix.
#' @return Returns a numeric value representing the expected number of eigenvectors required to estimate a spatial filter (i.e. number of non-zero or 'large' coefficients).
#' @details Following Chun et al. (2016), the expected number of eigenvectors required to remove residual spatial autocorrelation from a model
#'  is an increasing function of the degree of spatial autocorrelation in the outcome variable and the number of links in the connectivity matrix.
#'
#'@source
#'
#' Chun, Yongwan, Griffith, Daniel A., Lee, Mongyeon, and Sinha, Parmanand (2016). "Eigenvector selection with stepwise regression techniques to construct eigenvector spatial filters." Journal of Geographical Systems 18(1): 67-85.
#' 
exp_pars <- function(formula, data, C) {
  nlinks <- length(which(C != 0))
  N <- nrow(C)
    if (any(!C %in% c(0, 1))) {
        C <- apply(C, 2, function(i) ifelse(i != 0, 1, 0))
      }
  M <- diag(N) - matrix(1, N, N)/N
  MCM <- M %*% C %*% M
  eigens <- eigen(MCM, symmetric = TRUE)
  npos <- sum(eigens$values > 0)
  sa <- mc(residuals(lm(formula, data = data)), C)
  X <- model.matrix(formula, data)
  E_sa <- expected_mc(X, C)
  Sigma_sa <- sqrt( 2 / nlinks )
  z_sa <- (sa - E_sa) / Sigma_sa
  if (z_sa < -.59) {
    z_sa = -.59
  warning("The moran coefficient indicates very strong negative spatial autocorrelation, which this formula for obtaining the expected no. of eigenvectors was not designed for.")
  }
  a <- (6.1808 * (z_sa + .6)^.1742) / npos^.1298
  b <- 3.3534 / (z_sa + .6)^.1742
  denom <- 1 + exp(2.148 - a + b)
  candidates <- round(npos / denom)
  return(candidates)
}

#' Edge list
#'
#' @description Creates a list of unique connected nodes following the graph representation of a spatial connectivity matrix.
#' @export
#' @param w A connectivity matrix where connection between two nodes is indicated by non-zero entries.
#' @return Returns a \code{data.frame} with two columns representing connected pairs of nodes; only unique pairs of nodes are included.
#'
#' @details This is used internally for  \link[geostan]{stan_icar} and \link[geostan]{stan_bym2}; it is also needed to create the scaling factor for \code{stan_bym2}.
#' @examples
#' 
#' data(sentencing)
#' C <- shape2mat(sentencing)
#' nbs <- edges(C)
#' 
edges <- function(w) {
  lw <- apply(w, 1, function(r) {
    which(r != 0)
  })
  all.edges <- lapply(1:length(lw), function(i) {
    nbs <- lw[[i]]
    if(length(nbs)) data.frame(node1 = i, node2 = nbs)
  })
  all.edges <- do.call("rbind", all.edges)
  edges <- all.edges[which(all.edges$node1 < all.edges$node2),]
  return(edges)
}

