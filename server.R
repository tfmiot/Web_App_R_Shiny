# Master IoT UAH - Trabajo final de Máster (Script server.R)

# Incluimos las librerías necesarias

library(leaflet)
library(leaflet.extras)
library(scales)
library(lattice)
library(dplyr)
library(ggplot2)
library(plotly)
library(mongolite)
library(jsonlite)
library(tidyr)
library(anytime)

# Configuramos la fecha y hora del sistema al horario local Español

Sys.setenv(TZ='Europe/Madrid')
dbdata = data.frame()

# Definimos las credenciales para el acceso a la BBDD

user = 'tfmiot'
pass = 'prototipo'

# Creamos una conexión a las colecciones "datos" y "configuraciones" de la base de datos awsdb alojada en nuestra instancia

datos <- mongo("datos", url = paste0("mongodb://",user,":",pass,"@34.218.246.36:27017/awsdb"))
configraciones <- mongo("configuraciones", url = paste0("mongodb://",user,":",pass,"@34.218.246.36:27017/awsdb"))

# Funcion principal del servidor dnde establecemos la sesion e indicamos las entradas de ui.R y las salidas al interfaz

function(input, output, session) {
  
 ###########################  
 ###   Mapa Interactivo  ###
 ###########################
   
output$map <- renderLeaflet({leaflet(quakes, options = leafletOptions(zoomControl = FALSE) )%>%           # Imprimimos el mapa base en pantalla 
        addTiles() %>%                                                          
        setView(lng = -3.7044898, lat = 40.4176276, zoom = 13)                                            # Hacemos un zoom hacia la zona donde están ubicados los sensores
        })
  
checkMongoMap <- function() {                                                                             # Creamos una funcion para obtener datos de forma dinámica de mongo
  ultimoDato <- as.data.frame(datos$aggregate(ultimo,   options = '{"allowDiskUse":true}'))               # Lanzamos una conlulta para obtener el último dato de cada sensor  
  coordenadas <- configraciones$find('{}')                                                                # Realizamos una bñúsqueda sobre la colección "configuraciones" para obtener las coordenadas
  coordenadas %>%                                                                                         # Hacemos un join entre los datos y las coordenadas para poder ubicar los nodos
    select("device" = 'Device_id', 'Latitud', 'Longitud') -> coordenadas                                  # En el mapa
  ultimoDato <- merge(ultimoDato, coordenadas, by = 'device')
  
  ultimoDato %>%
    mutate(label_temp = paste("temperatura: ", temperatura, " ºC"),                                       # Agregamos unas nuevas variables al dataset para poder imprimir las etiquetas en el mapa en cada caso 
           label_hum = paste("humedad: ", humedad, " %"), 
           label_pres = paste("presion: ", presion, " hPa"), 
           label_carg = paste("carga: ", carga, " %")) -> ultimoDato
  
  ultimoDato <- mutate(ultimoDato, mindif= difftime(Sys.time(), ultimoDato$timestamp, tz = 'Europe/Madrid', units = 'mins'))     # Calculamos el tiempo de desconecxión en minutos de los nodos para verificar si han dejado de reportar
  ultimoDato <- ultimoDato[complete.cases(ultimoDato),]                                                                          # Mostramos solo los datos con valores no nulos
  return(ultimoDato)
}

MapReact <- reactiveValues(mdf=data.frame())                                                               # Creamos una nueva función reactiva para nuestra consulta, nos basamos en el ejemplo de https://github.com/mokjpn/R_IoT para programarlo

mdata <- reactivePoll(10000, session, checkMongoMap, checkMongoMap)                                        # Cada 10 segundos, chequeamos si ha entrado algun dato nuevo a la base de datos

observe({                                                                                                  # introducimos los datos actualizados en el dtaframe reactivo creado más arriba
  MapReact$mdf <- mdata()
})

nodesInBounds <- reactive({                                                                                # Funcion reactiva que nos permite cambiar de parámetro y mantener
        if (is.null(input$parameter))                                                                      # el mapa en la posicion en la que se encontraba
        return(MapReact$mdf[FALSE,])                                                                       # lo combinamos con los valores del dataset reactivo creado anteriormente 
      bounds <- input$map_bounds                                                                           # esta parte de código está basado en el ejemplo de RStudio
      latRng <- range(bounds$north, bounds$south)                                                          # https://github.com/rstudio/shiny-examples/tree/master/063-superzip-example
      lngRng <- range(bounds$east, bounds$west)
      subset(MapReact$mdf,
             latitude >= latRng[1] & latitude <= latRng[2] &
               longitude >= lngRng[1] & longitude <= lngRng[2])
    })
  

observe({                                                                                                # Funcion donde observaremos los parámetros de entrada del selector                                                                                
                                                                                                         # y el dataset reactivo autoactualizable para mostrar los nodos en el mapa    
    parameter <- input$parameter                                                                         # En primer lugar, guardamos el parámetro que esté seleccionado en el panel interactivo

  if (parameter == "fire_status"){                                                                       # Panel nodos (muestra el estado de los nodos encendidos, apagados o con fuego)

    icono <- pulseIcons(color = ifelse(MapReact$mdf$mindif <10,                                          # Comprobamos el dataset para mirar el tiempo de conexión desde que se recibió el último dato
                                       (ifelse(MapReact$mdf$fuego == 0,'green', 'red')),'gray'),         # si es menor de 10 segundos, entonces comprobamos que no haya fuego (verde), si hay alarma se pintará rojo
                      heartbeat = ifelse(MapReact$mdf$mindif <10,                                        # si el tiempo es superior a 10 segundos pintamos el nodo de gris
                                         (ifelse(MapReact$mdf$fuego == 0,0.8, 0.4)),0))                  # además manejamos también la velocidad de los pulsos del icono interactivo en uno u otro caso
    
    Lab <- MapReact$mdf$device                                                                           # indicamos las etiquetas a mostrar
    
    leafletProxy("map", data = MapReact$mdf) %>%                                                         # Pintamos nos nodos en nuestro mapa, segun los datos que entren en la funcion reactiva
      clearMarkerClusters() %>%                                                                          # y los colores y etiquetas indicadas más arriba.
      addPulseMarkers(MapReact$mdf$Longitud,
                      MapReact$mdf$Latitud,
                      clusterOptions = markerClusterOptions(),                                           # clusterzamos el mapa segun ubicacion de los nodos
                      label = Lab,
                      icon = icono)
    
  } else if (parameter == "temp"){                                                                       # Seguimos las mismas operaciones indicadas anteriomente para el parámetro temperatura
    
    icono <- pulseIcons(color = ifelse(MapReact$mdf$mindif <10,
                                ifelse(MapReact$mdf$temperatura <20,'green', 
                                ifelse(MapReact$mdf$temperatura <28,'yellow', 
                                ifelse(MapReact$mdf$temperatura <31,'orange',
                                ifelse(MapReact$mdf$temperatura <37,'red', 'darkred')))), 'gray'), 
                        heartbeat = ifelse(MapReact$mdf$mindif <10,
                                ifelse(MapReact$mdf$temperatura <20,1, 
                                ifelse(MapReact$mdf$temperatura <28, 0.9, 
                                ifelse(MapReact$mdf$temperatura <31,0.7,
                                ifelse(MapReact$mdf$temperatura <37,0.5, 0.3)))),0))
    
    Lab <- MapReact$mdf$label_temp
    
    leafletProxy("map", data = MapReact$mdf) %>%
      clearMarkerClusters() %>%
      addPulseMarkers(MapReact$mdf$Longitud,
                      MapReact$mdf$Latitud,
                      clusterOptions = markerClusterOptions(),
                      label = Lab,
                      icon = icono)
      
  } else if (parameter == "press"){                                                                       # Seguimos las mismas operaciones indicadas anteriomente para el parámetro presión
    
    icono <- weatherIcons(icon = "barometer", 
                        iconColor = 'black',markerColor = ifelse(MapReact$mdf$mindif <10,'white', 'gray'))
    
    Lab <- MapReact$mdf$label_pres
    
    leafletProxy("map", data = MapReact$mdf) %>%
      clearMarkerClusters() %>%
      addWeatherMarkers(MapReact$mdf$Longitud,
                        MapReact$mdf$Latitud,
                      clusterOptions = markerClusterOptions(),
                      label = Lab,
                      icon = icono)
  } else if (parameter == "hum"){                                                                           # Seguimos las mismas operaciones indicadas anteriomente para el parámetro humedad,
    
    icono <- weatherIcons(icon = "wi-humidity",                                                             # En los casos de la presión, humedad, temperatura y carga usamos iconos obtenids en el siguiente github
                          iconColor = 'black',markerColor = ifelse(MapReact$mdf$mindif <10,                 # https://github.com/erikflowers/weather-icons
                                                            ifelse(MapReact$mdf$humedad <10,'lightred',     
                                                            ifelse(MapReact$mdf$humedad <25,'orange', 
                                                            ifelse(MapReact$mdf$humedad <50,'lightblue',
                                                            ifelse(MapReact$mdf$humedad <65,'blue',
                                                            ifelse(MapReact$mdf$humedad <85,'darkblue', 'cadetblue'))))),'gray'))
    
    Lab <- MapReact$mdf$label_hum
    
    leafletProxy("map", data = MapReact$mdf) %>%
      clearMarkerClusters() %>%
      addWeatherMarkers(MapReact$mdf$Longitud,
                        MapReact$mdf$Latitud,
                        clusterOptions = markerClusterOptions(),
                        label = Lab,
                        icon = icono)
  }else if (parameter == "carga"){
    
    icono <- weatherIcons(icon = "wi-lightning", 
                          iconColor = 'black',markerColor = ifelse(MapReact$mdf$mindif <10,
                                                            ifelse(MapReact$mdf$carga <10,'red',     
                                                            ifelse(MapReact$mdf$carga <25,'lightred', 
                                                            ifelse(MapReact$mdf$carga <50,'orange', 'green'))), 'gray'))
    
    Lab <- MapReact$mdf$label_carg                                                                                        # Seguimos las mismas operaciones indicadas anteriomente para el parámetro carga
    
    leafletProxy("map", data = MapReact$mdf) %>%
      clearMarkerClusters() %>%
      addWeatherMarkers(MapReact$mdf$Longitud,
                        MapReact$mdf$Latitud,
                        clusterOptions = markerClusterOptions(),
                        label = Lab,
                        icon = icono)
  }
  
    
  })
  
  output$dataTable <- DT::renderDataTable({ MapReact$mdf %>%                                                              # Con el dataset reactivo y el objeto tabla creado en ui, 
      select(timestamp, device, temperatura, humedad, presion, carga)                                                     # imprimimos una tabla interactiva para mostrar el último dato de cada uno de los parámetros
    }, width = "auto" )                                                                                                   # que entra a la base de datos
  
  ###########################  
  ###       Raw data      ###
  ###########################
  
  RawData <- reactive({                                                                                                   # Funcion reactiva que lanzará una consulta a la base de datos
    input$refresh                                                                                                         # siempre que pulsemos el botón "refresh"
    all_data <- as.data.frame(datos$aggregate(data,   options = '{"allowDiskUse":true}'))
    all_data
  })
  
  output$downloadCsv <- downloadHandler(                                                                                  # función que nos devuelve como salida un csv de la consulta
    filename = "datos_bonzos.csv",                                                                                        # esta parte del código se basa en el ejemplo de Rstudio
    content = function(file) {                                                                                            # https://github.com/rstudio/shiny-examples/tree/master/087-crandash
    write.csv(RawData(), file)
    },
    contentType = "text/csv"
  )
  
  output$rawtable <-renderPrint({                                                                                         # Imprimimos la consulta realizada a mongo en pantalla
    orig <- options(width = 1000)
      print(tail(RawData(), input$maxrows))
    
  })
  

  ###########################  
  ###       Dashboard     ###
  ###########################
  
  InputData<-reactive({                                                                                              # En esta parte del código introduciremos las acciones necesarias para imprimir e interactuar con gráficos en nuestro dashboard
    parametro <- input$Parametro                                                                                     # Creamos en primer lugar una función reactiva que nos devuelva un dataset interactivo
    if(parametro == "temperatura"){                                                                                  # Una vez leemos el parámetro de enntrada haremos la quey que corresponda en cada caso
      param <- as.data.frame(datos$aggregate(temp_by_days,   options = '{"allowDiskUse":true}'))
    } else if(parametro == "humedad"){
          param <- as.data.frame(datos$aggregate(hum_by_days,   options = '{"allowDiskUse":true}'))
            }else if (parametro == "presion"){
              param <- as.data.frame(datos$aggregate(pres_by_days,   options = '{"allowDiskUse":true}'))
            }
    param <- param[param$device%in%input$Device,]                                                                    # Filtramos según el dispositivoi que indiquemos en el selector en el dataframe
    filter(param, between(as.Date(date),input$dates[1], input$dates[2]))                                             # Filtramos el dataframe según las fechas introducidas en el selector
  })
  
  checkMongo <- function() {                                                                                         # Tal y como hicimos en el mapa, creamos una funcion para la parte de tiempo real
    all_data <- as.data.frame(datos$aggregate(all,   options = '{"allowDiskUse":true}'))                             # Lanzará una consulta a mongo para obtener los últimos 30 valores
    all_data <- all_data[complete.cases(all_data),]                                                                  # Omitimos las filas con valores nulos
    all_data <- all_data[all_data$device%in%input$Device,]                                                           # Filtramos por el device o los devices activos en el selector
    return(all_data)
  }
  
  myReact <- reactiveValues(gdf=data.frame())                                                                        # Opremos igual que en el mapa (ejemplo de https://github.com/mokjpn/R_IoT)
  gdata <- reactivePoll(30000, session, checkMongo, checkMongo)                                                      # convirtiendo la query en un datafra,e reactivo y autoactualizable cada 30 segundos 
  
  observe({
    myReact$gdf <- gdata()                                                                                           # Oservamos los datos del dataframe reactivo
  })
  
   output$trace_plot <- renderPlotly({                                                                               # Construimos los difrentes gráficos de salida dentro de observación que se mantiene a la espera de entradas
     
     if(input$realTime){                                                                                             # Modo tiempo real
       
       output$mensaje1 <- renderText(paste("<b>¡MODO TIEMPO REAL ACTIVADO!</b>"))                                    # Si seleccionamos el modo tiempo real imprimimos el mensaje de aviso
       output$mensaje2 <- renderText(paste("<b>Nota:</b> Los selectores de <b>fecha</b> y <b>parámetro</b> no son funcionales en el modo tiempo real"))
       
       if(input$desglose){                                                                                           # desglose de nodos (añadimos el parametro (color a ggplot))
         myReact$gdf %>% 
           gather('Var', 'Val', c(presion, temperatura, humedad)) %>%                                                # pintamos tres graficos con cada uno de los parámetros usando facetas
           ggplot(aes(anytime(timestamp/1000),Val, color = device))+                                                 # convertimos el uts a un formato entendible por el humano para el eje x
           geom_line(size = 0.8) +                                                                                   # los gráficos serán de tipo linea
           geom_point(aes(color = device),                                                                           # añadimos marcas de puntos
                      size = 2,
                      na.rm = TRUE) +
           ylab(label = "") +
           xlab(label = "") +
           scale_x_datetime(labels = date_format("%d/%m/%Y %H:%M", tz = 'Europe/Madrid'),                            # Indicamos el formato de las etiquetas temporales del eje x
                            breaks = date_breaks("2 min"),                                                           # y el rango de 2 minutos para la escala
                            minor_breaks=date_breaks("1 hour")) +
           theme_light()+
           theme(axis.text.x = element_text(angle = 60, hjust = 1)) +                                                # Mas formatos para las etiquetas del eje X
           facet_grid(Var ~ ., scales="free_y")
       }
       else{                                                                                                         # Si no está activado el desglos por nodos, pintamos la media de los nodos seleccionados
       myReact$gdf %>% 
         gather('Var', 'Val', c(presion, temperatura, humedad)) %>% 
         ggplot(aes(anytime(timestamp/1000),Val))+
           stat_summary(fun.y="mean", geom="line", color='steelblue', size = 0.8, aes(shape="mean")) +              # para ello usamos stat summary
           stat_summary(fun.y="mean", geom="point", color='steelblue', size = 2, aes(shape="mean")) +
           ylab(label = "") +
           xlab(label = "") +
           scale_x_datetime(labels = date_format("%d/%m/%Y %H:%M", tz = 'Europe/Madrid'),
                            breaks = date_breaks("2 min"),
                            minor_breaks=date_breaks("1 hour")) +
           theme_light()+
           theme(axis.text.x = element_text(angle = 60, hjust = 1)) +
        facet_grid(Var ~ ., scales="free_y")
       }
     }
     else{                                                                                                           # operamos de la misma forma para el resto de gráficos, en este caso lo pintaremos según el parámetro de entrada
      output$mensaje1 <- renderText(paste(""))
      output$mensaje2 <- renderText(paste(""))
     if(input$Parametro == "temperatura"){
       lb <- ("Temperatura (ºC)")}
      else if(input$Parametro == "humedad"){
        lb <- ("Humedad (%)")}else if(input$Parametro == "presion"){ lb <- ("Presión (hPa)")}
     if(input$desglose){
        print(ggplotly(ggplot(InputData(), aes(x = as.Date(date), y = param, color = device)) +                       # destacar que usamos ggploy y luego convertimos el gráfico a uno ploty para que sea interactivo            
                         geom_line(size = 0.8) +
                         geom_point(aes(color = device),
                                    size = 2,
                                    na.rm = TRUE) +
                         stat_summary(fun.y="mean", geom="line", color='black', size = 0.5, aes(shape="mean")) +
                         ylab(label = lb) +
                         xlab(label = "") +
                         scale_x_date(labels = date_format("%d/%m/%Y", tz = 'Europe/Madrid'), 
                                      breaks = date_breaks("1 day")) +
                         theme_minimal() +
                         theme(axis.text.x = element_text(angle = 60, hjust = 1))))
     } else {
       print(ggplotly(ggplot(InputData(), aes(x = as.Date(date), y = param)) +
                       stat_summary(fun.y="mean", geom="line", color='steelblue', size = 0.8, aes(shape="mean")) +
                       stat_summary(fun.y="mean", geom="point", color='steelblue', size = 2, aes(shape="mean")) +
                       ylab(label = lb) +
                       xlab(label = "") +
                        scale_x_date(labels = date_format("%d/%m/%Y", tz = 'Europe/Madrid'), 
                                     breaks = date_breaks("1 day")) +
                       theme_minimal() +
                       theme(axis.text.x = element_text(angle = 60, hjust = 1))))
       
     }
     }
  })
   session$allowReconnect(TRUE)                                                                    # función para refrescar la sesión ante alguna caida                   
}


