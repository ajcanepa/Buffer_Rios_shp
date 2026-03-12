# =============================================================================
# SCRIPT: Ríos Arlanzón, Vena y Ubierna desde Shapefile local del CNIG/IGN
#         Buffer 60 m + Exportación a KMZ
# =============================================================================

# -----------------------------------------------------------------------------
# 1. LIBRERÍAS
# -----------------------------------------------------------------------------

library(sf) # Lectura, manipulación y exportación de datos espaciales
library(tidyverse) # Filtrado y manipulación de tablas de atributos
library(zip) # Compresión del KML en KMZ


# -----------------------------------------------------------------------------
# 2. CONFIGURACIÓN DE RUTAS (AJUSTA ESTAS RUTAS A TU EQUIPO)
#    Descarga el shapefile desde:
#    https://mirame.chduero.es/chduero/viewer --> Arriba/Drecha Catálogo
#    https://centrodedescargas.cnig.es/CentroDescargas/hidrografia
#    https://www.miteco.gob.es/es/cartografia-y-sig/ide/descargas/agua/red-hidrografica.html # Otra opcion
#    y descomprime en una carpeta. Apunta la ruta aquí abajo.
# -----------------------------------------------------------------------------

# Ruta al shapefile de la capa de ríos/cauces del CNIG
# Nombres típicos del archivo según el producto descargado:
#   - IGR Hidrografía:  "HY_PhysicalWaters_Watercourses.shp" (INSPIRE)
#   - BTN25:            "HID_Hidrografia_Cauce.shp" o similar
#   - BCN200:           "hidrografia_l.shp"
#
# CAMBIA esta ruta por la ubicación real en tu equipo:

ruta_shp <- "Duero_Rios_Duero_20260312/Duero_Rios_Duero_20260312.shp"
# ruta_shp <- "C:/datos/btn25/HID_Hidrografia_Cauce.shp"   # Alternativa BTN25

# -----------------------------------------------------------------------------
# 3. EXPLORACIÓN PREVIA DEL SHAPEFILE
#    Antes de filtrar, inspeccionamos el archivo para identificar:
#    - Nombre de la columna que contiene el nombre del río
#    - Cómo aparecen escritos los nombres (tildes, mayúsculas, etc.)
# -----------------------------------------------------------------------------

# Leemos las primeras filas sin cargar todo en memoria (muy útil para archivos grandes)
cabecera <- st_read(
  ruta_shp,
  query = "SELECT * FROM \"Duero_Rios_Duero_20260312\" LIMIT 20"
)

# Mostramos los nombres de las columnas disponibles
cat("Columnas disponibles en el Shapefile:\n")
print(names(cabecera))

# Mostramos una muestra de nombres de ríos para ver el formato
# (ajusta el nombre de la columna según lo que veas arriba)
cat("\nMuestra de nombres de ríos:\n")
print(head(cabecera$nombre, 20)) # columna típica en datos INSPIRE del IGN
# print(head(cabecera$NOMBRE, 20))    # columna típica en BTN25 / BCN200

# -----------------------------------------------------------------------------
# 4. IDENTIFICAR EL NOMBRE EXACTO DE LA COLUMNA DE NOMBRES
#    Según el producto descargado, la columna de nombres puede llamarse:
#      - "localname"  (IGR Hidrografía INSPIRE)
#      - "NOMBRE"     (BTN25)
#      - "NOM_RIO"    (algunos productos del MITECO)
#      - "name"       (OpenStreetMap)
#    Ajusta la variable col_nombre según lo que hayas visto en el paso 3.
# -----------------------------------------------------------------------------

col_nombre <- "nombre" # <-- AJUSTA según tu shapefile


# -----------------------------------------------------------------------------
# 5. LECTURA OPTIMIZADA: SOLO PROVINCIA DE BURGOS
#    Para evitar cargar todo España en memoria, leemos solo el bbox de Burgos.
#    st_read() con la opción wkt_filter aplica un filtro espacial en la lectura,
#    lo que es mucho más eficiente que leer todo y luego filtrar.
# -----------------------------------------------------------------------------

# Definimos el polígono de recorte de la provincia de Burgos como WKT
#bbox_burgos_wkt <- "POLYGON((-4.10 41.80, -2.90 41.80, -2.90 43.00, -4.10 43.00, -4.10 41.80))"

# Leemos solo los elementos dentro del bbox de Burgos
message(">>> Leyendo shapefile (filtrado espacial por bbox de Burgos)...")
#hidrografia_burgos <- st_read(ruta_shp, wkt_filter = bbox_burgos_wkt)
Rios_Burgos <- hidrografia_burgos <- st_read(ruta_shp)

message(
  ">>> Elementos cargados en el bbox de Burgos: ",
  nrow(Rios_Burgos)
)

# Vemos qué ríos están disponibles en la zona de Burgos
cat("\nRíos disponibles en la zona de Burgos:\n")
print(sort(unique(Rios_Burgos[[col_nombre]])))


# -----------------------------------------------------------------------------
# 6. FILTRADO DE LOS TRES RÍOS DE INTERÉS
#    Usamos grepl() con ignore.case = TRUE para no depender de tildes o
#    mayúsculas exactas. Si los nombres no coinciden, ajusta los patrones.
# -----------------------------------------------------------------------------

rios_interes <-
  Rios_Burgos %>%
  filter(
    grepl("Río Arlanzón", .data[[col_nombre]], ignore.case = TRUE) |
      grepl("Río Vena", .data[[col_nombre]], ignore.case = TRUE) |
      grepl("Río Ubierna", .data[[col_nombre]], ignore.case = TRUE)
  )

message(">>> Segmentos encontrados para los 3 ríos: ", nrow(rios_interes))

# Verificamos cuáles se han encontrado
cat("\nRíos filtrados:\n")
print(table(rios_interes[[col_nombre]]))


# -----------------------------------------------------------------------------
# 7. ESTANDARIZACIÓN: CREAR COLUMNA "rio" CON NOMBRE LIMPIO
#    Normalizamos los nombres para que en el KMZ aparezca "Arlanzón",
#    "Vena" o "Ubierna" independientemente de cómo estén en el shapefile.
# -----------------------------------------------------------------------------

# rios_interes <- rios_interes %>%
#   mutate(
#     rio = case_when(
#       grepl("Arlanz", .data[[col_nombre]], ignore.case = TRUE) ~ "Arlanzón",
#       grepl("Vena", .data[[col_nombre]], ignore.case = TRUE) ~ "Vena",
#       grepl("Ubierna", .data[[col_nombre]], ignore.case = TRUE) ~ "Ubierna",
#       TRUE ~ "Desconocido"
#     )
#   )

# Nos quedamos solo con las columnas que necesitamos
rios_limpios <- rios_interes %>%
  select(nombre, geometry)


# -----------------------------------------------------------------------------
# 8. REPROYECCIÓN A ETRS89 / UTM ZONA 30N (EPSG:25830) PARA EL BUFFER
#    El buffer en metros requiere un CRS proyectado.
#    Verificamos primero el CRS original del shapefile.
# -----------------------------------------------------------------------------

cat("\nCRS original del shapefile:\n")
print(st_crs(rios_limpios))

# Reproyectamos a EPSG:25830 (sistema oficial de España peninsular)
rios_utm <- st_transform(rios_limpios, crs = 25830)
message(">>> Reproyectado a EPSG:25830 (ETRS89 / UTM zona 30N)")


# -----------------------------------------------------------------------------
# 9. HOMOGENEIZACIÓN DE GEOMETRÍAS
#    El shapefile puede contener mezcla de LINESTRING y MULTILINESTRING.
#    Las convertimos todas a MULTILINESTRING para evitar errores en st_buffer.
# -----------------------------------------------------------------------------

rios_utm <- st_cast(rios_utm, "MULTILINESTRING")
message(">>> Geometrías homogeneizadas a MULTILINESTRING")


# -----------------------------------------------------------------------------
# 10. BUFFER DE 60 METROS (ZONA DE RIBERA)
# -----------------------------------------------------------------------------

rios_buffer_utm <- st_buffer(
  rios_utm,
  dist = 60, # 60 metros = zona de ribera estimada
  endCapStyle = "ROUND", # Extremos redondeados
  joinStyle = "ROUND" # Uniones suaves entre segmentos
)

message(">>> Buffer de 60 m aplicado")


# -----------------------------------------------------------------------------
# 11. DISOLVER POLÍGONOS POR RÍO
#     st_union() por grupo elimina solapamientos entre segmentos del mismo río,
#     generando un único polígono (o multipolígono) por cauce.
# -----------------------------------------------------------------------------

rios_disueltos <-
  rios_buffer_utm %>%
  group_by(nombre) %>%
  summarise(
    geometry = st_union(geometry),
    .groups = "drop"
  )

message(
  ">>> Polígonos disueltos: ",
  nrow(rios_disueltos),
  " entidades (una por río)"
)
print(rios_disueltos)


# -----------------------------------------------------------------------------
# 12. REPROYECCIÓN A WGS84 (EPSG:4326) — OBLIGATORIO PARA KML/KMZ
# -----------------------------------------------------------------------------

rios_wgs84 <- st_transform(rios_disueltos, crs = 4326)
message(">>> Reproyectado a WGS84 para exportación KML")


# -----------------------------------------------------------------------------
# 13. AÑADIR METADATOS Y ESTILOS DE COLOR PARA GOOGLE EARTH
# -----------------------------------------------------------------------------

rios_wgs84 <-
  rios_wgs84 %>%
  mutate(
    descripcion = paste0(
      "Zona de ribera del río ",
      nombre,
      " (buffer 60 m) | Fuente: IGN/CNIG"
    ),
    OGR_STYLE = case_when(
      nombre == "Río Arlanzón" ~ "BRUSH(fc:#661E90FF);PEN(c:#1E90FF,w:2px)", # Azul
      nombre ==
        "Río Arlanzón (Brazo)" ~ "BRUSH(fc:#661E90FF);PEN(c:#1E90FF,w:2px)", # Azul
      nombre == "Río Vena" ~ "BRUSH(fc:#6632CD32);PEN(c:#32CD32,w:2px)", # Verde
      nombre == "Río Ubierna" ~ "BRUSH(fc:#66FF8C00);PEN(c:#FF8C00,w:2px)", # Naranja
      TRUE ~ "BRUSH(fc:#660000FF);PEN(c:#0000FF,w:2px)"
    )
  )


# -----------------------------------------------------------------------------
# 14. VERIFICACIÓN FINAL ANTES DE EXPORTAR
# -----------------------------------------------------------------------------

cat("\n===== RESUMEN FINAL =====\n")
cat("Número de ríos en la capa:", nrow(rios_wgs84), "\n")
cat("Ríos incluidos:", paste(rios_wgs84$nombre, collapse = ", "), "\n")
cat("CRS de exportación:", st_crs(rios_wgs84)$input, "\n")
cat("Bounding box:\n")
print(st_bbox(rios_wgs84))

# Visualizamos
# Un mapa simple, coloreando por nombre
# Definimos los colores equivalentes (sin alpha, en formato estándar R)
col_relleno <- c(
  "Río Arlanzón" = "#1E90FF", # azul
  "Río Arlanzón (Brazo)" = "#1E90FF", # azul
  "Río Vena" = "#32CD32", # verde
  "Río Ubierna" = "#FF8C00" # naranja
)

col_borde <- c(
  "Río Arlanzón" = "#1E90FF",
  "Río Arlanzón (Brazo)" = "#1E90FF",
  "Río Vena" = "#32CD32",
  "Río Ubierna" = "#FF8C00"
)

ggplot() +
  geom_sf(
    data = rios_wgs84,
    aes(fill = nombre, color = nombre),
    linewidth = 0.4
  ) +
  scale_fill_manual(values = col_relleno, na.value = "#0000FF") +
  scale_color_manual(values = col_borde, na.value = "#0000FF") +
  coord_sf(expand = FALSE) +
  theme_minimal() +
  labs(
    title = "Zonas de ribera (buffer 60 m)",
    subtitle = "Río Arlanzón, brazo, Vena y Ubierna",
    fill = "Río",
    color = "Río"
  )


# -----------------------------------------------------------------------------
# 15. EXPORTAR A KML
# -----------------------------------------------------------------------------

ruta_kml <- "rios_burgos_buffer.kml"

st_write(
  obj = rios_wgs84,
  dsn = ruta_kml,
  layer = "rios_burgos_buffer",
  driver = "KML",
  delete_dsn = TRUE # Sobreescribe si ya existe
)

message(">>> KML generado: ", ruta_kml)


# -----------------------------------------------------------------------------
# 16. COMPRIMIR A KMZ
# -----------------------------------------------------------------------------

ruta_kmz <- "rios_burgos_buffer.kmz"

zip::zip(
  zipfile = ruta_kmz,
  files = ruta_kml,
  mode = "cherry-pick"
)

message(">>> ¡KMZ generado correctamente!: ", ruta_kmz)
message(">>> Abre el archivo en Google Earth Pro o importa en QGIS.")
