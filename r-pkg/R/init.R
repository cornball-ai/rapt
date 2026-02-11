
.onLoad <- function(libname, pkgname) {
    if (is_root()) {
        system2("apt", "update -qq")
        refresh_cache()
    }
}
