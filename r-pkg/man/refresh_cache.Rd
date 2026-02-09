% tinyrox says don't edit this manually, but it can't stop you!
\name{refresh_cache}
\alias{refresh_cache}
\title{Refresh the package cache}
\usage{
refresh_cache()
}
\value{
Invisible \code{NULL}.
}
\description{
Forces a refresh of the cached mapping between R package names and
their apt package names. Call this after \code{apt update} to pick
up newly available packages.
}
\examples{
\dontrun{
refresh_cache()
}
}
