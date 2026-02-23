# -----------------------------------------------------------------------------

# Title:

#--------------------------------------------------------------------------------
# 01. Plot study area polygon
#--------------------------------------------------------------------------------
library(sf)
library(dplyr)
library(raster)
library(rnaturalearth)
library(rnaturalearthdata)
library(ggplot2)
library(giscoR)
library(tidyterra)
library(terra)

# 1. Load polygons--------------------------------------------------------------
# load REDUCE polygon
REDUCE <- st_read(paste0(input_data,"/enviro/REDUCE_Area/REDUCE_NEW_study_area.shp"))
#print(REDUCE)
#plot(REDUCE)

# load FAO34
FAO <- st_read(paste0(input_data,"/enviro/FAO_Areas/FAO_Major_Fishing_Areas.shp"))
#print(FAO)

# Filter the sf object to keep only the FAO34
FAO34 <- FAO %>% 
  filter(F_CODE == 34)
print(FAO34)
#plot(FAO34)


# 2. Load land mask--------------------------------------------------------------
# import landmask and coastline
world <- ne_countries(scale = "medium", returnclass = "sf")
coastline <- gisco_get_coastallines(year = "2016", epsg = "4326", resolution = "03")
# transform coastline in the same crs that landmask
coastline <- st_transform(coastline, crs = st_crs(world))


# 3. Load bathymetry--------------------------------------------------------------
# load bathymetry GEBCO2020
b1 <- rast(paste0(input_data,"/enviro/GEBCO_2020_REDUCE_bathymetry.tif"))
# use only values == or < 0 as a bathymetry
b1[b1 > 0] <- NA #0 data as NA

# color ramp for bathymetry
cols <- colorRampPalette(rev(c('#ecf9ff','#BFEFFF','#97C8EB','#4682B4','#264e76','#162e46')))(100)
cols <- adjustcolor(cols, alpha.f = 0.75) 

# limit represent in the plot for Mediterranean area
FAO34_ll <- sf::st_transform(FAO34, 4326)
REDUCE_ll <- sf::st_transform(REDUCE, 4326)

bb <- sf::st_bbox(FAO34_ll)
bb <- sf::st_bbox(REDUCE_ll)

pad <- 1  # degrees of padding
xlim <- c(bb["xmin"] - pad, bb["xmax"] + pad) #-46.00000  17.86573
ylim <- c(bb["ymin"] - pad, bb["ymax"] + pad) #-24   47


# Crop bathymetry to FAO34 or REDUCE area:
# Convert sf polygon to terra vector (and ensure same CRS)
reduce_v <- terra::vect(REDUCE)         # sf -> SpatVector
# (optional safety) project polygon to raster CRS if needed
reduce_v <- terra::project(reduce_v, terra::crs(b1))
# Crop to bbox then mask to polygon shape
b1_crop <- terra::crop(b1, reduce_v)
b1_mask <- terra::mask(b1_crop, reduce_v)

b1_mask
plot(b1_mask)

# Plot map ----------------------------
p <- ggplot() +
  
  # add bathymetry
  tidyterra::geom_spatraster(data = b1_mask) +
  # bathymettry color ramp
  scale_fill_gradientn(colors = cols,
                       name = "Depth (m)",
                       limits = visible_range, # limits of values in the represented area
                       guide = guide_colorbar(frame.colour = "grey5", ticks.colour = "grey5"),
                       na.value = "transparent") +   #NA pixels transparent
  
  # add polygons
  geom_sf(data = FAO34, fill = NA, color = "red", size = 0.3, linetype = "dashed") +
  geom_sf(data = REDUCE, fill = NA, color = "black", size = 0.2, linetype = "dashed") +
  
  # add land and coastline
  geom_sf(data = world, fill="grey90", colour = "grey75", size = 0.1) +
  geom_sf(data = coastline, fill = "transparent", colour = "black", size = 0.1, alpha = 0) +
  
  # spatial bounds
  coord_sf(xlim = xlim, ylim = ylim, expand=F) +
  
  # x y labels
  xlab("") +  ylab("") +
  # theme
  theme_bw() +
  theme(axis.text.y = element_text(size = 10),
        axis.text.x = element_text(size = 10),
        axis.ticks = element_line(size = 0.75),
        axis.ticks.length = unit(6, "pt"),
        panel.border = element_rect(color = "black", fill = NA, size = 1.2),
        panel.background = element_blank(),
        panel.grid = element_blank(),
        plot.background  = element_rect(fill = "transparent", colour = NA),
        legend.position = "none",
        legend.direction = "vertical",
        legend.justification = "center",
        legend.key.width = unit(15, "pt"),
        legend.key.height = unit(20, "pt"),
        legend.title = element_text(size = 9),
        legend.text = element_text(size = 8))

p


# save plot
p_png <- paste0(output_data, "/fig/map/REDUCE_FAO34.png")
ggsave(p_png, p, width=20, height=12, units="cm", dpi=450) #bg="white"
