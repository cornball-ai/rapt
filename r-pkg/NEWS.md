# rapt 0.1.2

* The apt repository is laid out per suite rather than flat, so a client is
  only ever offered builds for its own release (#26). Existing `.sources`
  entries need updating from `Suites: ./` to a codename plus
  `Components: main`.

* Binary packages are built for every suite and architecture r2u serves:
  jammy, noble and resolute on amd64, plus noble and resolute on arm64 (#27).

# rapt 0.1.1

* `enable()` and `disable()` gained a `verbose` argument, defaulting to option
  `rapt.verbose` (#20, thanks to @eddelbuettel).

* The `/etc/R/profile.d/rapt.R` drop-in is quiet by default. Set
  `RAPT_VERBOSE=TRUE` to restore the startup message.

* Binary packages are published to an apt repository at
  <https://cornball-ai.github.io/rapt/> (#17).

# rapt 0.1.0

* Initial release.
