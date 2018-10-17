# Master IoT UAH - Trabajo final de Máster (Script global.R)

# Usaremos este script unicamente para escribir los pipelines de los aggregates a mongo, simplemente por limpieza.

# Consulta para obtener el último dato de cada dispositivo que entra a la base de datos

ultimo = 
  '[
{"$sort" : {"timestamp" : -1}},
{"$group": {
"_id" : {"device" : "$deviceID"},
"temperatura" : {"$first" : "$data.temperatura"},
"humedad" : {"$first" : "$data.humedad"},
"presion" : {"$first" : "$data.presion"},
"carga" : {"$first" : "$data.carga"},
"fuego" : {"$first" : "$data.fuego"},
"timestamp" : {"$first" : "$timestamp"}}},
{"$project" :{ "device" : "$_id.device","temperatura": 1,  "humedad" :1, "presion" : 1, "timestamp" : 1, "fuego" : 1, "carga" : 1, "_id" : 0}}
]'

# Conslta para obtener los datos agregados por día de la temperatura de cada dispositivo

temp_by_days = '[
{"$group": {
  "_id" : {"device" : "$deviceID", "date" : {"$dateToString": { "format": "%Y-%m-%d", "date": "$timestamp" }}},
  "param" : {"$avg" : "$data.temperatura"}
}},
{"$project" :{ "device" : "$_id.device","param": 1,  "date" : "$_id.date", "_id" : 0}}
]'

# Conslta para obtener los datos agregados por día de la humedad de cada dispositivo

hum_by_days = '[
{"$group": {
  "_id" : {"device" : "$deviceID", "date" : {"$dateToString": { "format": "%Y-%m-%d", "date": "$timestamp" }}},
  "param" : {"$avg" : "$data.humedad"}
}},
{"$project" :{ "device" : "$_id.device","param": 1,  "date" : "$_id.date", "_id" : 0}}
]'

# Conslta para obtener los datos agregados por día de la presión de cada dispositivo

pres_by_days = '[
{"$group": {
  "_id" : {"device" : "$deviceID", "date" : {"$dateToString": { "format": "%Y-%m-%d", "date": "$timestamp" }}},
  "param" : {"$avg" : "$data.presion"}
}},
{"$project" :{ "device" : "$_id.device","param": 1,  "date" : "$_id.date", "_id" : 0}}
]'

# Consulta que obtiene los últimos 30 datos que entran a la BBDD y que se usará para construir el gráfico de tiempo real

all = 
  '[
{"$sort" : {"_id" : -1}},
{"$project" :{ "device" : "$deviceID",
               "temperatura" : "$data.temperatura", 
               "presion" : "$data.presion", 
               "humedad" : "$data.humedad",
               "timestamp" : "$uts", 
               "_id" :0 }},
{"$limit" : 30}
]'

# Consulta estándar para facilitar la descarga del 'raw data'

data =   '[
{"$project" :{ "device" : "$deviceID",
                "serial" : "$serial",
               "temperatura" : "$data.temperatura", 
               "presion" : "$data.presion", 
               "humedad" : "$data.humedad",
               "timestamp" : "$timestamp", 
                "rtc_hours" : "$rtc.hours",
                "rtc_minutes" : "$rtc.minutes",
                "rtc_seconds" : "$rtc.seconds",
               "_id" :0 }}
]'

# Consulta para obtener la primera y últma fecha en la que hay datos alojados en la BBDD usada para el selector de fechas

fechas = '[
{"$sort" : {"_id" : -1}},
{"$group": {
  "_id" : 0,
  "max" : {"$first" : "$timestamp"},
  "min" : {"$last" : "$timestamp"}
}},
{"$project" :{ "max" : 1,
               "min" : 1,
               "_id" :0 }}
]'

