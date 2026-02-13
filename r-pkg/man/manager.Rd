% tinyrox says don't edit this manually, but it can't stop you!
\name{manager}
\alias{manager}
\title{Get rapt status and configuration}
\usage{
manager()
}
\value{
A list with components:
\describe{
  \item{daemon_available}{Logical; is the raptd daemon running?}
  \item{socket_path}{Character; path to the Unix socket.}
  \item{sudo_allowed}{Logical; is sudo fallback enabled?}
  \item{enabled}{Logical; is the install.packages() hook active?}
  \item{cache_age}{Numeric; cache age in seconds (Inf if never refreshed).}
}
}
\description{
Returns information about the current rapt configuration, daemon
status, and cache age.
}
\examples{
manager()
}
