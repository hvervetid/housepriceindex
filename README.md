
# housepriceindex

<!-- badges: start -->
[![R-CMD-check](https://github.com/hvervetid/housepriceindex/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/hvervetid/housepriceindex/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

The goal of housepriceindex is to ...

## Installation

You can install the development version of housepriceindex by running:

``` r
devtools::install_github('hvervetid/housepriceindex')
```

## Example

A very typical usercase: you have a list of property transactions and a list of spatial units (say, municipalities).
You then find the centroids of the municipalities and calculate the index at each centroid. 


``` r
# Load packages 
library(sf)
library(housepriceindex)

# Load data
municipalities <- read_sf('municipalities.shp')    
transactions <- read_sf('transactions.shp')

# Prepare list of spatial units
municipal_centroids <- st_centroid(municipalities)
municipal_centroids$target_id <- municipalities$your_name_variable  ## the target dataset must have a column named 'target_id'.

# Prepare list of transactions 
transactions$price = transactions$your_price_variable ## the transaction dataset must have a column named 'price'.
transactions$year <- transactions$your_year_variable ## the transaction dataaset must have a column named 'year'. If you do not have time variation in the dataset, just write transactions$year <- 1
transactions$submarket <- transactions$your_market_variable ## the transaction dataset must have a column named 'submarket'. If you want all transactions to be within the same submarket, just write transactions$submarket <- 1

# Run the index 
index <- calculate_index(municipal_centroids, transactions, observations_outer = 5000, observations_inner = 500)

# Does it not work? Try typing ?calculate_index in console and read through the documentation 
```
In this case, you calculate the index for a single point and assume that it is representative across the whole municipality. If the municipalities vary a lot in size or density, it may be a good idea to make several points within each municipality and average across them to get to a municipal-wide index. 
