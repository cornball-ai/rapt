% tinyrox says don't edit this manually, but it can't stop you!
\name{available_sys}
\alias{available_sys}
\title{List available system packages}
\usage{
available_sys()
}
\value{
Character vector of R package names available via apt
  (without the \code{r-cran-} prefix).
}
\description{
Queries \code{apt-cache} for available \code{r-cran-*} packages.
Does not require the raptd daemon.
}
\examples{
\dontrun{
available_sys()
"dplyr" \%in\% available_sys()
}
}
\seealso{
\code{\link{install_sys}}
}
