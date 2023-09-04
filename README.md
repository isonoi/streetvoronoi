# Voronoiesque polygons based on travel times isochrones

# Pre-requisites

The code underlying this paper requires R to be installed.

# Input data

The input datasets for the example data are as follows:

- Street network in a 1 km buffer around central Oldenburg
- 4 points in Oldenburg

![](README_files/figure-commonmark/extract-osm-data-1.png)

# Voronoi polygons

![](README_files/figure-commonmark/voronois-1.png)

# Isochrones

    Simple feature collection with 4 features and 3 fields
    Geometry type: MULTIPOLYGON
    Dimension:     XY
    Bounding box:  xmin: 8.203783 ymin: 53.14221 xmax: 8.218292 ymax: 53.15138
    Geodetic CRS:  WGS 84
    # A tibble: 4 × 4
         id isomin isomax                                                   geometry
      <int>  <dbl>  <dbl>                                         <MULTIPOLYGON [°]>
    1     1      0      2 (((8.211609 53.14746, 8.210783 53.14753, 8.210232 53.1473…
    2     2      2      4 (((8.209544 53.14879, 8.209131 53.14888, 8.208895 53.1487…
    3     3      4      6 (((8.209131 53.14983, 8.208305 53.15013, 8.208187 53.1497…
    4     4      6      8 (((8.208305 53.15138, 8.208114 53.15127, 8.207479 53.1509…

![](README_files/figure-commonmark/unnamed-chunk-4-1.png)

# Next steps with isochrone polygon intersection approach

The example above demonstrates the calculation of voronoi polygons and
isochrone polygons associated with points. To get from this example to
catchment areas associated with travel times, building on the approach
of calculating multiple isochrones, a number of problems need to be
solved:

- Iterative union of isochrone polygons associated with each point for
  which there are no ‘collissions’
- In cases where there are ‘collisions’ between isochrone polygons,
  erase polygons with larger travel times with polygons associated with
  a different point that have lower travel times
- Where isochrone polygons of equal travel time intersect, find the
  centreline of the intersection and partition polygons according, as
  outlined
  [here](https://gis.stackexchange.com/questions/217151/how-to-align-edges-of-overlapping-polygons-in-the-middle-line)

# Alternative approaches

Another approach would be to iteratively sample points located between
points to find locations that have roughly equal travel times. From
these ‘equal travel time points’ polygons can be constructed.

# Nearest hex cells

![](README_files/figure-commonmark/unnamed-chunk-5-1.png)

We’ll iterate over every hex cell to find the nearest pub, first using
nearest distances:

![](README_files/figure-commonmark/unnamed-chunk-6-1.png)

Next, we’ll use travel times to find the nearest pub. To minimise the
number of requests, the strategy will be as follows:

1.  Identify hex cells that touch the boundary between two or more
    territories

![](README_files/figure-commonmark/unnamed-chunk-7-1.png)
