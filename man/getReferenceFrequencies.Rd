% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{getReferenceFrequencies}
\alias{getReferenceFrequencies}
\title{Helper transforming reference frequencies}
\usage{
getReferenceFrequencies(ref, pop, carrier_frequency = FALSE)
}
\arguments{
\item{ref}{Long format data frame with three columns "var", "population",
"frequency".}

\item{pop}{Character giving names of populations to include}

\item{carrier_frequency}{Logical indicating if carrier frequency should be
returned instead of frequency. Carrier frequency is calculated based on
Hardy-Weinberg equilibrium model.}
}
\value{
Wide format data frame with population frequencies as columns.
}
\description{
Helper transforming reference frequencies
}
