# rapt 0.1.0.1

* `enable()` and `disable()` gained a `verbose` argument, defaulting to option
  `rapt.verbose` (#20, thanks to @eddelbuettel).

* The `/etc/R/profile.d/rapt.R` drop-in is quiet by default. Set
  `RAPT_VERBOSE=TRUE` to restore the startup message.

* Binary packages are published to an apt repository at
  <https://cornball-ai.github.io/rapt> (#17).

# rapt 0.1.0

* Initial release.
