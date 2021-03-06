#' Find placenames near a given location
#'
#' @references \url{https://data.aad.gov.au/aadc/gaz/scar/}, \url{https://www.scar.org/data-products/place-names/}
#'
#' @param gaz data.frame or SpatialPointsDataFrame: as returned by \code{\link{an_read}}, \code{\link{an_preferred}}, or \code{\link{an_filter}}
#' @param loc numeric: target location (a two-element numeric vector giving longitude and latitude, or a SpatialPoints object)
#' @param max_distance numeric: maximum search distance in kilometres
#'
#' @return data.frame of results
#'
#' @seealso \code{\link{an_read}}
#'
#' @examples
#' \dontrun{
#'  g <- an_read(cache = "session")
#'
#'  ## named features within 10km of 110E, 66S
#'  an_near(g, loc = c(110, -66), max_distance = 10)
#'
#'  ## using pipe operator
#'  g %>% an_near(loc = c(100, -66), max_distance = 10)
#'
#'  ## with sp objects
#'  gsp <- an_read(cache = "session", sp = TRUE)
#'  loc <- sp::SpatialPoints(matrix(c(110, -66), nrow = 1),
#'    proj4string = CRS("+proj=longlat +datum=WGS84 +ellps=WGS84"))
#'  an_near(gsp, loc = loc, max_distance = 10)
#' }
#'
#' @export
an_near <- function(gaz, loc, max_distance) {
    assert_that(inherits(gaz, c("data.frame", "SpatialPointsDataFrame")))
    ## make sure gaz locations are in longitude and latitude
    if (inherits(gaz, "SpatialPointsDataFrame")) {
        if (!is.projected(gaz)) {
            crds <- coordinates(gaz)
        } else {
            crds <- coordinates(spTransform(gaz, CRS("+proj=longlat +datum=WGS84 +ellps=WGS84")))
        }
    } else {
        crds <- gaz[, c("longitude", "latitude")]
    }
    ## make sure loc is in longitude and latitude
    if (inherits(loc, "SpatialPoints")) {
        if (is.projected(loc)) loc <- coordinates(spTransform(loc, CRS("+proj=longlat +datum=WGS84 +ellps=WGS84")))
    }
    dist <- geosphere::distVincentySphere(loc, crds) / 1e3
    dist[is.na(dist)] <- Inf
    gaz[dist<=max_distance, ]
}


#' Filter a collection of place names by various criteria
#'
#' A data frame of place names can be filtered according to name, geographic location, feature type, or other criteria. All text-related matches are by default treated as regular expressions and are case-insensitive: you can change this behaviour via the \code{ignore_case} and \code{as_regex} parameters.
#'
#' @references \url{https://data.aad.gov.au/aadc/gaz/scar/}, \url{https://www.scar.org/data-products/place-names/}
#'
#' @param gaz data.frame or SpatialPointsDataFrame: as returned by \code{\link{an_read}} or \code{\link{an_preferred}}
#' @param query character: vector of place name terms to search for. Returned place names will be those that match all entries in \code{query}
#' @param feature_ids numeric: return only place names associated with the features identified by these identifiers. Currently these values can only be \code{scar_common_id} values
#' @param extent vector of c(longitude_min, longitude_max, latitude_min, latitude_max): if provided, search only for names within this bounding box. \code{extent} can also be passed as a raster Extent object, a Raster object (in which case its extent will be used), a Spatial object (in which case the bounding box of the object will be used as the extent), or a matrix (in which case it will be assumed to be the output of \code{sp::bbox})
#' @param feature_type string: return only place names corresponding to feature types matching this pattern. For valid feature type names see \code{\link{an_feature_types}}
#' @param origin string: return only place names originating from bodies (countries or organisations) matching this pattern. For valid \code{origin} values see \code{link{an_origins}}
#' @param origin_gazetteer string: return only place names originating from gazetteers matching this pattern. For valid gazetteer names see \code{\link{an_gazetteers}}
#' @param ignore_case logical: if \code{TRUE}, use case-insensitive text matching
#' @param as_regex logical: if \code{TRUE}, treat \code{query} and other string input parameters as regular expressions. If \code{FALSE}, they will be treated as fixed strings to match against
#'
#' @return data.frame of results
#'
#' @seealso \code{\link{an_read}}, \code{\link{an_gazetteers}}, \code{\link{an_origins}}
#'
#' @examples
#' \dontrun{
#'  g <- an_read(cache = "session")
#'
#'  ## simple search for any place name containing the word 'William'
#'  an_filter(g, query = "William")
#'
#'  ## which bodies (countries or organisations) provided the names in our data?
#'  an_origins(g)
#'
#'  ## find names containing "William" and originating from Australia or the USA
#'  an_filter(g, query = "William", origin = "Australia|United States of America")
#'
#'  ## this search will return no matches
#'  ## because the actual place name is 'William Scoresby Archipelago'
#'  an_filter(g, query = "William Archipelago")
#'
#'  ## we can split the search terms so that each is matched separately
#'  an_filter(g, query = c("William", "Archipelago"))
#'
#'  ## or use a regular expression
#'  an_filter(g, query = "William .* Archipelago")
#'
#'  ## or refine the search using feature type
#'  an_filter(g, query = "William", feature_type = "Archipelago")
#'
#'  ## what feature types do we have in our data?
#'  an_feature_types(g)
#'
#'  ## for more complex text searching, use regular expressions
#'  ## e.g. names matching "West" or "East"
#'  an_filter(g, query = "West|East")
#'
#'  ## names starting with "West" or "East"
#'  an_filter(g, query = "^(West|East)")
#'
#'  ## names with "West" or "East" appearing as complete words in the name
#'  ## ["\\b" matches a word boundary: see help("regex") ]
#'  an_filter(g, query = "\\b(West|East)\\b")
#'
#'  ## filtering by spatial extent
#'  nms <- an_filter(g, extent = c(100, 120, -70, -65), origin = "Australia")
#'  with(nms, plot(longitude, latitude))
#'  with(nms, text(longitude, latitude, place_name))
#'
#'  ## searching within the extent of an sp object
#'  my_sp <- sp::SpatialPoints(cbind(c(100, 120), c(-70, -65)))
#'  an_filter(g, extent = my_sp)
#'
#'  ## or equivalently
#'  an_filter(g, extent = bbox(my_sp))
#'
#'  ## or using the sp form of the gazetteer data
#'  gsp <- an_read(cache = "session", sp = TRUE)
#'  an_filter(gsp, extent = my_sp)
#'
#'  ## using the pipe operator
#'  g %>% an_filter(query = "Ross", feature_type = "Ice shelf|Mountain")
#'
#'  g %>% an_near(loc = c(100, -66), max_distance = 20) %>%
#'        an_filter(feature_type = "Island")
#'
#'  ## find all names for feature 1589 and the naming
#'  ##  authority for each name
#'  an_filter(g, feature_ids = 1589)[, c("place_name", "origin")]
#' }
#' @export
an_filter <- function(gaz, query, feature_ids, extent, feature_type, origin, origin_gazetteer, ignore_case=TRUE, as_regex=TRUE) {
    assert_that(is.flag(ignore_case), !is.na(ignore_case))
    assert_that(is.flag(as_regex), !is.na(as_regex))
    ## note that we do our own case-conversion when ignore_case is TRUE, rather than using the ignore.case parameter in grepl
    ## this is because grepl does not honour ignore.case when fixed is TRUE
    ## helper function to simplify code when doing case-insensitive matching
    tlc <- function(x, cond=ignore_case) if (cond) tolower(x) else x
    assert_that(inherits(gaz, c("data.frame", "SpatialPointsDataFrame")))
    idx <- rep(TRUE, nrow(gaz))
    if (!missing(feature_ids)) {
        idx <- gaz$scar_common_id %in% feature_ids
    }
    if (!missing(query)) {
        assert_that(is.character(query))
        query <- query[nzchar(query) & !is.na(query)]
        if (length(query)<1) stop("all query terms were empty or NA")
        search_place_name <- tlc(gaz$place_name)
        search_place_name_transliterated <- tlc(gaz$place_name_transliterated)
        for (st in query) {
            st <- tlc(st)
            idx <- idx & (grepl(st, search_place_name, fixed = !as_regex) | grepl(st, search_place_name_transliterated, fixed = !as_regex))
        }
    }
    out <- gaz[idx, ]
    if (!missing(extent)) {
        assert_that((is.numeric(extent) && length(extent) == 4) || inherits(extent, "Extent") || inherits(extent, "Raster") || inherits(extent, "Spatial"))
        if (inherits(out, "SpatialPointsDataFrame")) {
            out <- crop(out, extent)
        } else {
            if (inherits(extent, "Raster")) extent <- raster::extent(extent)
            if (inherits(extent, "Spatial")) extent <- sp::bbox(extent)
            if (inherits(extent, "matrix")) {
                ## if matrix, assume is an sp::bbox object
                extent <- as.numeric(extent)
                ## this is ordered c(xmin, ymin, xmax, ymax)
                sidx <- !is.na(out$longitude) & !is.na(out$latitude)
                sidx <- sidx & out$longitude>=extent[1] & out$longitude<=extent[3] & out$latitude>=extent[2] & out$latitude<=extent[4]
                out <- out[sidx, ]
            } else {
                sidx <- !is.na(out$longitude) & !is.na(out$latitude)
                sidx <- sidx & out$longitude>=extent[1] & out$longitude<=extent[2] & out$latitude>=extent[3] & out$latitude<=extent[4]
                out <- out[sidx, ]
            }
        }
    }
    if (!missing(feature_type)) {
        assert_that(is.string(feature_type), !is.na(feature_type), nzchar(feature_type))
        out <- out[grepl(tlc(feature_type), tlc(out$feature_type_name), fixed = !as_regex), ]
    }
    if (!missing(origin)) {
        assert_that(is.string(origin), !is.na(origin), nzchar(origin))
        out <- out[grepl(tlc(origin), tlc(out$origin), fixed = !as_regex), ]
    }
    if (!missing(origin_gazetteer)) {
        assert_that(is.string(origin_gazetteer), !is.na(origin_gazetteer), nzchar(origin_gazetteer))
        out <- out[grepl(tlc(origin_gazetteer), tlc(out$gazetteer), fixed = !as_regex), ]
    }
    out
}


#' List the origins of place names present in gazetteer data
#'
#' The Composite Gazetteer of Antarctica is a compilation of place names provided by different countries and organisations. This function lists the originating bodies that provided the names in a given data frame.
#'
#' @param gaz data.frame or SpatialPointsDataFrame: as returned by \code{\link{an_read}}, \code{\link{an_preferred}}, or \code{\link{an_filter}}
#'
#' @return character vector of origin names (countries or organisations)
#'
#' @seealso \code{\link{an_filter}} for filtering data according to origin
#'
#' @examples
#' \dontrun{
#'  g <- an_read(cache = "session")
#'
#'  ## which bodies (countries or organisations) provided the names in our data?
#'  an_origins(g)
#' }
#' @export
an_origins <- function(gaz) {
    assert_that(inherits(gaz, c("data.frame", "SpatialPointsDataFrame")))
    sort(no_na(unique(gaz$origin)))
}


#' List feature types present in gazetteer data
#'
#' The gazetteer place names are associated with different feature types (e.g. "Hill", "Mountain", "Water body"). This function lists the feature types that are present in a given data frame.
#'
#' @param gaz data.frame or SpatialPointsDataFrame: as returned by \code{\link{an_read}}, \code{\link{an_preferred}}, or \code{\link{an_filter}}
#'
#' @return character vector of country names
#'
#' @seealso \code{\link{an_filter}} for filtering data according to feature type
#'
#' @examples
#' \dontrun{
#'  g <- an_read(cache = "session")
#'
#'  ## what feature types do we have in our data?
#'  an_feature_types(g)
#' }
#' @export
an_feature_types <- function(gaz) {
    assert_that(inherits(gaz, c("data.frame", "SpatialPointsDataFrame")))
    sort(as.character(no_na(unique(gaz$feature_type_name))))
}
