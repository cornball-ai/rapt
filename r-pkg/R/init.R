
.onLoad <- function(libname, pkgname) {
    system("apt-get update -qq")
    refresh_cache()
}
