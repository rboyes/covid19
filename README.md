# United Kingdom Covid19 rates

A Shiny app for the interactive charting of weekly covid rates per 100k for all local authorities in the UK.

App is available at: https://rboyes.shinyapps.io/covid19

![Alt text](screengrab.png?raw=true "Application")


Uses data from the following sources:

* Covid case data: https://api.coronavirus.data.gov.uk/v1/data
* Local authority population data: https://www.ons.gov.uk/peoplepopulationandcommunity/populationandmigration/populationestimates/datasets/populationestimatesforukenglandandwalesscotlandandnorthernireland

Some issues around time taken to start up, primarily due to slow responsiveness of the government data website. What I've done as a workaround is run a nightly job on a machine that is then uploaded to a static website.
