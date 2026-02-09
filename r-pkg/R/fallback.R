#' @title Sudo fallback when daemon unavailable
#' @name fallback
#' @description Fallback to sudo apt when raptd is not running.
NULL

#' Check if running as root
#' @noRd
is_root <- function() {
    system("id -u", intern = TRUE) == "0"
}

#' Check if apt fallback is allowed
#' @noRd
can_use_fallback <- function() {
    # Root can always use apt directly
    if (is_root()) {
        return(TRUE)
    }

    # Explicit option takes precedence
    if (isTRUE(getOption("rapt.sudo"))) {
        return(TRUE)
    }

    # In interactive mode, we can prompt for sudo
    if (interactive()) {
        return(TRUE)
    }

    FALSE
}

#' Fallback install/remove via sudo
#'
#' @param action Character, either "install" or "remove".
#' @param deb_pkgs Character vector of deb package names (already resolved).
#' @return Invisible \code{TRUE} on success, \code{FALSE} on failure.
#' @noRd
fallback_apt <- function(action, deb_pkgs) {
    if (!can_use_fallback()) {
        warning("raptd not available and apt fallback disabled. ",
                "Set options(rapt.sudo = TRUE) to enable.")
        return(invisible(FALSE))
    }

    message("raptd not available, falling back to ",
            if (is_root()) "direct apt" else "sudo")
    if (is_root()) {
        status <- system2("apt", c(action, "-y", deb_pkgs))
    } else {
        status <- system2("sudo", c("apt", action, "-y", deb_pkgs))
    }

    if (status != 0) {
        warning("apt ", action, " failed with status ", status)
        return(invisible(FALSE))
    }

    invisible(TRUE)
}
