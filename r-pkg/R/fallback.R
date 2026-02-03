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

#' Convert R package names to deb package names
#' @noRd
r_to_deb <- function(pkgs) {
    paste0("r-cran-", tolower(pkgs))
}

#' Fallback install via sudo
#' @noRd
fallback_install <- function(pkgs) {
    if (!can_use_fallback()) {
        warning("raptd not available and apt fallback disabled. ",
                "Set options(rapt.sudo = TRUE) to enable.")
        return(invisible(FALSE))
    }

    deb_pkgs <- r_to_deb(pkgs)

    message("raptd not available, falling back to ",
            if (is_root()) "direct apt" else "sudo")
    if (is_root()) {
        status <- system2("apt", c("install", "-y", deb_pkgs))
    } else {
        status <- system2("sudo", c("apt", "install", "-y", deb_pkgs))
    }

    if (status != 0) {
        warning("apt install failed with status ", status)
        return(invisible(FALSE))
    }

    invisible(TRUE)
}

#' Fallback remove via sudo
#' @noRd
fallback_remove <- function(pkgs) {
    if (!can_use_fallback()) {
        warning("raptd not available and apt fallback disabled. ",
                "Set options(rapt.sudo = TRUE) to enable.")
        return(invisible(FALSE))
    }

    deb_pkgs <- r_to_deb(pkgs)

    message("raptd not available, falling back to ",
            if (is_root()) "direct apt" else "sudo")
    if (is_root()) {
        status <- system2("apt", c("remove", "-y", deb_pkgs))
    } else {
        status <- system2("sudo", c("apt", "remove", "-y", deb_pkgs))
    }

    if (status != 0) {
        warning("apt remove failed with status ", status)
        return(invisible(FALSE))
    }

    invisible(TRUE)
}
