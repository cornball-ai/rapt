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

# Test r_to_deb
expect_equal(
    rapt:::r_to_deb("dplyr"),
    "r-cran-dplyr"
)

expect_equal(
    rapt:::r_to_deb("Rcpp"),
    "r-cran-rcpp"
)

expect_equal(
    rapt:::r_to_deb(c("dplyr", "Rcpp")),
    c("r-cran-dplyr", "r-cran-rcpp")
)

# Test manager() returns expected structure
info <- manager()
expect_true(is.list(info))
expect_true("daemon_available" %in% names(info))
expect_true("socket_path" %in% names(info))
expect_true("sudo_allowed" %in% names(info))
expect_true("enabled" %in% names(info))

# Test available_sys (only if apt-cache is available)
if (Sys.which("apt-cache") != "") {
    avail <- available_sys()
    expect_true(is.character(avail))
    # Should not have r-cran- prefix
    expect_false(any(grepl("^r-cran-", avail)))
}

# === Edge cases ===

# Package names with dots
expect_equal(
    rapt:::validate_pkgs("data.table"),
    "data.table"
)
expect_equal(
    rapt:::r_to_deb("data.table"),
    "r-cran-data.table"
)

# Package names with numbers
expect_equal(
    rapt:::validate_pkgs("R6"),
    "R6"
)
expect_equal(
    rapt:::r_to_deb("R6"),
    "r-cran-r6"
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
