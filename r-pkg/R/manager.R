#' @title System package management
#' @name manager
#' @description Install and remove R packages via apt.
NULL

#' Install system packages
#'
#' @param pkgs Character vector of package names to install.
#' @return Invisible TRUE on success, FALSE on failure.
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

#' Remove system packages
#'
#' @param pkgs Character vector of package names to remove.
#' @return Invisible TRUE on success, FALSE on failure.
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
#' @return Character vector of R package names available via apt.
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

#' Get package manager info
#'
#' @return List with rapt configuration and status.
#' @export
manager <- function() {
    list(
        daemon_available = daemon_available(),
        socket_path = getOption("rapt.socket", SOCKET_PATH),
        sudo_allowed = getOption("rapt.sudo", FALSE),
        enabled = isTRUE(getOption("rapt.enabled"))
    )
}
