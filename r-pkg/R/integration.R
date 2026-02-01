#' @title Hook into install.packages()
#' @name integration
#' @description Enable/disable automatic apt installation for R packages.
NULL

# Store original install.packages function
.rapt_env <- new.env(parent = emptyenv())

#' Enable rapt integration
#'
#' Hooks into \code{install.packages()} to automatically use apt for
#' packages available in the system repository.
#'
#' @return Invisible NULL.
#' @export
enable <- function() {
    if (isTRUE(getOption("rapt.enabled"))) {
        message("rapt already enabled")
        return(invisible(NULL))
    }

    # Store original
    .rapt_env$original_install.packages <- utils::install.packages

    # Create wrapper
    wrapped <- function(pkgs, lib = NULL, repos = getOption("repos"), ...) {
        # Only intercept if using default lib location
        if (is.null(lib)) {
            lib <- .libPaths()[1]
        }

        # Check which packages are available via apt
        sys_avail <- available_as_sys(pkgs)

        if (any(sys_avail)) {
            sys_pkgs <- pkgs[sys_avail]
            other_pkgs <- pkgs[!sys_avail]

            message("Installing via apt: ", paste(sys_pkgs, collapse = ", "))
            install_sys(sys_pkgs)

            # Install remaining via CRAN
            if (length(other_pkgs) > 0) {
                message("Installing via CRAN: ", paste(other_pkgs, collapse = ", "))
                .rapt_env$original_install.packages(other_pkgs, lib = lib,
                                                     repos = repos, ...)
            }
        } else {
            # No system packages available, use original
            .rapt_env$original_install.packages(pkgs, lib = lib,
                                                 repos = repos, ...)
        }
    }

    # Replace install.packages in utils namespace
    unlock <- unlockBinding("install.packages", asNamespace("utils"))
    assign("install.packages", wrapped, envir = asNamespace("utils"))
    if (unlock) lockBinding("install.packages", asNamespace("utils"))

    options(rapt.enabled = TRUE)
    message("rapt enabled - install.packages() will use apt when possible")
    invisible(NULL)
}

#' Disable rapt integration
#'
#' Restores the original \code{install.packages()} function.
#'
#' @return Invisible NULL.
#' @export
disable <- function() {
    if (!isTRUE(getOption("rapt.enabled"))) {
        message("rapt not enabled")
        return(invisible(NULL))
    }

    if (is.null(.rapt_env$original_install.packages)) {
        warning("Original install.packages not found")
        return(invisible(NULL))
    }

    # Restore original
    unlock <- unlockBinding("install.packages", asNamespace("utils"))
    assign("install.packages", .rapt_env$original_install.packages,
           envir = asNamespace("utils"))
    if (unlock) lockBinding("install.packages", asNamespace("utils"))

    .rapt_env$original_install.packages <- NULL
    options(rapt.enabled = FALSE)
    message("rapt disabled - install.packages() restored to original")
    invisible(NULL)
}
