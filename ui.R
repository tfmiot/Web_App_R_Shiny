# Master IoT UAH - Trabajo final de Máster (Script ui.R)

# Cargamos las librerías necesarias

library(leaflet)
library(plotly)
library(shinydashboard)
library(shinyWidgets)
library(DT)
library(mongolite)

# Configuramos la fecha y hora del sistema al horario local Español

Sys.setenv(TZ='Europe/Madrid')

# Definimos las credenciales para el acceso a la BBDD

user = 'tfmiot'
pass = 'prototipo'

# Creamos una conexión a las colecciones "datos" y "configuraciones" de la base de datos awsdb alojada en nuestra instancia

datos <- mongo("datos", url = paste0("mongodb://",user,":",pass,"@34.218.246.36:27017/awsdb"))
configraciones <- mongo("configuraciones", url = paste0("mongodb://",user,":",pass,"@34.218.246.36:27017/awsdb"))

# Mediante la librería ShinyDashboard generamos una nueva estructura

dashboardPage(title = "UAH - IoT Fire Detector",                                         # Agregamos un título a la pestaña de nuestro navegador
  dashboardHeader(title = tags$img(src="logo-uah.png", width = '70%')),                  # Ponemos el logo de la Universidad de Alcalá en el encabezado
  skin = "blue",                                                                         # Definimos el azul como color principal del Dashboard
   dashboardSidebar(                                                                     # Definimos nuestro menú de opciones (basado en el ejemplo de Rstudio (https://github.com/rstudio/shiny-examples/tree/master/087-crandash))
    sidebarMenu(
      menuItem("Dashboard", tabName = "dashboard",  icon = icon("bar-chart")),           # Seleccionamos nombres e iconos para los tres paneles de los que se compone el dashboard
      menuItem("Raw data", tabName = "rawdata", icon = icon("file")),                    # Que estarán destinados a la visualización gráfica, extracción de datos,
      menuItem("Map", tabName = "map", icon = icon("globe"), selected = TRUE)            # y visualización del mapa
    )
  ),
  dashboardBody(                                                                         # Comenzamos a ubicar elementos en el cuerpo del dashboard
    
    tags$div(tags$style(HTML( ".dropdown-menu{z-index:10000 !important;}"))),            # Para no "pisar" el encabezado con los elementos interactivos del dashboard
    
    tabItems(                                                                            # Incluimos los elementos dentro de cada uno de lso menús creados más arriba
      tabItem("dashboard", 
              fluidRow(                                                                  # Usamos la función fluidRow para agregar una nueva fila de elementos en el submenú
                box(background = 'light-blue',                                           # Creamos una nueva caja, azul, y ocultable (incialmente la dejamos oculta)
                    collapsible = TRUE, 
                    collapsed = TRUE, title = "Selector de datos",
                    column(4, pickerInput(inputId = 'Device',                                 # Creamos varias columnas para ubicar los elementos el panel princiapl
                                          label = "Selecionar nodos",                         # En la primera agregamos un selector para seleccionar uno, todos o varios nodos
                                          choices = configraciones$distinct({"Device_id"}),   # Para ello usamos la librería shinyWidgets. Lanzamos una query a la colección configuraciones
                                          options = list(                                     # para tener el valor único de los dispositivos de la red en el selector
                                            'actions-box' = TRUE,                             # habilitamos las casillas de automarcado
                                            size = 5                                          # indicamos el tamaño del selector
                                          ), 
                                          multiple = TRUE                                     # habilitamos la selección múltiple de elementos
                    ),
                    dateRangeInput("dates",                                                                             # Agregamos un selector de fechas
                                   "Fecha",
                                   start = as.Date(datos$aggregate(fechas, options = '{"allowDiskUse":true}')[[2]]),    # Como valores mínimo y máximo del selector consultamos en la base de datos
                                   end = as.Date(datos$aggregate(fechas, options = '{"allowDiskUse":true}')[[1]]),      # La priemar y última fecha en la que hay algún dato
                                   min = as.Date(datos$aggregate(fechas, options = '{"allowDiskUse":true}')[[2]]), 
                                   max =as.Date(datos$aggregate(fechas, options = '{"allowDiskUse":true}')[[1]])
                    )
                    
                    ),
                  column(2, selectInput(inputId = 'Parametro',                                                          # Creamos una segunda columna con un nuevo selector
                              label='Parametro', c('temperatura','humedad','presion'))),                                # Como opciones indicamos los parámetros que reportan nuestros nodos
                  column(2, materialSwitch(inputId = "desglose", label = "Desglosar por nodos", status = "danger"),     # Agregamos dos switch (con los temas "danger" y "succes") para activar el tiempo real  
                            materialSwitch(inputId = "realTime", label = "Activar Tiempo Real", status = "succes")      # y poder desglosar por nodos (librería shinyWidgets.)
                         ),
                  column(2, htmlOutput("mensaje1"),                                                                     # Ponemos un objeto mensaje (tipo html) para indicar que el modo tiempo real está activado
                         br(),
                         htmlOutput("mensaje2")),
                  width = 12
                )
                
              ),
              fluidRow(                                                                      # En la segunda fila del menu dashboard
                box(
                  tags$style(type="text/css",                                                # Agregamos una segunda caja blanca
                             ".shiny-output-error { visibility: hidden; }",                  # Y deshabilitamos los mensajes de Warning
                             ".shiny-output-error:before { visibility: hidden; }"
                  ),
                  plotlyOutput("trace_plot", height = "100%", width = "90%"), width = 12     # Ubicamos un objeto tipo ploty (librería plotly) para los gráficos
                )
              )
              
      ),
      tabItem("rawdata",                                                                     # Esta parte del código está basada totalmente en el ejemplo https://github.com/rstudio/shiny-examples/tree/master/087-crandash                                       
              numericInput("maxrows", "Rows to show", 25),                                   # En el siguiente submenú creamos una entrada numérica para
              actionButton("refresh", "Refresh now"),                                        # seleccionar el numero de filas que queremos mostrar de los datos. 
              br(),
              br(),
              verbatimTextOutput("rawtable"),                                                # Mostramos la tabla por pantalla
              downloadButton("downloadCsv", "Download as CSV")                               # E incluimos un botón intercativo para descargar el rawta 
      ),
      
      tabItem("map",                                                                         # El siguiente panel toma la base y la hoja de estilos del ejemplo
               div(class="outer",                                                            # https://github.com/rstudio/shiny-examples/tree/master/063-superzip-example
                   tags$head(                                                                
                     includeCSS("styles.css")                                                # Hoja de estilos de la incluida en la fuente (rstudio)
                   ),
                   leafletOutput("map", width="100%", height="100%"),                             # Incluimos un objeto de tipo mapa leafleat
                   absolutePanel(id = "controls", class = "panel panel-default", fixed = TRUE,    # Se incluye el panel de seleción desplazable
                                 draggable = TRUE,
                                 top = 60, 
                                 left = "auto", 
                                 right = 20, 
                                 bottom = "auto",
                                 width = 800,
                                 height = "auto", 
                                 h2("Mapa de sensores"),                                           # Ponemos nombre al selector
                                 selectInput("parameter", "Parámetro",                             # Indicamos las selecciones para nuestro mapa
                                             choices =  c(
                                   "Status" = "fire_status",
                                   "Temperature" = "temp",
                                   "Hummidity" = "hum",
                                   "Pressure" = "press",
                                   "Charge" = "carga"
                                 )
                                 ) ,box(collapsible = TRUE, collapsed = TRUE, title = "Datos tiempo Real",                 # Agragamos una nueba caja dentro del selector
                                    div(dataTableOutput(outputId="dataTable" ), style = "font-size:75%") , width = 800     # Donde ubicaremos una tabla para mostrar los datos en tiempo real
                                 )
                   )
               )
      )
    )
  )
)




          
           
           