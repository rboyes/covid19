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
library(lubridate)
library(tidyverse)

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
        
        httr::GET(
            url   = endpoint,
            query = list(
                filters   = paste(filters, collapse = ";"),
                structure = jsonlite::toJSON(structure, auto_unbox = TRUE),
                page      = current_page
            ),
            timeout(10)
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
df_population <- readxl::read_xls('ukmidyearestimates20192020ladcodes.xls', sheet = 'MYE2 - Persons', skip = 4)
df_population <- df_population %>% select(Code, Name, Geography1, `All ages`) %>% rename(code = Code, name = Name, geography = Geography1, population = `All ages`)

# Join to the population data for each local authority
df_cases <- df_cases %>% left_join(df_population, by = c("code" = "code"), suffix = c("", "_population"))

# And calculate a rolling number of cases per 100k population for some duration, I thought a week is best
cumlag <- 7
df_cases <- df_cases %>% arrange(code, date) %>% group_by(code) %>% mutate(cumlag = dplyr::lag(cumulative, n = cumlag, default = NA)) %>% arrange(code, desc(date)) %>% ungroup()
df_cases <- df_cases %>% mutate(rollsum = cumulative - cumlag)
df_cases <- df_cases %>% mutate(rollrate100k = 1.0E+5 * rollsum / population)

start_date <- df_cases %>% summarise(min_date = min(date)) %>% pull()
testing_lag <- 4 # The number of most recent days removed 
last_date <- today() - ddays(testing_lag)

# Get the latest figures
df_latest <- df_cases %>% group_by(name) %>% filter(date == last_date) %>% ungroup()

# What are the top 5 ?
top_names <- df_latest %>% top_n(5, rollrate100k) %>% pull(name)
name_choices <- df_latest %>% pull(name)

subTitleText <- paste("Rolling weekly sum of positive covid cases per 100k population for each local authority in the United Kingdom.",
                      " Note the date filter excludes the last ", testing_lag, 
                      " days initially, due to data still being reported; change to suit your needs.")

# Define UI for application that draws a histogram
ui <- fluidPage(

    # Application title
    titlePanel(h1("Local authority Covid 19 cases",h5(subTitleText)), windowTitle = "UK local authority Covid 19 cases"),
    # Sidebar with a slider input for number of bins 
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
                           max = today() - ddays(1))
        ),

        # Show a plot of the generated distribution
        mainPanel(
            plotOutput("rollsumPlot")
        )
    )
)

# Define server logic required to draw a histogram
server <- function(input, output) {

    output$rollsumPlot <- renderPlot({
        df_plot <- df_cases %>% filter(name %in% input$selectedCodes) %>% 
            filter((date >= input$dateRange[1]) & (date <= input$dateRange[2]))
        df_plot %>% 
            ggplot(aes(x = date, y = rollrate100k, group = name, color = name)) + 
            geom_line() +
            labs(x = "Date", y = "Rolling positives in last seven days per 100k", color = "Local authority\n") + 
            scale_x_date(date_labels = "%b %Y") + theme(text = element_text(size=14))
    })
}

# Run the application 
shinyApp(ui = ui, server = server)
