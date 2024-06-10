# not sure if these are necessary
if(T==F){
use_package('sf')
use_package('stringr')
use_package('data.table')
use_package('lmtest')
use_package('sandwich')
use_package('foreach')}

# Function to calculate index at single point -----------------------------

# Do to each point
#' Calculate index for a single target point in space
#'
#' @param list_of_targets The dataset containing all targets.
#' @param list_of_transactions The dataset with all transactions.
#' @param max_radius_A The maximal radius in kilometers to be taken by the outer ring.
#' @param A_N The target number of transactions for the outer ring.
#' @param max_radius_T The maximal radius in kilometers to be taken by the inner ring.
#' @param T_N The target number of transactions for the inner ring.
#' @param treatment_vars List of variables containing Attributes to be included in regression.
#' @param id The id of the single target identifying it within the target_id column.
#' @param debug Whether to print messages for debugging.
#'
#' @return A data.table
#' @export
#'
#' @examples
#' #On the way
calculate_index_point = function(list_of_targets, list_of_transactions, A_N, T_N,
                               max_radius_A, max_radius_T, treatment_vars, id, debug){

    # Isolate point
    one_target = list_of_targets[target_id==id,]

    # create spatial trends
    list_of_transactions[, trend_X := one_target$target_X-origin_X]
    list_of_transactions[, trend_Y := one_target$target_Y-origin_Y]

    ## create distance matrix
    list_of_transactions[, dist_km := sqrt(trend_X^2 + trend_Y^2) / 1000]

    # Find out which submarket the point is in
    min_distance = min(list_of_transactions$dist_km)
    relevant_submarket = first(list_of_transactions$submarket[list_of_transactions$dist_km==min_distance])
    list_of_transactions[, not_own_submarket := ifelse(submarket==relevant_submarket, 0, 1)]

    # Find number of transactions
    N <- nrow(list_of_transactions)
    # Find number of years
    N_year <- uniqueN(list_of_transactions, by = 'year')

    # Find radius that hits A_N criterion (multiply percentile with N)
    desired_quantile_A = A_N/N

    # If this is too large relative to number of potential observations, replace it by maximum possible
    if (desired_quantile<0 | desired_quantile_A>1 | is.numeric(desired_quantile_A)==F){desired_quantile_A <- 1}
    radius_A = as.numeric(stats::quantile(list_of_transactions$dist_km, desired_quantile_A))

    # if it's too far out, replace with maximum
    if (radius_A > max_radius_A){radius_A <- max_radius_A}
    # create marker of whether observations are inside or outside
    list_of_transactions[, outside_A := ifelse(dist_km>radius_A, 1, 0)]

    # Keep the observations that are within A
    transactions_subset <- list_of_transactions[outside_A==0,]

    # Find radius that hits T_N criterion
    N_subset = nrow(transactions_subset)
    desired_quantile_T = T_N/N_subset

    # If this is too large relative to number of potential observations, replace it by maximum possible
    if (desired_quantile_T<0 | desired_quantile_T>1 | is.numeric(desired_quantile_T)==F){desired_quantile_T <- 1}

    radius_T = as.numeric(stats::quantile(transactions_subset$dist_km, desired_quantile_T))
    # if it's too far out, replace with maximum
    if (radius_T > max_radius_T){
        radius_T <- max_radius_T
        applied_max <- 1} else {applied_max <- 0}

    # If radius of inner and outer rings are identical, we invoke emergency powers and set inner radius to half of outer
    if (round(radius_T,5)==round(radius_A,5)){
      message(paste('For target id',id, 'inner radius is set to three-quarters of outer radius'))
      radius_T <- 0.75*radius_A}

    # create marker of observations outside inner ring
    transactions_subset[, outside_T := ifelse(dist_km>radius_T, 1, 0)]


    # Run regressions
      formula = stats::reformulate(c(treatment_vars, 'dist_km:yearfactor', 'yearfactor', 'outside_T', 'trend_X', 'trend_Y', 'not_own_submarket:yearfactor', '0'), response = 'lprice')
      reg = stats::lm(formula, data = transactions_subset)

      test = lmtest::coeftest(reg, vcov = vcovCL, cluster = ~outside_T)
      test = as.data.frame(test[,])
      clusteredcoefs = data.table(varname = rownames(test), coefficients = test$Estimate, stderr=test$'Std. Error')

      if (debug){
        message(paste('Coefficient table for target_id', id, 'looks like this:'))
        print(clusteredcoefs)
      }

    # Only keep the coefficients of interest
    coefs = clusteredcoefs[stringr::str_detect(varname, 'yearfactor') & !stringr::str_detect(varname, 'dist') & !stringr::str_detect(varname, 'submarket'),]
    coefs[, year := as.numeric(stringr::str_extract(varname, '[:digit:]+'))]


    # A couple of quick sanity checks
    if (nrow(coefs)!=N_year){
      message('Coefficient table should have exactly one row per year, but instead it looks like this:')
      message(coefs)
      stop('Regression failed. Try increasing max_radius_inner or decreasing observations_inner')}

    # If only one year, remove artificial companion
    coefs = coefs[year != 999999,]

    # create single-observation dataset and save
    tosave = data.table::data.table(
        target_id = one_target$target_id,
        year = coefs$year,
        price = exp(coefs$coefficients),
        price_se = exp(coefs$coefficients + coefs$stderr) - exp(coefs$coefficients),
        lprice = coefs$coefficients,
        lprice_se = coefs$stderr,
        target_X = one_target$target_X,
        target_Y = one_target$target_Y,
        outer_radius_used = radius_A,
        inner_radius_used = radius_T
    )

    return(tosave)

}


# Helper function to demean vars ------------------------------------------

demean_variable <- function(data, var) {
    data[, (var) := get(var) - mean(get(var), na.rm = TRUE)]
}


# Helper function to add regressors together ------------------------------

addregressors <- function(x){
  paste(x, collapse = "+")}


# Helper function to transform proj into meters ---------------------------

#' Transform CRS into correct UTM.
#'
#' @param sf_df An sf dataframe to be transformed
#' @param debug Whether to print debugging messages. Defaults to TRUE
#'
#' @return An sf dataframe in the correct UTM format.
#' @import sf
#' @export
#'
#' @examples
#' #sf_df <- read_sf(xxx)
#' #sf_sf <- transform_crs_to_utm(sf_sf)
transform_crs_to_utm <- function(sf_df, debug=T){

  # First, project into 4326 because that's easier to work with
  sf_df = sf::st_transform(sf_df, crs=4326)

  # Then, find north-west corner of data
  bbox = sf::st_bbox(sf_df)

  # Find out whether corner is north of equator
  n_equator = ifelse(as.numeric(bbox$ymax)>0, TRUE, FALSE)

  # Find out which UTM zone the northwest corner fits into
  UTMzone = ceiling((as.numeric(bbox$xmin)+180)/6)

  # Construct correct UTM Zone EPSG
  if (n_equator==TRUE){
    epsg = as.numeric(paste0(326, UTMzone))
  } else {
    epsg = as.numeric(paste0(327, UTMzone))
  }

  message(paste('..Transforming dataset into CRS', epsg))
  # Transform dataset into metered CRS
  sf_df = sf::st_transform(sf_df, crs = epsg)

  # return dataset
  return(sf_df)
}




# Main function to be run by user -----------------------------------------


#' Calculate house price index
#'
#' The function uses a dataset with transactions and a dataset with a list of targets where
#' the index is to be calculated.
#'
#' @param target_dataset The dataset with all targets. Each target must be a separate row.
#' The dataset must be either an sf dataframe or a dataframe with 'target_X' and 'target_Y' columns in projected meters.
#' It must have a target identifier named 'target_id'.
#' @param transaction_dataset The dataset with all transactions. Each transaction must be a separate row.
#' The dataset must be either an sf dataframe or a dataframe with 'origin_X' and 'origin_Y' columns in projected meters.
#' The dataset must have columns named 'year', 'submarket' and 'price'. Any attributes to be included in the regression as hedonics must be called "Att_xxx", with xxx being replaceable.
#' @param observations_outer The target number of transactions for the outer ring.
#' @param observations_inner The target number of transactions for the inner ring.
#' @param max_radius_outer The maximal radius in kilometers to be taken by the outer ring. Default value 20 km.
#' @param max_radius_inner The maximal radius in kilometers to be taken by the inner ring. Default value 10 km.
#' @param n_cores The number of cores to be used. Default is NULL, meaning that the program will use all but one available cores.
#' @param use_parallel Whether to use parallel processing. Defaults to TRUE. Turning off can be useful for debugging.
#' @param skip_errors Whether to skip problematic targets. Defaults to FALSE, meaning an error will force the function to stop. Changing this parameter makes debugging very hard.
#' @param debug Whether to print all messages for debugging purpose. Defaults to FALSE.
#'
#' @return A single data.table with a row for each year-target pair.
#' @import data.table
#' @import sf
#' @import stringr
#' @import lmtest
#' @import fixest
#' @import sandwich
#' @import foreach
#' @import doParallel
#' @export
#'
#' @examples
#' #transactions <- read_sf(xxx)
#' #targets <- read_sf(yyy)
#' #index = calculate_index(targets, transactions, observations_outer=10000, observations_inner=2000)
calculate_index = function(target_dataset,
                           transaction_dataset,
                           observations_outer,
                           observations_inner,
                           max_radius_outer=20,
                           max_radius_inner=10,
                           n_cores = NULL,
                           use_parallel = T,
                           skip_errors=F,
                           debug=F){

    message('Preparing datasets...')

  # Check whether transactions and targets have same format
  if (class(transaction_dataset)[[1]] != class(target_dataset)[[1]]){
    stop('Transaction and target datasets must be in the same format: either both are sf or both are dataframes with _X and _Y columns.')
  }


  ### Check whether transactions have a good spatial format
  if (class(transaction_dataset)[[1]] == 'sf'){
    if (debug){message('Transforming transactions to projected coordinates in meters...')}

    # Check whether transaction has a CRS
    transaction_crs = sf::st_crs(transaction_dataset, parameters=T)
    if (length(transaction_crs)==2){
      stop('Transaction dataset does not have a CRS. You must give the dataset a CRS or create variables named "origin_X" and "origin_Y" in projected meters.')
      }

    # Check whether transaction CRS is metered.
    transaction_in_meter = stringr::str_detect(transaction_crs$units_gdal, c('metre'))

    # If not metered, find correct CRS and reproject
    if (transaction_in_meter==F){
      transaction_dataset = transform_crs_to_utm(transaction_dataset, debug)
    }

    # Finally, take out coordinates and add as variables. Drop geometry column.
    coords = as.data.table(sf::st_coordinates(transaction_dataset))
    transaction_dataset = sf::st_drop_geometry(transaction_dataset)
    transaction_dataset$origin_X = coords$X
    transaction_dataset$origin_Y = coords$Y
  }


  # Check whether targets have a good spatial format
  if (class(target_dataset)[[1]] == 'sf'){
    if (debug){message('Transforming targets to projected coordinates in meters...')}

    # Check whether target has a CRS
    target_crs = sf::st_crs(target_dataset, parameters=T)
    if (length(target_crs)==2){
      stop('Target dataset does not have a CRS. You must give the dataset a CRS or create variables named "target_X" and "target_Y" in projected meters.')
    }

    # Check whether target CRS is metered.
    target_in_meter = stringr::str_detect(target_crs$units_gdal, c('metre'))

    # If not metered, find correct CRS and reproject
    if (target_in_meter==F){
      target_dataset = transform_crs_to_utm(target_dataset, debug)
    }


    # Finally, take out coordinates and add as variables. Drop geometry column.
    coords = data.table::as.data.table(sf::st_coordinates(target_dataset))
    target_dataset = sf::st_drop_geometry(target_dataset)
    target_dataset$target_X = coords$X
    target_dataset$target_Y = coords$Y
  }



  # convert to datatable
  if (debug){message('Convering transactions and targets to data.table format...')}
  transaction_dataset = data.table::as.data.table(transaction_dataset)
  target_dataset = data.table::as.data.table(target_dataset)

  # Check whether variables are named correctly
  if (debug){message('Checking whether variables are named correctly...')}
  if (! 'target_id' %in% names(target_dataset)){
      stop('There is no variable named "target_id" to identify targets in the target dataset. Please make one.')}
  if (! 'target_X' %in% names(target_dataset)){
      stop('There is no variable named "target_X" to identify projected X coordinate for target dataset.Please make one or convert target dataset to an sf dataframe with known CRS.')}
  if (! 'target_Y' %in% names(target_dataset)){
      stop('There is no variable named "target_Y" to identify projected Y coordinate for target dataset. Please make one or convert target dataset to an sf dataframe with known CRS.')}
  if (! 'origin_X' %in% names(transaction_dataset)){
      stop('There is no variable named "origin_X" to identify projected X coordinate for transaction dataset. Please make one or convert transaction dataset to an sf dataframe with known CRS.')}
  if (! 'origin_Y' %in% names(transaction_dataset)){
      stop('There is no variable named "origin_Y" to identify projected Y coordinate for transaction dataset.Please make one or convert transaction dataset to an sf dataframe with known CRS.')}
  if (! 'year' %in% names(transaction_dataset)){
      stop('There is no variable named "year" to identify the year of a transaction in the transaction dataset.Please make one. If all transactions occur in the same period, you may simply define year=1.')}
  if (! 'submarket' %in% names(transaction_dataset)){
      stop('There is no variable named "submarket" to identify the submarket of a transaction in the transaction dataset.Please make one. If you do not want separate submarkets, you may simply define submarket=1.')}
  if (! 'price' %in% names(transaction_dataset)){
      stop('There is no variable named "price" to identify the price of a transaction in the transaction dataset. Please make one. Take care that the price should be in nominal currency, NOT in logs. It may be for the whole transaction or per unit of floorspace.')}

  if (debug){message('Variables are named correctly.')}

  # Check whether target IDs are unique
  if (uniqueN(target_dataset, by = 'target_id') != nrow(target_dataset)){
    stop('The target IDs supplied are not unique. Please make them unique and try again.')}
  if (debug){message('Target IDs are indeed unique.')}

  # Check whether observation parameters are set correctly
  if (observations_outer<=observations_inner){
    stop('Observations_outer parameter must be higher than observations_inner')}
  if (observations_outer<=0){
    stop('Observations_outer parameter must be set to positive integer')}
  if (observations_inner<=0){
    stop('Observations_inner parameter must be set to positive integer')}

  # If only one year exists, create an artificial year to ensure regression runs
  if (var(transaction_dataset$year)==0){
    if (debug){message('Only one year found. Creating separate dummy...')}
    transaction_one <- transaction_dataset
    transaction_one$year <- 999999
    transaction_dataset <- rbind(transaction_dataset, transaction_one)
  }

  # Prepare year as factor
  if (debug){message('Converting year to factor variable...')}
  transaction_dataset[, yearfactor := base::as.factor(year)]

  if (debug){message(paste('Calculating index for the following years: ', print(levels(transaction_dataset$yearfactor))))}


  # Prepare log price
  if (debug){message('Calculating log price...')}
  transaction_dataset[, lprice := log(price)]

  # Find list of attributes
  if (debug){message('Finding list of attributes to control for...')}
  attribute_vars = names(transaction_dataset)
  attribute_vars = attribute_vars[stringr::str_detect(attribute_vars, 'Att_')==T]

  # demean variables
  if (debug){message('Demeaning variables...')}

  for (attr_var in attribute_vars){
      demean_variable(data=transaction_dataset, var=attr_var)}

  # Run regressions in parallel

  if (debug){message('Registering support for parallel processing...')}

  # If no number or cores is specified, use 'number avaialble minus one'. If there is only one core, that would be a bad idea, so we select higher of that or one.
  if (is.null(n_cores)){
    n_cores_available = parallel::detectCores()
    n_cores = max(n_cores_available-1, 1)
  }

  doParallel::registerDoParallel(n_cores)

  if (use_parallel!=T){n_cores<-1}
  if (skip_errors==F){onerror <- 'stop'} else {onerror <- 'remove'}

  message(paste('Prepation done. Calculating index using', n_cores, 'cores...'))

  package_list = c('sf', 'data.table', 'stringr', 'lmtest', 'sandwich')

  start_time = Sys.time()

  if (debug){message('Evaluating ...')}
  if (use_parallel==T){
    evaluated = foreach::foreach(oa = target_dataset$target_id, .combine = rbind, .errorhandling = onerror, .packages = package_list, .verbose = debug) %dopar%
      calculate_index_point(target_dataset, transaction_dataset,
      observations_outer, observations_inner,
      max_radius_outer, max_radius_inner,
      attribute_vars, oa, debug)
    } else {
      evaluated = foreach::foreach(oa = target_dataset$target_id, .combine = rbind, .errorhandling = onerror, .packages = package_list, .verbose = debug) %do%
        calculate_index_point(target_dataset, transaction_dataset,
                              observations_outer, observations_inner,
                              max_radius_outer, max_radius_inner,
                              attribute_vars, oa, debug)
      }


  end_time = Sys.time()
  duration = difftime(end_time, start_time)
  if (nrow(evaluated)<1){stop('The index did not calculate succesfully. Further debug necessary...')}
  message(paste0("Finished calculating the index in ", round(duration[[1]], 2), ' ', units(duration), "."))

  return(evaluated)
}


