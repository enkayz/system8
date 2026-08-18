# GitHub discovery keywords for portable land-asset portals

This is a discovery index, not an endorsement or dependency lockfile. Verify repository ownership, release activity, security posture, licence compatibility, accessibility, browser support, data terms and government assurance before adoption. Some services expose data rather than reusable software; do not assume an API or redistribution right exists.

## Australian data and interoperability

Search terms:

```text
Landgate SLIP spatial services cadastral parcels WA WMS WFS WMTS ArcGIS REST
NationalMap TerriaJS catalogue CKAN data.gov.au DCAT-AP GeoJSON
GDA2020 GDA94 EPSG 7844 coordinate transformation Australian geospatial
OGC API - Features OGC API - Tiles OGC API - Records WMS WFS WMTS
Australian address G-NAF geocoding PSMA Geoscape licensing
```

Compatibility targets:

- **Landgate / SLIP:** treat services, datasets, licences and credentials as source-specific adapters.
- **NationalMap:** catalogue and layer compatibility patterns associated with TerriaJS; verify each source's terms.
- **data.gov.au:** dataset discovery and metadata publishing; test current catalogue/API behaviour before integration.
- **ArcGIS REST and OGC services:** adapters at the boundary, never provider-specific fields in the canonical core.
- **GeoJSON, KML, CSV, GeoPackage, FlatGeobuf and GeoParquet:** candidate interchange formats selected by workload and consumer support.

## Browser maps and visualisation

```text
MapLibre GL JS vector tiles style specification PMTiles
OpenLayers WMS WFS WMTS GeoJSON temporal layer
Leaflet accessible map plugins marker clustering
TerriaJS NationalMap catalogue model
CesiumJS 3D Tiles terrain time dynamic data
NASA WorldWind WebWorldWind
 deck.gl geospatial visualization trips layer timeline
kepler.gl geospatial exploration
```

Candidate libraries to assess:

- MapLibre GL JS — vector-map rendering and open style ecosystem.
- OpenLayers — broad OGC and projection support.
- Leaflet — lightweight 2D maps with a large plugin ecosystem.
- TerriaJS — catalogue-driven geospatial portals and the technology family used by NationalMap.
- CesiumJS — 3D globe, terrain, 3D Tiles and time-dynamic visualisation.
- deck.gl — GPU layers, including time-oriented trip/path visualisations.

## Spatial services and storage

```text
PostGIS PostgreSQL spatial database temporal tables
GeoServer OGC WMS WFS WMTS vector tiles
pygeoapi OGC API Features Records Tiles Processes
GDAL ogr2ogr coordinate transformation GeoPackage FlatGeobuf GeoParquet
PROJ GDA2020 GDA94 transformation grids
STAC SpatioTemporal Asset Catalog imagery history
TiTiler Cloud Optimized GeoTIFF COG dynamic tiles
Martin pg_tileserv tegola vector tile server
PMTiles tippecanoe planetiler tileserver-gl
GeoNetwork pycsw OGC API Records metadata catalogue
```

## Parcels, land and public catalogue features

```text
cadastral parcel viewer property boundary land tenure land administration
land asset register surplus property disposal public sale portal
parcel identifier spatial search point in polygon address geocoder
planning scheme zoning heritage environment infrastructure overlays
public asset catalogue map list accessibility WCAG
GeoDCAT DCAT-AP dataset provenance lineage ISO 19115
```

## Temporal and historical map discovery

```text
time enabled WMS TIME temporal GIS timeline slider historical imagery
OpenLayers time slider MapLibre temporal layers Cesium clock timeline
STAC datetime collections item search COG mosaic
map compare swipe layer version history event sourcing geospatial
```

For global imagery/data discovery, search **NOAA** open-data catalogues and **Soar.Earth** documentation separately. Treat them as candidate data/provider integrations only after checking API availability, coverage, attribution, redistribution and commercial-use terms. Do not describe either as a built-in dependency.

## Public APIs, search and content

```text
OpenAPI land asset API JSON Schema event sourcing
CKAN API DCAT metadata catalogue
Meilisearch OpenSearch PostgreSQL full text geospatial search
headless CMS static site government design system WCAG 2.2
subscription notifications webhook RSS Atom GeoRSS
```

## Microsoft and legacy migration

```text
Power Pages solution export PAC CLI Dataverse schema export portal configuration
Power Platform ALM managed unmanaged solution environment variables connection references
Office Scripts Excel TypeScript Power Automate workbook automation
VBA macro inventory oletools olevba signed macros COM ActiveX migration assessment
IIS inventory appcmd Microsoft.Web.Administration ASP.NET modernization .NET Upgrade Assistant
SharePoint migration assessment workflow forms web parts
```

Use separate analyzers for Office VBA and IIS/.NET. VBA-to-Office-Scripts automation is not a general source-to-source conversion; search for dependency inventory, test extraction and rewrite assistance rather than promises of complete automatic conversion.

## Security and assurance

```text
TLS certificate inventory Schannel IIS bindings cipher suites
DLP simulation Microsoft Purview policy tips false positive
file malware scanning ClamAV ICAP content disarm reconstruction
SBOM SLSA signed release provenance dependency review
OWASP ASVS API Security Top 10 threat modeling
```

## Selection record

For every adopted repository record:

1. source URL and exact version/commit;
2. licence and notice obligations;
3. maintainer/release/security activity;
4. accessibility and browser evidence;
5. data/API terms, attribution and redistribution rights;
6. deployment and exit path;
7. vulnerability and dependency scan;
8. approved owner and rollback/replacement plan.
