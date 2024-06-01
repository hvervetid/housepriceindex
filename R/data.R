#' Transaction data
#'
#' An artificial dataset mimicking property transactions in Berlin.
#'
#' @format An sf data frame with 1,648,823 rows and 6 columns:
#' \describe{
#'   \item{price}{Price of transaction in euro per square meter.}
#'   \item{year}{Year of transaction}
#'   \item{Att_area}{Size of transacted property in square meters.}
#'   \item{Att_balcon}{A dummy for whether the property has a balcony.}
#'   \item{submarket}{An indicator for whether the property is in East Berlin, West Berlin or Rest of Germany}
#'   \item{geometry}{An sf column giving the location of the property as a point.}
#' }
#' @source Gabriel Ahlfeldt,
"example_dataset_transactions"

#' Hexagon data
#'
#' A shapefile of various hexagons covering Berlin.
#'
#' @format An sf data frame with 1953 rows and 2 columns:
#' \describe{
#'   \item{target_id}{The name of the hexagon.}
#'   \item{geometry}{An sf column giving the boundaries of the hexagon.}
#' }
#' @source Gabriel Ahlfeldt,
"example_dataset_hexagons"
