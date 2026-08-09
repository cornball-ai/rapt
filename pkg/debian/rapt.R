## Enable rapt if installed.
##
## Quiet by default, as a system-wide hook should not announce itself in every
## session. Set RAPT_VERBOSE=TRUE to hear about it. An environment variable
## rather than an option, because R reads ~/.Renviron before any profile file,
## so this stays settable without root.
if (requireNamespace("rapt", quietly = TRUE))
    rapt::enable(verbose = identical(toupper(Sys.getenv("RAPT_VERBOSE", "FALSE")), "TRUE"))
