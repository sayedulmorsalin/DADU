# Implementation Plan: Chat UI Integration

Integrate an in-app chat UI into the bottom navigation bar of the Home page. Currently, the "Message" tab opens WhatsApp; this will be replaced with a dedicated `Chat` screen.

## Proposed Changes

### [User Interface]

#### [NEW] [chat.dart](file:///D:/all code/Flutter all projects/DADU/lib/screen/user/chat.dart)
- Create a new `Chat` screen using `StatelessWidget`.
- Implement a chat bubble list (ListView).
- Add a bottom message input field with a send button.
- Use `AppColors` for consistent styling.

#### [MODIFY] [home.dart](file:///D:/all code/Flutter all projects/DADU/lib/screen/product/home.dart)
- Update `_buildCurrentPage` to include the `Chat()` screen.
- Simplify `BottomNavigationBar` `currentIndex` and `onTap` logic to directly map to `controller.selectedIndex`.

### [Controller]

#### [MODIFY] [home_controller.dart](file:///D:/all code/Flutter all projects/DADU/lib/controller/home_controller.dart)
- Update `onBottomNavTap` to remove the special handling for index 3 (Message) and instead update `selectedIndex` for all 5 tabs.

## Verification Plan

### Manual Verification
- Deploy the app.
- Click on the "Message" icon in the bottom navigation bar.
- Verify that the new Chat UI is displayed instead of opening WhatsApp.
- Verify that other tabs (Home, Cart, Search, Profile) still work correctly.
- Verify the Chat UI appearance (messages list, input field).
