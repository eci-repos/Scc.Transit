# Transit data input

`scc_transit_poc_2024_2026.csv` is the dashboard POC input file. It is loaded into `staging.RawTransitData` by `scripts/load_poc.ps1` and transformed into the dimensional warehouse tables.

Refresh the source file with:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/build_scc_transit_poc_csv.ps1
```

The current file is intentionally retained as a versioned POC input. For production-scale refreshes, move large raw extracts to external storage and keep only a small sample or manifest in Git.
