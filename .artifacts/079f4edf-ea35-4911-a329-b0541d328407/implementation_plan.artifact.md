# Implementation Plan - Top Notification Sheet

The user wants the notification sheet to slide down from the top instead of sliding up from the bottom. I will implement this using `showGeneralDialog` with a custom `SlideTransition`.

## Proposed Changes

### [Component] Notification Sheet UI

#### [MODIFY] [notification_sheet.dart](file:///D:/all code/Flutter all projects/DADU/lib/component/notification_sheet.dart)
- Replace `showModalBottomSheet` with `showGeneralDialog`.
- Implement `transitionBuilder` to animate the sheet from the top.
- Adjust the layout:
    - Change `borderRadius` from `vertical(top: ...)` to `vertical(bottom: ...)`.
    - Move the "drag handle" to the bottom of the sheet.
    - Ensure the sheet is positioned at the top of the screen.

## Verification Plan

### Manual Verification
1. **Open Sheet:** Click the notification icon. Verify the sheet slides down smoothly from the top.
2. **Close Sheet:** Swipe up or click the "Close" button. Verify it slides back up.
3. **UI Consistency:** Ensure all existing features (Mark all read, Clear all, Swipe to delete, Deep link navigation) still work perfectly in the new top-down orientation.
