
.onLoad <- function(libname, pkgname) {
    if (isTRUE(getOption("rapt.enabled"))) {
        if (is_root()) {
            system2("apt", "update -qq")
            refresh_cache()
        } else if (isTRUE(getOption("rapt.sudo"))) {
            system2("sudo", "apt update -qq")
            refresh_cache()
        }
    }
}
