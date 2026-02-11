% tinyrox says don't edit this manually, but it can't stop you!
\name{destroy_cache}
\alias{destroy_cache}
\title{Destroy the package cache}
\usage{
destroy_cache()
}
\value{
Invisible \code{NULL}.
}
\description{
Clears the cached mapping between R package names and apt package
names, freeing memory. The cache will be rebuilt on the next call
to \code{\link{available_sys}} or \code{\link{install_sys}}.
}
\examples{
\dontrun{
destroy_cache()
}
}
\seealso{
\code{\link{refresh_cache}}
}
