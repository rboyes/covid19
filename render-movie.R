library(shiny)

library(ggplot2)
library(htmlwidgets)
library(httr)
library(leaflet)
library(lubridate)
library(sf)
library(stringr)
library(tidyverse)
library(webshot)

csv_url = format(Sys.Date(), "http://31.125.158.39/covid19-data/covid19-%Y-%m-%d.csv.gz")
df_cases = readr::read_csv(csv_url)

df_population <- readxl::read_xls('ukmidyearestimates20192019ladcodes.xls', sheet = 'MYE2 - Persons', skip = 4)
df_population <- df_population %>% select(Code, Name, Geography1, `All ages`) %>% rename(code = Code, name = Name, geography = Geography1, population = `All ages`)

df_lads = sf::read_sf('Local_Authority_Districts__December_2019__Boundaries_UK_BUC.shp')

df_cases <- df_cases %>% left_join(df_population, by = c("code" = "code"), suffix = c("", "_population"))

df_cases <- df_cases %>% arrange(code, date) %>% group_by(code) %>% mutate(cumlag = dplyr::lag(cumulative, n = 7, default = NA)) %>% arrange(code, desc(date)) %>% ungroup()
df_cases <- df_cases %>% mutate(rollsum = cumulative - cumlag)
df_cases <- df_cases %>% mutate(rollrate100k = 1.0E+5 * rollsum / population)

outdir = 'map-pngs'

if(!dir.exists(outdir)) {
  dir.create(outdir)
}

dates <- seq(as.Date("2020-09-01"), today() - 4, by=1)

idx = 1
for(mapDate in as.list(dates)) {
  print(mapDate)
  df_plot = df_cases %>% 
    filter(date == mapDate) %>% 
    select(code, name, rollrate100k) %>% 
    mutate(la_rollrate100k = sprintf("%s - rollrate/100k: %4.0f", name, rollrate100k))
  
  df_lads_cases = df_lads %>% 
    dplyr::left_join(df_plot, by = c("lad19cd" = "code")) %>%
    filter(!is.na(rollrate100k))
  
  bins = c(0, 10, 20, 50, 100, 200, 350, 550, 750, Inf)
  
  pal <- colorBin(
    bins = bins,
    palette = "YlGnBu",
    domain = df_lads_cases$rollrate100k
  )
  
  map = leaflet::leaflet() %>% 
    leaflet::setView(lat = 54.75, lng = -4, zoom = 6) %>%
    leaflet::addPolygons(data = df_lads_cases,
                         stroke = TRUE,
                         weight = 1.0,
                         fillColor = ~pal(rollrate100k),
                         fillOpacity = 1.0,
                         label = ~la_rollrate100k,
                         layerId = ~lad19cd) %>%
    leaflet::addLegend(position = "topright", 
                       title = sprintf("Rollrate/100k - %s", format(mapDate, "%d-%m-%y")),
                       pal = pal, 
                       values = df_lads_cases$rollrate100k)
  
  html_path = 'map.html'
  saveWidget(map, html_path, selfcontained = TRUE)
  webshot(html_path, file = file.path(outdir, sprintf('%03d.png', idx)))
  file.remove(html_path)
  
  idx = idx + 1
}

curdir = getwd()
setwd(outdir)
system('ffmpeg -y -framerate 4 -i %03d.png -c:v libx264 -vf fps=20 -pix_fmt yuv420p out.mp4')
setwd(curdir)