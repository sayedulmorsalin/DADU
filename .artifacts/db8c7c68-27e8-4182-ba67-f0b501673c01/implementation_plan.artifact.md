# Implementation Plan - Fix API Stock Mapping for Combo Packs

The user clarified that products are fetched via the API, not Firebase. The "Stock Out" issue occurs because the API response might be missing the `stock` field for Combo Packs, which currently defaults to `0` in the UI, marking them as unavailable.

## User Review Required

> [!IMPORTANT]
> I will change the default stock value to `1` when it's missing from the API response. This ensures products are available for purchase by default.

## Proposed Changes

### Services

#### [MODIFY] [d1.dart](file:///D:/all code/Flutter all projects/DADU/lib/services/d1.dart)
- Update `ApiService.fetchProducts` and `ApiService.fetchProductById` mappings.
- Change `stock` mapping to default to `1` if the API field is null or missing.

### Product Screens

#### [MODIFY] [combo_pack.dart](file:///D:/all code/Flutter all projects/DADU/lib/screen/product/combo_pack.dart)
- Update `ProductItem` parameters to handle null stock values by defaulting to `1`.

#### [MODIFY] [home.dart](file:///D:/all code/Flutter all projects/DADU/lib/screen/product/home.dart)
- Ensure `ProductItem` and `ProductDetails` navigation in `Home` also uses the updated default stock value.

## Verification Plan

### Manual Verification
1. Open the "Combo Pack" screen.
2. Verify products show as "Available".
3. Confirm "Add to Cart" works on these items.
