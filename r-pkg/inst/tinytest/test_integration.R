# Test enable/disable integration

# Initially not enabled
expect_false(isTRUE(getOption("rapt.enabled")))

# Enable
enable()
expect_true(isTRUE(getOption("rapt.enabled")))

# Double enable should message, not error
expect_message(enable(), "already enabled")

# Disable
disable()
expect_false(isTRUE(getOption("rapt.enabled")))

# Double disable should message, not error
expect_message(disable(), "not enabled")

# Enable/disable cycle should restore original
orig <- utils::install.packages
enable()
disable()
expect_identical(utils::install.packages, orig)
