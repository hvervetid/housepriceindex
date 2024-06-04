## code to prepare `DATASET` dataset goes here

library(data.table)
library(stringr)
library(sf)
library(dplyr)
# load postcode
# downloaded from https://www.data.gov.uk/dataset/c1e0176d-59fb-4a8c-92c9-c8b376a80687/code-point-open
postcode = read_sf('/Users/alexanderhansen/Library/Mobile Documents/com~apple~CloudDocs/Academia/programming/housepriceindex_raw/codepo_gpkg_gb/Data/codepo_gb.gpkg')
postcode = select(postcode, postcode, geometry)

# Load transactions
# downloaded from https://www.gov.uk/government/statistical-data-sets/price-paid-data-downloads on June 3rd 2024. Crown Copyright etc.
#
transaction = fread('/Users/alexanderhansen/Library/Mobile Documents/com~apple~CloudDocs/Academia/programming/housepriceindex_raw/pp-complete.csv')

transaction = transaction[, c('V1', 'V2', 'V3', 'V4', 'V6', 'V13', 'V14')]
names(transaction) <- c('id', 'price', 'transaction_date', 'postcode','newbuilt','local_authority','county')
transaction[, year := as.numeric(stringr::str_sub(transaction_date, 1, 4))]
transaction[, Att_newbuilt := ifelse(newbuilt=='Y',1,0)]
transaction = transaction[year > 2014 & year < 2019 & county == 'GREATER LONDON',]
southern = c('BEXLEY', 'GREENWICH','BROMLEY','LEWISHAM','CROYDON','SOUTHWARK',
             'LAMBETH','SUTTON','MERTON','WANDSWORTH','KINGSTON UPON THAMES', 'RICHMOND UPON THAMES')
transaction[, submarket := ifelse(local_authority %in% southern, 2, 1)]

transaction = left_join(transaction, postcode, by = 'postcode')

transaction = select(transaction, price, Att_newbuilt, year, submarket, geometry)
example_dataset_transactions = st_as_sf(transaction, crs = 27700)
example_dataset_transactions = filter(example_dataset_transactions, st_is_empty(example_dataset_transactions)==F)
example_dataset_transactions = st_transform(example_dataset_transactions, crs = 4326)
# set crs
usethis::use_data(example_dataset_transactions, overwrite = TRUE)

# Load wards of London
# downloaded here https://data.london.gov.uk/dataset/statistical-gis-boundary-files-london
ldward = read_sf('/Users/alexanderhansen/Library/Mobile Documents/com~apple~CloudDocs/Academia/programming/housepriceindex_raw/London_Ward.shp')

innerlondon = c('Camden', 'City and County of the City of London', 'City of Westminster', 'Camden',
                'Greenwich', 'Hackney', 'Hammersmith and Fulham', 'Islington', 'Kensington and Chelsea', 'Lambeth',
                'Lewisham', 'Southwark', 'Tower Hamlets', 'Wandsworth')
ldward = filter(ldward, DISTRICT %in% innerlondon)
ldward$target_id = ldward$GSS_CODE
ldward = select(ldward, NAME, target_id, DISTRICT, geometry)
example_dataset_wards = ldward
example_dataset_wards = st_transform(example_dataset_wards, crs = 4326)
usethis::use_data(example_dataset_wards, overwrite=TRUE)
