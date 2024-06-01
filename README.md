
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
And then load it in the standard way by calling 
``` r
library(housepriceindex)
```

## Example

A very typical usercase: you have a list of property transactions and a list of spatial units (say, hexagons).
You then find the centroids of the hexagons and calculate the index at each centroid. 


``` r
### Load packages 
library(housepriceindex)
library(sf)

### Load data.
## The package comes with two example datasets to easily run it, e
hexagons <- example_dataset_hexagons   
transactions <- example_dataset_transactions

### Find centroids of hexagons and use them.
hexagon_centroids <- sf::st_centroid(hexagons)

### Run the index 
index <- calculate_index(hexagon_centroids, transactions, observations_outer = 5000, observations_inner = 500)

# Does it not work? Try typing ?calculate_index in console and read through the documentation 
```
In this case, you calculate the index for a single point and assume that it is representative across the whole hexagon. If the hexagons are large, it may be a good idea to create several points within each hexagon. 
