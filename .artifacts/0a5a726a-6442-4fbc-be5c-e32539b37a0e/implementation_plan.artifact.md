# Fix persistent order notice when no orders are present

The user is seeing an "Order Accepted" notice in the "To Ship" orders screen even when no orders are found. This is likely due to the notice visibility logic not checking for the presence of actual orders, and potentially due to legacy "garbage" data in the database being counted as orders.

## Proposed Changes

### [Component: UI] [order_list_screen.dart](file:///D:/all code/Flutter all projects/DADU/lib/screen/user/order_list_screen.dart)

#### [MODIFY] [order_list_screen.dart](file:///D:/all code/Flutter all projects/DADU/lib/screen/user/order_list_screen.dart)
- Update `_buildTopNotice()` to accept a boolean `hasItems`.
- Only return the notice widget if `hasItems` is true.
- Call `_buildTopNotice(displayedItems.isNotEmpty)` in the `build` method.

### [Component: Logic] [profile.dart](file:///D:/all code/Flutter all projects/DADU/lib/screen/user/profile.dart)

#### [MODIFY] [profile.dart](file:///D:/all code/Flutter all projects/DADU/lib/screen/user/profile.dart)
- Update `_castToList` to filter out null elements and ensure items are of expected types (Maps).
- This will ensure that if the database contains garbage data (like a list with nulls or empty strings from older versions), it won't be counted as valid orders.
- This fixes both the notice visibility on the Profile screen and the order count badges.

## Verification Plan

### Manual Verification
- Deploy the app and navigate to the "To Ship" section with a user that has no orders. Verify that the notice is gone.
- Check the Profile screen for the same user and ensure no notices or incorrect order counts are shown.
- (Optional) Simulate "garbage" data in Firestore (e.g., `to_ship: [null]`) and verify the app handles it correctly.
