
# housepriceindex

<!-- badges: start -->
[![R-CMD-check](https://github.com/hvervetid/housepriceindex/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/hvervetid/housepriceindex/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

The goal of housepriceindex is to provide an easy way to calculate a house price index based on transactions that incorporates both time, geography, and housing characteristics. The package provides a single user-end function called calculate_index(). The package also includes two shapefiles of example transactions and targets to illustrate its workings.

## The algorithm
The underlying algorithm is strongly based on G. Ahlfeldt, S. Heblich, T. Seidel (2023): Micro-geographic property price and rent indices. Regional Science and Urban Economics, 98. https://doi.org/10.1016/j.regsciurbeco.2022.103836, and the interested reader is referred to this article to understand the underlying econometrics. A few modifications have been made, notably to dispense with the deterministic radius of outer and inner circles in favour of flexibly fitting the circle to hit a desired number of observations of the outer and inner ring. 

## What parameters should I choose? 
As user, you need to decide on at least two parameters: how many observations to target for the outer ring and the inner ring.

The outer ring determines which observations will enter the regression for a given target. If the outer ring has radius of 4 kilometer, then any transaction happening more than 4 kilometers from the target will not be used to calculate the index at that target.

Meanwhile, the inner ring is used to calculate a fixed effect around the target. This will capture, say, location-specific amenities such as a nice park. 

Depending on how many transactions you have, setting the observations_outer parameter to about 5% of all transactions and observations_inner to about 0.5% is a reasonable first guess. However, you don't want the numbers to be too low: again, as a pure rule of thumb, you probably don't want the observations_inner to be below 500. 

There are also three other parameters you may set: 
* max_radius_outer: Sets a maximal radius that the outer ring can take. The default value is 20 kilometers. 
* max_radius_inner: Sets a maximal radius that the inner ring can take. The default value is 10 kilometers. 
* debug: If set to TRUE, more detailed reports on the workings of the func



## Installation
To install the development version of housepriceindex, you must first install and load the devtools package:

``` r
install.pacakges('devtools')
library(devtools)
```
You may then install and load it by running:
``` r
devtools::install_github('hvervetid/housepriceindex')
library(housepriceindex)
```

## How to format your datasets 

For the index to work as intended, it is imperative that you structure the input data frames as follows: 
* Targets
    * There must be a column named 'target_id' with *distinct* names for each target. This could be a unique name, id, row identifier etc.
    * There must be EITHER 
        a) an sf column named 'geometry' with a POINT for each target and known coordinate reference system (CRS)
        b) Two columns named 'target_X' and 'target_Y' showing the X and Y position of the target in projected meters. 
* Transactions
    * There must be a column named 'year'. If all transactions take place in the same period, make a column with year=1.
    * There must be a column named 'submarket'. If all transactions take place in the same *continuous* market, make a column with submarket=1. 
    * There must be a column named 'price'. The price should be in nominal currency. It can be either per unit of floorspace or for the whole property. The final index will be in the same unit. 
    * If you want observable attributes to be included in the regression, please name them 'Att_*' with the asterisk being an arbitrary name. By default, attributes will be included under the assumption of a log-linear relationship with price. If the attributes should enter as categorical variables, please format the column appropriately using as.factor(Att_*) first. If the attributes should enter as polynomials, create separate columns for each power. 
    * There must be EITHER 
        a) an sf column named 'geometry' with a POINT for each transaction and known coordinate reference system (CRS)
        b) Two columns named 'origin_X' and 'origin_Y' showing the X and Y position of the target in projected meters. 
    
We strongly recommend that the two datasets are in the same format: either both are SF dataframes or both are in projected meters using the same CRS. 

## Example

A very typical usercase: you have a list of property transactions and a list of spatial units (say, UK wards).
You then find the centroids of the wards and calculate the index at each centroid. 


``` r
### Load packages 
library(housepriceindex)
library(sf)

### Load data
## The package comes with two example datasets to easily test the index:
wards <- example_dataset_wards   
transactions <- example_dataset_transactions

### Find centroids of hexagons to use as the targets
ward_centroids <- sf::st_centroid(wards)

### Run the index 
index <- calculate_index(ward_centroids, transactions, observations_outer = 5000, observations_inner = 500)

## Produce a quick map of the index in 2015 to see what it looks like 
index <- index[index$year==2015]
wards <- merge(wards, index, by = 'target_id')

library(ggplot2)
ggplot() + geom_sf(data=wards, aes(fill=price))
```
In this case, you calculate the index for a single point and assume that it is representative across the whole hexagon. If the hexagons are large, it may be a good idea to create several points within each hexagon. 

The example datasets are publicly available property transactions in Greater London in 2015-2018, geolocated by postcode, as well as a list of wards in City of London and Inner London boroughs. Postcodes were geolocated using the publicly available Code-Point Open geodatapackage. See data description by running ?example_dataset_wards and ?example_dataset_transactions for further details.  

Contains HM Land Registry data © Crown copyright and database right 2021. This data is licensed under the Open Government Licence v3.0. 

Contains OS data © Crown copyright and database right 2020 Contains Royal Mail data © Royal Mail copyright and Database right 2020 Contains National Statistics data © Crown copyright and database right 2020
