% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{experimentMatToDf}
\alias{experimentMatToDf}
\title{Helper transform experiment matrix to data frame}
\usage{
experimentMatToDf(mat)
}
\arguments{
\item{mat}{Matrix}
}
\value{
Data frame representation of \code{mat}.
}
\description{
Function transpose \code{mat} and inserts column names of input \code{mat} as
a 'ID' column.
}
