% tinyrox says don't edit this manually, but it can't stop you!
\name{available_sys}
\alias{available_sys}
\title{List available system packages}
\usage{
available_sys()
}
\value{
Character vector of R package names available via apt
  (without prefix).
}
\description{
Returns R package names available via apt, including both
\code{r-cran-*} and \code{r-bioc-*} packages from r2u.
Results are cached for one hour (configurable via
\code{options(rapt.cache_ttl)}).
}
\examples{
\dontrun{
available_sys()
"dplyr" \%in\% available_sys()
}
}
\seealso{
\code{\link{install_sys}}, \code{\link{refresh_cache}}
}
