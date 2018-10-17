# Web_App_R_Shiny
R Shiny Web App  to monitoring fire detector iot nodes 


In this repository are located the scripts of the R Shiny application used to monitor the flow of fire detection devices.

Parts of the code are based on examples from the RStudio library:

https://github.com/rstudio/shiny-examples/tree/master/063-superzip-example

https://github.com/rstudio/shiny-examples/tree/master/087-crandash 


Regarding to the sending of data in near real time we have relied  in the excellent example of mokjpn:

https://github.com/mokjpn/R_IoT


For some icons we have used the following:

https://github.com/erikflowers/weather-icons

Shiny web app is published in the following link:

https://firedetectoruah.shinyapps.io/Shiny_tfmiot_final/

Please, check the scripts and memory documentation for more information.

To run application in RStudio, please install missing pakackages an execute:

```
shiny::runApp('Shiny_tfmiot_final')
```

librarys:

```
install.packages(leaflet)
install.packages(leaflet.extras)
install.packages(scales)
install.packages(lattice)
install.packages(dplyr)
install.packages(ggplot2)
install.packages(plotly)
install.packages(mongolite)
install.packages(jsonlite)
install.packages(tidyr)
install.packages(anytime)
install.packages(leaflet)
install.packages(plotly)
install.packages(shinydashboard)
install.packages(shinyWidgets)
install.packages(DT)
```

Whit scripts, css and icons in the same directory.
