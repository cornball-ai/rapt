# Store original install.packages function
.rapt_env <- new.env(parent = emptyenv())

#' Enable rapt integration
#'
#' Hooks into \code{install.packages()} to automatically use apt for
#' packages available in the r2u repository. When enabled, calls to
#' \code{install.packages()} will:
#' \enumerate{
#'   \item Check which requested packages are available via apt
#'   \item Install those packages via \code{install_sys()}
#'   \item Install remaining packages from CRAN as usual
#' }
#'
#' This is called automatically at startup when rapt is installed via
#' the Debian package (via \code{/etc/R/profile.d/rapt.R}).
#'
#' @return Invisible \code{NULL}.
#' @examples
#' \dontrun{
#' enable()
#' install.packages("dplyr")
#' #> Installing via apt: dplyr
#' }
#' @seealso \code{\link{disable}}, \code{\link{manager}}
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
    ns <- asNamespace("utils")
    was_locked <- bindingIsLocked("install.packages", ns)
    if (was_locked) unlockBinding("install.packages", ns)
    assign("install.packages", wrapped, envir = ns)
    if (was_locked) lockBinding("install.packages", ns)

    options(rapt.enabled = TRUE)
    message("rapt enabled - install.packages() will use apt when possible")
    invisible(NULL)
}

#' Disable rapt integration
#'
#' Restores the original \code{install.packages()} function so packages
#' are installed from CRAN instead of apt.
#'
#' @return Invisible \code{NULL}.
#' @examples
#' \dontrun{
#' disable()
#' install.packages("dplyr")  # Now compiles from CRAN
#' }
#' @seealso \code{\link{enable}}
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
    ns <- asNamespace("utils")
    was_locked <- bindingIsLocked("install.packages", ns)
    if (was_locked) unlockBinding("install.packages", ns)
    assign("install.packages", .rapt_env$original_install.packages, envir = ns)
    if (was_locked) lockBinding("install.packages", ns)

    .rapt_env$original_install.packages <- NULL
    options(rapt.enabled = FALSE)
    message("rapt disabled - install.packages() restored to original")
    invisible(NULL)
}
