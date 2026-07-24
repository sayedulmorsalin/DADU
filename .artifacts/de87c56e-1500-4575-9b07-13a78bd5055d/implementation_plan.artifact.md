# Implementation Plan - Fix Navigation Data Source and Notification Images

The root cause of the navigation failure is that `DeepLinkService` was looking for product data in Firestore, while the app's primary data source for products is now an external API accessed via `ApiService`. Additionally, we will refine the notification payload to ensure images are displayed correctly.

## Proposed Changes

### [DADU App]

#### [MODIFY] [DeepLinkService.dart](file:///D:/all code/Flutter all projects/DADU/lib/services/deep_link_service.dart)
- Import `ApiService` from `package:dadu/services/d1.dart`.
- Replace `dataBase _db = dataBase()` with `ApiService _apiService = ApiService()`.
- Update `_navigateToProduct` to use `_apiService.fetchProductById(productId)` instead of `_db.getProductById(productId)`.
- Keep the `_waitForNavigator` logic as it is essential for cold starts.

### [Admin Panel - Cloud Functions]

#### [MODIFY] [index.js](file:///D:/all code/Flutter all projects/dadu_admin_panel/functions/index.js)
- Ensure the `notification` block is correctly populated for all platforms.
- Add `tag` and `body_loc_key` potentially? No, let's stick to basics but ensure `priority: 'high'` is correctly set for Android. (It is already set).
- One common issue with images is the `mutable-content` flag. I will add it to the general `notification` options if possible, though it's mainly for APNs. For Android, `image` should be sufficient.

## Verification Plan

### Manual Verification
1.  **Test Navigation:** Send a notification. Click it. Verify that "Pushing ProductDetails page for: [Product Name]" appears in the logs and the screen opens.
2.  **Verify Data Source:** Ensure the logs show `Parsed Product ID` matching what was sent.
3.  **Check Image:** Verify if the image shows up in the notification tray.

> [!IMPORTANT]
> The app must be logged in (even anonymously) for `ApiService` to work, as it requires a Firebase ID Token. `DeepLinkService` already waits for the navigator, which usually implies the app has started its initialization flow.
