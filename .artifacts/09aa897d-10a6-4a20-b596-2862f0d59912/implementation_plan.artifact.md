# Implementation Plan: User Blocking System

This plan details the steps to implement a user blocking system that allows administrators to block users from the admin panel, which will then restrict their ability to send messages in the mobile application.

## User Review Required

> [!IMPORTANT]
> The blocking system will rely on a new field `isBlocked` in the Firestore `users` collection.
> Existing users will not have this field, so the app must handle `null` as `false`.

## Proposed Changes

### Admin Panel (dadu_admin_panel)

#### [MODIFY] [search.dart](file:///D:/all%20code/Flutter%20all%20projects/dadu_admin_panel/lib/pages/screens/search.dart)
- Add `_isBlocked` boolean state variable.
- Update `_populateFormFields` to read `isBlocked` from the document.
- Add a switch toggle for `isBlocked` in the edit section.
- Display the blocked status in the display section.
- Include `isBlocked` in the `updatedData` map within `_updateUserProfile`.

### Mobile Application (DADU)

#### [MODIFY] [home_controller.dart](file:///D:/all%20code/Flutter%20all%20projects/DADU/lib/controller/home_controller.dart)
- Add `RxBool isBlocked = false.obs`.
- Update `_listenToCartCount` to extract `isBlocked` from the user document snapshot and update `isBlocked.value`.

#### [MODIFY] [chat_controller.dart](file:///D:/all%20code/Flutter%20all%20projects/DADU/lib/controller/chat_controller.dart)
- Add a helper getter `isBlocked` that proxies to `_homeController.isBlocked.value`.
- Update `sendMessage` to prevent sending if `isBlocked` is true (as a safety measure).

#### [MODIFY] [chat.dart](file:///D:/all%20code/Flutter%20all%20projects/DADU/lib/screen/user/chat.dart)
- Update `_buildMessageInput` to observe `controller.isBlocked`.
- Disable the `TextField` and send `IconButton` when `isBlocked` is true.
- Display a descriptive hint text or a banner when the user is blocked.

## Verification Plan

### Manual Verification
1.  **Admin Panel:**
    *   Search for a user by email.
    *   Toggle the "Blocked" switch to "Yes" and save.
    *   Verify the status is saved in Firestore.
2.  **Mobile App:**
    *   Login with the blocked user's account.
    *   Navigate to the Chat screen.
    *   Verify the input box is disabled and a "Blocked" message is shown.
    *   Attempt to send a message (e.g., via keyboard 'enter') and ensure it doesn't send.
3.  **Admin Panel:**
    *   Unblock the user.
4.  **Mobile App:**
    *   Verify the input box is re-enabled automatically (thanks to the Firestore stream).
