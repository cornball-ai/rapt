#' Install system packages via apt
#'
#' Installs R packages using \code{apt install r-cran-*}. Communicates
#' with the raptd daemon if available, otherwise falls back to sudo.
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

    # Try daemon first
    if (daemon_available()) {
        cmd <- paste("install", paste(pkgs, collapse = " "))
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
    fallback_install(pkgs)
}

#' Remove system packages via apt
#'
#' Removes R packages using \code{apt remove r-cran-*}. Communicates
#' with the raptd daemon if available, otherwise falls back to sudo.
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

    # Try daemon first
    if (daemon_available()) {
        cmd <- paste("remove", paste(pkgs, collapse = " "))
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
    fallback_remove(pkgs)
}

#' List available system packages
#'
#' Queries \code{apt-cache} for available \code{r-cran-*} packages.
#' Does not require the raptd daemon.
#'
#' @return Character vector of R package names available via apt
#'   (without the \code{r-cran-} prefix).
#' @examples
#' \dontrun{
#' available_sys()
#' "dplyr" %in% available_sys()
#' }
#' @seealso \code{\link{install_sys}}
#' @export
available_sys <- function() {
    # This doesn't need the daemon - query apt-cache directly
    out <- system2("apt-cache", c("pkgnames", "r-cran-"),
                   stdout = TRUE, stderr = NULL)

    if (length(out) == 0) {
        return(character(0))
    }

    # Strip "r-cran-" prefix and return
    pkgs <- sub("^r-cran-", "", out)
    sort(unique(pkgs))
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
#' Returns information about the current rapt configuration and daemon status.
#'
#' @return A list with components:
#' \describe{
#'   \item{daemon_available}{Logical; is the raptd daemon running?}
#'   \item{socket_path}{Character; path to the Unix socket.}
#'   \item{sudo_allowed}{Logical; is sudo fallback enabled?}
#'   \item{enabled}{Logical; is the install.packages() hook active?}
#' }
#' @examples
#' manager()
#' @export
manager <- function() {
    list(
        daemon_available = daemon_available(),
        socket_path = getOption("rapt.socket", SOCKET_PATH),
        sudo_allowed = getOption("rapt.sudo", FALSE),
        enabled = isTRUE(getOption("rapt.enabled"))
    )
}
