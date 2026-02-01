% tinyrox says don't edit this manually, but it can't stop you!
\name{enable}
\alias{enable}
\title{Enable rapt integration}
\usage{
enable()
}
\value{
Invisible \code{NULL}.
}
\description{
Hooks into \code{install.packages()} to automatically use apt for
packages available in the r2u repository. When enabled, calls to
\code{install.packages()} will:
\enumerate{
\item Check which requested packages are available via apt
\item Install those packages via \code{install_sys()}
\item Install remaining packages from CRAN as usual
}
This is called automatically at startup when rapt is installed via
the Debian package (added to \code{/etc/R/Rprofile.site}).
}
\examples{
\dontrun{
enable()
install.packages("dplyr")
#> Installing via apt: dplyr
}
}
\seealso{
\code{\link{disable}}, \code{\link{manager}}
}
