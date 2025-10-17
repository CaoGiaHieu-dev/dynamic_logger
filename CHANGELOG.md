## 0.3.0

- **Chore:** Updated example file to include custom log handler configuration for better console output visibility.
- **Chore:** Remove dependency.
- **Docs:** Improved README with clearer examples and output visibility instructions.

## 0.2.2

- **Feature:** Added global enable/disable capability via the `enable` parameter in `DynamicLogger.configure`. When disabled (`enable: false`), calls to `DynamicLogger.log` will be ignored.

## 0.2.1

-  Fix footer output

## 0.2.0

-  **BREAKING:** Refactored core formatting logic for significantly improved memory efficiency, especially with large data structures. Uses `StringBuffer` more effectively and reduces intermediate string creation.
-  **Feature:** Added configurable truncation for large/deep data structures:
    -  Introduced `maxDepth` and `maxCollectionEntries` limits.
    -  Added `DynamicLogger.configure` to set global defaults for truncation, limits, and the log handler.
 -  Added `truncate`, `maxDepth`, and `maxCollectionEntries` parameters to `DynamicLogger.log` for per-call overrides.
-  **Feature:** Added `DynamicLogger.formatData` static utility to format data structures into strings without logging, respecting truncation rules.
-  **Fix:** Improved JSON/List formatting to be more standard (correct indentation, quoting of strings, comma placement, handling of empty collections).
-  **Fix:** Corrected indentation for top-level primitive/string logs to align directly under the header.
-  **Fix:** Improved header/footer appearance using single-line box characters.
-  **Chore:** Removed dependency on the `collection` package.
-  **Chore:** Added internal error handling during formatting to prevent logger crashes on unexpected data.

## 0.1.1

-  Downgrade `collection` to 1.19.0

## 0.1.0

-  Initial release of DynamicLogger.