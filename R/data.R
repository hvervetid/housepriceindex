#' Transaction data
#'
#' Geolocated property transactions in Greater London in 2015 to 2018.
#'
#' @format An sf data frame with 481,159 rows and 5 columns:
#' \describe{
#'   \item{price}{Price of transaction in pounds.}
#'   \item{year}{Year of transaction}
#'   \item{Att_newbuilt}{A dummy for whether the property is newbuilt}
#'   \item{submarket}{Submarket 2 is all properties south of the Thames, submarket 1 is all properties north of the Thames}
#'   \item{geometry}{An sf column giving the location of the property as a point.}
#' }
#' @source HM Land Registry's Price Paid Data (\url{https://www.gov.uk/government/collections/price-paid-data}). Ordnance Survey's Code Point open (\url{https://www.data.gov.uk/dataset/c1e0176d-59fb-4a8c-92c9-c8b376a80687/code-point-open})
"example_dataset_transactions"

#' Ward data
#'
#' A shapefile of wards in Inner London
#'
#' @format An sf data frame with 253 rows and 4 columns:
#' \describe{
#'   \item{NAME}{The name of the ward.}
#'   \item{target_id}{The ID of the ward.}
#'   \item{DISTRICT}{The district to which the ward belongs.}
#'   \item{geometry}{An sf column giving the boundaries of the ward}
#' }
#' @source Greater London Authority's DataStore, manipulated by Alexander Hansen. Open Govenrment License v2. \url{https://data.london.gov.uk/dataset/statistical-gis-boundary-files-london}
"example_dataset_wards"
