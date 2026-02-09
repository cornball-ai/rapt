# Package-level cache for available deb packages
.pkg_cache <- new.env(parent = emptyenv())
.pkg_cache$time <- as.POSIXct(0, origin = "1970-01-01")
.pkg_cache$pkgs <- character(0)
.pkg_cache$map  <- character(0)

#' Ensure package cache is fresh
#' @noRd
ensure_cache <- function() {
    ttl <- getOption("rapt.cache_ttl", 3600)
    if (as.numeric(Sys.time() - .pkg_cache$time, units = "secs") < ttl)
        return(invisible(NULL))
    refresh_cache()
}

#' Refresh the package cache
#'
#' Forces a refresh of the cached mapping between R package names and
#' their apt package names. Call this after \code{apt update} to pick
#' up newly available packages.
#'
#' @return Invisible \code{NULL}.
#' @examples
#' \dontrun{
#' refresh_cache()
#' }
#' @export
refresh_cache <- function() {
    cran <- system2("apt-cache", c("pkgnames", "r-cran-"),
                    stdout = TRUE, stderr = NULL)
    bioc <- system2("apt-cache", c("pkgnames", "r-bioc-"),
                    stdout = TRUE, stderr = NULL)

    # Build named vector: tolower(r_name) -> deb_name
    map <- character(0)
    if (length(bioc) > 0) {
        r_bioc <- sub("^r-bioc-", "", bioc)
        names(bioc) <- tolower(r_bioc)
        map <- bioc
    }
    if (length(cran) > 0) {
        r_cran <- sub("^r-cran-", "", cran)
        names(cran) <- tolower(r_cran)
        # cran overwrites bioc if both exist
        map[names(cran)] <- cran
    }

    .pkg_cache$map  <- map
    .pkg_cache$pkgs <- sort(unique(c(
        sub("^r-cran-", "", cran),
        sub("^r-bioc-", "", bioc)
    )))
    .pkg_cache$time <- Sys.time()
    invisible(NULL)
}

#' Convert R package names to deb package names
#'
#' Uses the cached package list to return the correct deb name
#' (\code{r-cran-*} or \code{r-bioc-*}). Defaults to \code{r-cran-}
#' for packages not found in the cache.
#'
#' @param pkgs Character vector of R package names.
#' @return Character vector of deb package names.
#' @noRd
r_to_deb <- function(pkgs) {
    ensure_cache()
    lc <- tolower(pkgs)
    idx <- match(lc, names(.pkg_cache$map))
    ifelse(is.na(idx), paste0("r-cran-", lc), unname(.pkg_cache$map[idx]))
}

#' Install system packages via apt
#'
#' Installs R packages using apt. Communicates with the raptd daemon
#' if available, otherwise falls back to sudo. Supports both
#' \code{r-cran-*} and \code{r-bioc-*} packages from r2u.
#'
#' @param pkgs Character vector of R package names to install (e.g., "dplyr").
#' @return Invisible \code{TRUE} on success, \code{FALSE} on failure.
#' @examples
#' \dontrun{
#' install_sys("dplyr")
#' install_sys(c("ggplot2", "data.table"))
#' }
#' @seealso \code{\link{remove_sys}}, \code{\link{available_sys}}
#' @export
install_sys <- function(pkgs) {
    pkgs <- validate_pkgs(pkgs)
    if (length(pkgs) == 0) return(invisible(TRUE))

    deb_pkgs <- r_to_deb(pkgs)

    # Try daemon first
    if (daemon_available()) {
        cmd <- paste("install", paste(deb_pkgs, collapse = " "))
        response <- rapt_call(cmd)
        result <- parse_response(response)

        if (nzchar(result$output)) {
            message(result$output)
        }

        if (result$status != 0) {
            warning("apt install failed with status ", result$status)
            return(invisible(FALSE))
        }
        return(invisible(TRUE))
    }

    # Fallback to sudo
    fallback_apt("install", deb_pkgs)
}

#' Remove system packages via apt
#'
#' Removes R packages using apt. Communicates with the raptd daemon
#' if available, otherwise falls back to sudo. Supports both
#' \code{r-cran-*} and \code{r-bioc-*} packages.
#'
#' @param pkgs Character vector of R package names to remove.
#' @return Invisible \code{TRUE} on success, \code{FALSE} on failure.
#' @examples
#' \dontrun{
#' remove_sys("dplyr")
#' }
#' @seealso \code{\link{install_sys}}
#' @export
remove_sys <- function(pkgs) {
    pkgs <- validate_pkgs(pkgs)
    if (length(pkgs) == 0) return(invisible(TRUE))

    deb_pkgs <- r_to_deb(pkgs)

    # Try daemon first
    if (daemon_available()) {
        cmd <- paste("remove", paste(deb_pkgs, collapse = " "))
        response <- rapt_call(cmd)
        result <- parse_response(response)

        if (nzchar(result$output)) {
            message(result$output)
        }

        if (result$status != 0) {
            warning("apt remove failed with status ", result$status)
            return(invisible(FALSE))
        }
        return(invisible(TRUE))
    }

    # Fallback to sudo
    fallback_apt("remove", deb_pkgs)
}

#' List available system packages
#'
#' Returns R package names available via apt, including both
#' \code{r-cran-*} and \code{r-bioc-*} packages from r2u.
#' Results are cached for one hour (configurable via
#' \code{options(rapt.cache_ttl)}).
#'
#' @return Character vector of R package names available via apt
#'   (without prefix).
#' @examples
#' \dontrun{
#' available_sys()
#' "dplyr" %in% available_sys()
#' }
#' @seealso \code{\link{install_sys}}, \code{\link{refresh_cache}}
#' @export
available_sys <- function() {
    ensure_cache()
    .pkg_cache$pkgs
}

#' Check if packages are available as system packages
#'
#' @param pkgs Character vector of package names.
#' @return Logical vector indicating availability.
#' @noRd
available_as_sys <- function(pkgs) {
    available <- available_sys()
    tolower(pkgs) %in% tolower(available)
}

#' Validate package names
#'
#' @param pkgs Package names to validate.
#' @return Validated package names (invalid ones removed with warning).
#' @noRd
validate_pkgs <- function(pkgs) {
    if (!is.character(pkgs)) {
        stop("pkgs must be a character vector")
    }

    pkgs <- unique(pkgs[nzchar(pkgs)])

    # Check for valid characters
    valid <- grepl("^[a-zA-Z0-9._]+$", pkgs)
    if (!all(valid)) {
        warning("Invalid package names removed: ",
                paste(pkgs[!valid], collapse = ", "))
        pkgs <- pkgs[valid]
    }

    pkgs
}

#' Get rapt status and configuration
#'
#' Returns information about the current rapt configuration, daemon
#' status, and cache age.
#'
#' @return A list with components:
#' \describe{
#'   \item{daemon_available}{Logical; is the raptd daemon running?}
#'   \item{socket_path}{Character; path to the Unix socket.}
#'   \item{sudo_allowed}{Logical; is sudo fallback enabled?}
#'   \item{enabled}{Logical; is the install.packages() hook active?}
#'   \item{cache_age}{Numeric; cache age in seconds (Inf if never refreshed).}
#' }
#' @examples
#' manager()
#' @export
manager <- function() {
    age <- as.numeric(Sys.time() - .pkg_cache$time, units = "secs")
    list(
        daemon_available = daemon_available(),
        socket_path = getOption("rapt.socket", SOCKET_PATH),
        sudo_allowed = getOption("rapt.sudo", FALSE),
        enabled = isTRUE(getOption("rapt.enabled")),
        cache_age = age
    )
}
