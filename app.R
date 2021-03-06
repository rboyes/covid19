#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)

library(ggplot2)
library(httr)
library(jsonlite)
library(leaflet)
library(lubridate)
library(sf)
library(stringr)
library(tidyverse)

library(DT)

#' Extracts paginated data by requesting all of the pages
#' and combining the results.
#'
#' @param filters    API filters. See the API documentations for 
#'                   additional information.
#'                   
#' @param structure  Structure parameter. See the API documentations 
#'                   for additional information.
#'                   
#' @return list      Comprehensive list of dictionaries containing all 
#'                   the data for the given ``filter`` and ``structure`.`
get_paginated_data <- function (filters, structure) {
    
    endpoint     <- "https://api.coronavirus.data.gov.uk/v1/data"
    results      <- list()
    current_page <- 1
    
    repeat {
        print(str_glue("Getting page {current_page} at time {date()}"))
        httr::GET(
            url   = endpoint,
            query = list(
                filters   = paste(filters, collapse = ";"),
                structure = jsonlite::toJSON(structure, auto_unbox = TRUE),
                page      = current_page
            ),
            timeout(30)
        ) -> response
        
        # Handle errors:
        if ( response$status_code >= 400 ) {
            err_msg = httr::http_status(response)
            stop(err_msg)
        } else if ( response$status_code == 204 ) {
            break
        }
        
        # Convert response from binary to JSON:
        json_text <- content(response, "text")
        dt        <- jsonlite::fromJSON(json_text)
        results   <- rbind(results, dt$data)
        
        if ( is.null( dt$pagination$`next` ) ){
            break
        }
        
        current_page <- current_page + 1;
        
    }
    
    return(results)
    
}

# Create filters:
query_filters <- c(
    "areaType=ltla"
)

# Create the structure as a list or a list of lists:
query_structure <- list(
    date       = "date", 
    name       = "areaName", 
    code       = "areaCode", 
    daily      = "newCasesBySpecimenDate",
    cumulative = "cumCasesBySpecimenDate"
)

df_cases <- get_paginated_data(query_filters, query_structure) %>% as_tibble() %>% mutate(date = as.Date(date))

# Population data for local authorities in the UK, available from the ONS: 
# https://www.ons.gov.uk/peoplepopulationandcommunity/populationandmigration/populationestimates/datasets/populationestimatesforukenglandandwalesscotlandandnorthernireland
df_population <- readxl::read_xls('ukmidyearestimates20192019ladcodes.xls', sheet = 'MYE2 - Persons', skip = 4)
df_population <- df_population %>% select(Code, Name, Geography1, `All ages`) %>% rename(code = Code, name = Name, geography = Geography1, population = `All ages`)

df_lads = sf::read_sf('Local_Authority_Districts__December_2019__Boundaries_UK_BUC.shp')

# Join to the population data for each local authority
df_cases <- df_cases %>% left_join(df_population, by = c("code" = "code"), suffix = c("", "_population"))

# And calculate a rolling number of cases per 100k population for some duration, I thought a week is best
df_cases <- df_cases %>% arrange(code, date) %>% group_by(code) %>% mutate(cumlag = dplyr::lag(cumulative, n = 7, default = NA)) %>% arrange(code, desc(date)) %>% ungroup()
df_cases <- df_cases %>% mutate(rollsum = cumulative - cumlag)
df_cases <- df_cases %>% mutate(rollrate100k = 1.0E+5 * rollsum / population)

start_date <- min(df_cases$date)
end_date <- max(df_cases$date)
testlag <- 4 # The number of most recent days removed, due to delays in getting testing results
last_date <- end_date - ddays(testlag)

# Get the latest figures
df_latest <- df_cases %>% group_by(name) %>% filter(date == last_date) %>% ungroup()

country_names = df_latest %>% filter(geography == 'Country') %>% pull(name)

# What are the top 5 ?
top_names <- df_latest %>% top_n(5, rollrate100k) %>% pull(name)

# Combine them with the countries
top_names <- append(top_names, country_names)

name_choices <- df_latest %>% pull(name)



subTitleText <- paste("Rolling weekly sum of positive covid tests per 100k population for each local authority in the United Kingdom; tests are recorded by specimen date.",
                      " Note the date filter excludes the last ", testlag, 
                      " days initially, due to data still being reported; change to suit your needs.",
                      " The local authorities with the highest rolling rates are selected.")

ui <- fluidPage(
    
    # Application title
    titlePanel(h1("Local authority Covid 19 cases",h5(subTitleText)), windowTitle = "UK local authority Covid 19 cases"),
    sidebarLayout(
        sidebarPanel(
            selectInput("selectedCodes", 
                        label = "Local authority:",
                        choices = name_choices,
                        multiple = TRUE,
                        selected = top_names),
            dateRangeInput("dateRange",
                           label = "Date range:", 
                           start = start_date,
                           end = last_date,
                           min = start_date,
                           max = end_date)
        ),
        
        mainPanel(
            tabsetPanel(
                type = "tabs",
                tabPanel("Plot", plotOutput("rollsumPlot", height = 800)),
                tabPanel("Table", DTOutput("rollsumTable", height = 800)),
                tabPanel("Map", leafletOutput("map", height = 800))
            )
        )
    )
)

server <- function(input, output, session) {
    
    output$rollsumPlot <- renderPlot({
        df_plot <- df_cases %>% filter(name %in% input$selectedCodes) %>% 
            filter((date >= input$dateRange[1]) & (date <= input$dateRange[2]))
        df_plot %>% 
            ggplot(aes(x = date, y = rollrate100k, group = name, color = name)) + 
            geom_line(size = 1) +
            labs(x = "", y = "Rolling positives in last seven days per 100k", color = "Local authority\n") + 
            scale_x_date(date_labels = "%b %Y") + theme(text = element_text(size=14))
    })
    
    output$rollsumTable <- DT::renderDT({
        
        date_endweek <- input$dateRange[2]
        date_startweek <- date_endweek - ddays(7)
        df_week <- df_cases %>% 
            filter((date > date_startweek) & 
                   (date <= date_endweek) & 
                   (name %in% input$selectedCodes)) %>% 
            arrange(name, date)
        
        df_wideweek <- df_week %>% mutate(date = format(date, "%b%d")) %>% pivot_wider(names_from = date, values_from = c("daily"), id_cols = c("name"))
        
        df_endweek <- df_cases %>% filter(date == date_endweek) %>% select(name, rollsum, rollrate100k)
        df_startweek <- df_cases %>% filter(date == date_startweek) %>% select(name, rollsum, rollrate100k)
        
        df_wideweek <- df_wideweek %>% inner_join(df_endweek %>% select(name, rollsum), by = "name")
        df_wideweek <- df_wideweek %>% inner_join(df_startweek %>% select(name, rollsum), by = "name", suffix = c("", format(date_startweek, "_%b%d")))
        df_wideweek <- df_wideweek %>% inner_join(df_endweek %>% select(name, rollrate100k), by = "name")
        df_wideweek <- df_wideweek %>% inner_join(df_startweek %>% select(name, rollrate100k), by = "name", suffix = c("", format(date_startweek, "_%b%d")))
        
        rollrate100k_startweek <- paste("rollrate100k", format(date_startweek, "%b%d"), sep = "_")
        df_wideweek <- df_wideweek %>% mutate(ratediff = rollrate100k - base::get(rollrate100k_startweek)) %>% rename("Local authority" = name) %>% arrange(desc(rollrate100k))
        dt_wideweek <- datatable(df_wideweek, rownames = FALSE, options = list(pageLength = 25, searching = FALSE)) %>% 
            formatRound(columns = c("rollrate100k", rollrate100k_startweek, "ratediff"), digits = 2) %>%
            formatStyle("ratediff", backgroundColor = styleInterval(c(0.0), c('green', 'red')))
        return(dt_wideweek)
    })
    
    output$map <- renderLeaflet({
        
        mapDate = input$dateRange[2]
        
        dates <- seq(as.Date("2020-09-01"), as.Date("2020-12-15"), by=1)
        
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
            #saveWidget(map, sprintf("map-%s.html", format(mapDate, "%y-%m-%d")))
            Sys.sleep(1)
            View
        }
        
        return(map)
    })
    
    observeEvent({input$map_shape_click}, {
        map_click_data <- input$map_shape_click
        inputValues = reactiveValuesToList(input)
        selectedValues = inputValues$selectedCodes
        map_region_name = df_cases %>% filter(code == map_click_data$id) %>% pull(name)
        updateSelectInput(session, "selectedCodes", selected = append(selectedValues, map_region_name))
    })
}

# Run the application 
shinyApp(ui = ui, server = server)
