% tinyrox says don't edit this manually, but it can't stop you!
\name{disable}
\alias{disable}
\title{Disable rapt integration}
\usage{
disable(verbose = getOption("rapt.verbose", TRUE))
}
\arguments{
\item{verbose}{logical controlling whether this function reports what
it did, defaulting to option \sQuote{rapt.verbose} and to \sQuote{TRUE}
when that option is unset. Set to \sQuote{FALSE} for silence.}
}
\value{
Invisible \code{NULL}.
}
\description{
Restores the original \code{install.packages()} function so packages
are installed from CRAN instead of apt.
}
\examples{
\dontrun{
disable()
install.packages("dplyr")  # Now compiles from CRAN
}
}
\seealso{
\code{\link{enable}}
}
