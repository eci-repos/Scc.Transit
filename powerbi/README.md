# SCC Transit Power BI POC

Open `SccTransitPoc.pbip` in Power BI Desktop. The PBIP report connects to the local SQL Server database `SccTransitPoc` on `localhost` and imports the `mart` views.

Pages included:

1. Ridership Overview
2. Expected vs Actual
3. Service Detail
4. Coverage & Stops
5. Weather Impact
6. Operations & Context

The 2026 source data is partial-year. The Operations & Context page includes feed availability status; realtime, events, traffic, and air-quality row counts remain zero until their corresponding source feeds are loaded. Weather data can be seeded with `scripts/load_noaa_weather.ps1`.

The seed report uses source-controlled DAX measures for cards and charts. The installed Desktop build requires TMDL measures to use standard bracketed column references.
