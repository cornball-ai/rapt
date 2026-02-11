# Test manager functions

# Test validate_pkgs
expect_equal(
    rapt:::validate_pkgs(c("dplyr", "ggplot2")),
    c("dplyr", "ggplot2")
)

expect_equal(
    rapt:::validate_pkgs(c("dplyr", "dplyr")),
    "dplyr"
)

expect_equal(
    rapt:::validate_pkgs(character(0)),
    character(0)
)

# Invalid names should warn and be removed
expect_warning(
    result <- rapt:::validate_pkgs(c("good", "bad;name", "also-bad")),
    "Invalid package names"
)
expect_equal(result, "good")

# Test manager() returns expected structure
info <- manager()
expect_true(is.list(info))
expect_true("daemon_available" %in% names(info))
expect_true("socket_path" %in% names(info))
expect_true("sudo_allowed" %in% names(info))
expect_true("enabled" %in% names(info))
expect_true("cache_age" %in% names(info))

# === Cache tests ===

# Cache is primed on load
expect_true(manager()$cache_age < 5)

if (Sys.which("apt-cache") != "") {

    # available_sys() returns character vector without prefixes
    avail <- available_sys()
    expect_true(is.character(avail))
    expect_true(length(avail) > 0)
    expect_false(any(grepl("^r-cran-", avail)))
    expect_false(any(grepl("^r-bioc-", avail)))

    # r_to_deb - cran packages
    expect_equal(rapt:::r_to_deb("dplyr"), "r-cran-dplyr")
    expect_equal(rapt:::r_to_deb("Rcpp"), "r-cran-rcpp")
    expect_equal(
        rapt:::r_to_deb(c("dplyr", "Rcpp")),
        c("r-cran-dplyr", "r-cran-rcpp")
    )

    # r_to_deb - unknown packages default to r-cran-
    expect_equal(rapt:::r_to_deb("nonexistentpkg"), "r-cran-nonexistentpkg")

    # r_to_deb returns correct prefix for bioc packages
    bioc_debs <- system2("apt-cache", c("pkgnames", "r-bioc-"),
                         stdout = TRUE, stderr = NULL)
    if (length(bioc_debs) > 0) {
        bioc_r_name <- sub("^r-bioc-", "", bioc_debs[1])
        result <- rapt:::r_to_deb(bioc_r_name)
        expect_true(grepl("^r-bioc-", result),
                    info = paste("Expected r-bioc- prefix for", bioc_r_name,
                                 "but got", result))
    }

    # Second call to available_sys should be instant (cached)
    t0 <- proc.time()["elapsed"]
    avail2 <- available_sys()
    t1 <- proc.time()["elapsed"]
    expect_true((t1 - t0) < 0.1,
                info = "cached available_sys() should be near-instant")
    expect_equal(avail, avail2)
}

# === Edge cases ===

# Package names with dots
expect_equal(
    rapt:::validate_pkgs("data.table"),
    "data.table"
)

# Package names with numbers
expect_equal(
    rapt:::validate_pkgs("R6"),
    "R6"
)

# Injection attempts - semicolons
expect_warning(
    result <- rapt:::validate_pkgs("foo;rm -rf /"),
    "Invalid"
)
expect_equal(result, character(0))

# Injection attempts - backticks
expect_warning(
    result <- rapt:::validate_pkgs("foo`whoami`"),
    "Invalid"
)
expect_equal(result, character(0))

# Injection attempts - dollar signs
expect_warning(
    result <- rapt:::validate_pkgs("foo$HOME"),
    "Invalid"
)
expect_equal(result, character(0))

# Injection attempts - pipes
expect_warning(
    result <- rapt:::validate_pkgs("foo|cat /etc/passwd"),
    "Invalid"
)
expect_equal(result, character(0))

# Injection attempts - newlines
expect_warning(
    result <- rapt:::validate_pkgs("foo\nrm -rf /"),
    "Invalid"
)
expect_equal(result, character(0))

# Empty strings filtered out
expect_equal(
    rapt:::validate_pkgs(c("good", "", "also_good")),
    c("good", "also_good")
)

# Underscores are valid
expect_equal(
    rapt:::validate_pkgs("some_package"),
    "some_package"
)

# All empty input
expect_equal(
    rapt:::validate_pkgs(c("", "")),
    character(0)
)

# Non-character input
expect_error(
    rapt:::validate_pkgs(123),
    "character"
)

expect_error(
    rapt:::validate_pkgs(NULL),
    "character"
)
