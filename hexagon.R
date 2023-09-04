library("sf")
library("tidyverse")
library("geodata")
library("parallel")
library("osrm")
library("cppRouting")
library("data.table")
# Setup --------------------------------------------------------------------
osrm_folder <- "~/osrm/osrm-backend"
n <- 10
set.seed(10)
extract <- FALSE
contract <- FALSE
cores <- parallel::detectCores()
nb <- function(cell) {
  lapply(seq_along(cell), function(c) {
    # Gather target cells
    data.table(
      from = cell[c],
      to = unlist(nb_contiguity[cell[c]]),
      cost = unlist(nb_durations[cell[c]])
    )
  }) %>%
    rbindlist()
}


# Download data -----------------------------------------------------------
dir.create("./data", recursive = TRUE, showWarnings = FALSE)


osm_pbf_file <- "http://download.geofabrik.de/europe/malta-latest.osm.pbf"
if (!file.exists(file.path(".", "data", basename(osm_pbf_file)))) {
  download.file(osm_pbf_file,
                destfile = file.path(".", "data", basename(osm_pbf_file)))
}


shp_file <- "http://download.geofabrik.de/europe/malta-latest-free.shp.zip"
if (!file.exists(file.path(".", "data", basename(shp_file)))) {
  download.file(shp_file,
                destfile = file.path(".", "data", basename(shp_file)))
}


outline <- geodata::gadm(country = "MLT", level = 0, path = "./data") %>%
  st_as_sf()


# Preprocess OSRM ---------------------------------------------------------
## extract -----------------------------------------------------------------
if (extract) {
  system(paste("osrm-extract", file.path(".", "data", basename(osm_pbf_file)),
               "-p", paste0(osrm_folder, "/profiles/bicycle.lua")))
}


## contract ----------------------------------------------------------------
osrm_file <- file.path(".", "data", str_replace(basename(osm_pbf_file),
                                                ".osm.pbf$", ".osrm"))
if (contract) {
  system(paste("osrm-contract", osrm_file))
}


## run server --------------------------------------------------------------
system(paste("osrm-routed", osrm_file, "--max-matching-radius=-1"), wait = F)


# Build sample data set -------------------------------------------------------
points <- st_sample(x = outline, size = n) %>%
  st_sfc() %>%
  st_as_sf()

# Hexagon Approach -------------------------------------------------------

## Build Gird --------------------------------------------------------------
hex_grid <- st_as_sf(sf::st_make_grid(st_union(outline),
                                      square = F, flat_topped = F,
                                      cellsize = 0.01)) %>%
  st_transform(crs = 4326) %>%
  rename(geometry = x) %>%
  mutate(area = units::set_units(st_area(.),"km^2"))

# Average Distance beween Grid Points
dist <- as.numeric(units::set_units(2*(sqrt(3)/2) * sqrt((2*mean(hex_grid$area))/(3*sqrt(3))),"m"))

# Create Centroids
hex_points <- st_centroid(hex_grid)

# Intersect Grid with Country Outline
hex_grid <- hex_grid[st_intersects(hex_grid,st_union(outline), sparse =  FALSE),] %>%
  mutate(hexid = row_number())
rownames(hex_grid) <- NULL

# Restrict Hex-Points to Hex Grid
hex_points <- hex_points %>%
  dplyr::select(-area) %>%
  sf::st_join(hex_grid,join = st_within) %>%
  dplyr::filter(!is.na(hexid))


ggplot()+
  geom_sf(data = hex_grid)+
  geom_sf(data = outline, fill = NA)


## Get Neighbor dist/dura ----------------------------------------------------
nb_contiguity <- st_touches(hex_grid)

nb_durations <- lapply(1:length(nb_contiguity), function(n) {
  dura <- osrmTable(src = hex_points[n,],
                    dst = hex_points[nb_contiguity[[n]], ],
                    osrm.server = "http://0.0.0.0:5000/")
  return(dura$durations)
})

# Convert to graph, make isochrones -----------------------------------------
db <- mclapply(1:nrow(hex_grid), nb, mc.cores = cores) %>%
  rbindlist()

db[is.na(cost), cost:= 9998]

# Convert into edge-weighted, directed graph
graph <- cppRouting::makegraph(df = db, directed = T)

t0 <- Sys.time()
isochrone_cells <- mclapply(1:nrow(hex_grid), function(i) {
  unlist(cppRouting::get_isochrone(Graph = graph, from = i,lim = 15))
}, mc.cores = cores)
t1 <- Sys.time()
print(t1 - t0)

isochrone_count <- lapply(isochrone_cells, length)

hex_grid$accessibility <- unlist(isochrone_count)

ggplot()+
  geom_sf(data = hex_grid, aes(fill = accessibility))+
  geom_sf(data = outline, fill = NA)


c <- c(10,20)
ggplot()+
  geom_sf(data = hex_grid[unlist(isochrone_cells[c]),], fill = "#00ff00", alpha = 0.5)+
  geom_sf(data = hex_grid[c,], fill = "#ff0000")+
  geom_sf(data = outline, fill = NA)
