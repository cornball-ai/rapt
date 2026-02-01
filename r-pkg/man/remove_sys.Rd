% tinyrox says don't edit this manually, but it can't stop you!
\name{remove_sys}
\alias{remove_sys}
\title{Remove system packages via apt}
\usage{
remove_sys(pkgs)
}
\arguments{
\item{pkgs}{Character vector of R package names to remove.}
}
\value{
Invisible \code{TRUE} on success, \code{FALSE} on failure.
}
\description{
Removes R packages using \code{apt-get remove r-cran-*}. Communicates
with the raptd daemon if available, otherwise falls back to sudo.
}
\examples{
\dontrun{
remove_sys("dplyr")
}
}
\seealso{
\code{\link{install_sys}}
}
