
# housepriceindex

<!-- badges: start -->
[![R-CMD-check](https://github.com/hvervetid/housepriceindex/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/hvervetid/housepriceindex/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

The goal of housepriceindex is to provide an easy way to calculate a house price index based on transactions. It incorporates both time, geography, and housing characteristics. 

## The algorithm
The underlying algorithm is strongly based on G. Ahlfeldt, S. Heblich, T. Seidel (2023): Micro-geographic property price and rent indices. Regional Science and Urban Economics, 98. https://doi.org/10.1016/j.regsciurbeco.2022.103836, and the interested reader is referred to this article to understand the underlying econometrics. A few modifications have been made, notably to dispense with the deterministic radius of outer and inner circles in favour of flexibly fitting the circle to hit a desired number of observations of the outer and inner ring. 

## What parameters should I choose? 
As user, you need to decide on at least two parameters: how many observations to target for the outer ring and the inner ring.

The outer ring determines which observations will enter the regression for a given target. If the outer ring has radius of 4 kilometer, then any transaction happening more than 4 kilometers from the target will not be used to calculate the index at that target.

Meanwhile, the inner ring is used to calculate a fixed effect around the target. This will capture, say, location-specific amenities such as a nice park. 

Depending on how many transactions you have, setting the observations_outer parameter to about 5% of all transactions and observations_inner to about 0.5% is a reasonable first guess. However, you don't want the numbers to be too low: again, as a pure rule of thumb, you probably don't want the observations_inner to be below 500. 
## Installation

You can install the development version of housepriceindex by running:

``` r
devtools::install_github('hvervetid/housepriceindex')
```

## Example

A very typical usercase: you have a list of property transactions and a list of spatial units (say, municipalities).
You then find the centroids of the municipalities and calculate the index at each centroid. 


``` r
### Load packages 
library(sf)
library(housepriceindex)

### Load data
municipalities <- read_sf('municipalities.shp')    
transactions <- read_sf('transactions.shp')

### Prepare list of spatial units
municipal_centroids <- st_centroid(municipalities)
municipal_centroids$target_id <- municipalities$your_name_variable  ## the target dataset must have a column named 'target_id'.

### Prepare list of transactions 
## the transaction dataset must have a column named 'price'.
transactions$price = transactions$your_price_variable 
## the transaction dataaset must have a column named 'year'. 
# If you do not have time variation in the dataset, just write transactions$year <- 1
transactions$year <- transactions$your_year_variable 
## the transaction dataset must have a column named 'submarket'. 
# If you want all transactions to be within the same submarket, just write transactions$submarket <- 1
transactions$submarket <- transactions$your_market_variable 
## If you want to include house characeristics in the regression (e.g. a dummy for the property being a flat), ensure the variable begins with 'Att_'
# If the variable should enter as a factor (e.g. Att_type where 1=semi-detached house, 2=detached house and 3=flat), ensure that is formatted as such by wrapping the right-hand side in as.factor().
transactions$Att_flatdummy <- transactions$is_the_property_a_flat 

### Run the index 
index <- calculate_index(municipal_centroids, transactions, observations_outer = 5000, observations_inner = 500)

# Does it not work? Try typing ?calculate_index in console and read through the documentation 
```
In this case, you calculate the index for a single point and assume that it is representative across the whole municipality. If the municipalities vary a lot in size or density, it may be a good idea to make several points within each municipality and average across them to get to a municipal-wide index. 
