% tinyrox says don't edit this manually, but it can't stop you!
\name{install_sys}
\alias{install_sys}
\title{Install system packages via apt}
\usage{
install_sys(pkgs)
}
\arguments{
\item{pkgs}{Character vector of R package names to install (e.g., "dplyr").}
}
\value{
Invisible \code{TRUE} on success, \code{FALSE} on failure.
}
\description{
Installs R packages using apt. Communicates with the raptd daemon
if available, otherwise falls back to sudo. Supports both
\code{r-cran-*} and \code{r-bioc-*} packages from r2u.
}
\examples{
\dontrun{
install_sys("dplyr")
install_sys(c("ggplot2", "data.table"))
}
}
\seealso{
\code{\link{remove_sys}}, \code{\link{available_sys}}
}
