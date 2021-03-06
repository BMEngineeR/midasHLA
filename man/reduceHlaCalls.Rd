% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/transformationFunctions.R
\name{reduceHlaCalls}
\alias{reduceHlaCalls}
\title{Reduce HLA calls resolution}
\usage{
reduceHlaCalls(hla_calls, resolution = 4)
}
\arguments{
\item{hla_calls}{HLA calls data frame, as returned by
\code{\link{readHlaCalls}} function.}

\item{resolution}{Number specifying desired resolution.}
}
\value{
HLA calls data frame reduced to specified resolution.
}
\description{
\code{reduceHlaCalls} reduces HLA calls data frame to specified resolution.
}
\details{
Alleles with resolution greater than \code{resolution} or optional suffixes
are returned unchanged.
}
\examples{
reduceHlaCalls(MiDAS_tut_HLA, resolution = 2)

}
