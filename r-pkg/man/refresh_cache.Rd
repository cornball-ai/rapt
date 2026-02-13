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
Updates the apt index and refreshes the cached mapping between R
package names and their apt package names. Discovers all
\code{r-<repo>-<pkg>} packages (CRAN, Bioconductor, and any other
registered repositories).
}
\examples{
\dontrun{
refresh_cache()
}
}
