#' @title Sudo fallback when daemon unavailable
#' @name fallback
#' @description Fallback to sudo apt-get when raptd is not running.
NULL

#' Check if sudo fallback is allowed
#' @noRd
can_use_sudo <- function() {
    # Explicit option takes precedence
    if (isTRUE(getOption("rapt.sudo"))) {
        return(TRUE)
    }

    # In interactive mode, we can prompt
    if (interactive()) {
        return(TRUE)
    }

    FALSE
}

#' Convert R package names to deb package names
#' @noRd
r_to_deb <- function(pkgs) {
    paste0("r-cran-", tolower(pkgs))
}

#' Fallback install via sudo
#' @noRd
fallback_install <- function(pkgs) {
    if (!can_use_sudo()) {
        warning("raptd not available and sudo fallback disabled. ",
                "Set options(rapt.sudo = TRUE) to enable.")
        return(invisible(FALSE))
    }

    deb_pkgs <- r_to_deb(pkgs)
    args <- c("apt-get", "install", "-y", deb_pkgs)

    message("raptd not available, falling back to sudo")
    status <- system2("sudo", args)

    if (status != 0) {
        warning("sudo apt-get install failed with status ", status)
        return(invisible(FALSE))
    }

    invisible(TRUE)
}

#' Fallback remove via sudo
#' @noRd
fallback_remove <- function(pkgs) {
    if (!can_use_sudo()) {
        warning("raptd not available and sudo fallback disabled. ",
                "Set options(rapt.sudo = TRUE) to enable.")
        return(invisible(FALSE))
    }

    deb_pkgs <- r_to_deb(pkgs)
    args <- c("apt-get", "remove", "-y", deb_pkgs)

    message("raptd not available, falling back to sudo")
    status <- system2("sudo", args)

    if (status != 0) {
        warning("sudo apt-get remove failed with status ", status)
        return(invisible(FALSE))
    }

    invisible(TRUE)
}
