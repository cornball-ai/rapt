% tinyrox says don't edit this manually, but it can't stop you!
\name{enable}
\alias{enable}
\title{Enable rapt integration}
\usage{
enable(verbose = getOption("rapt.verbose", TRUE))
}
\arguments{
\item{verbose}{logical with default value supplied by option
\sQuote{rapt.verbose} with a fallback of \sQuote{TRUE} to suppress
a message from this function.}
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
}
\details{
This is called automatically at startup when rapt is installed via
the Debian package (via \code{/etc/R/profile.d/rapt.R}).

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
