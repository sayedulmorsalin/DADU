# Redirect Message Icon to In-App Chat

Modify the behavior of the message icon in the `ProductDetails` screen to redirect users to the message tab on the home page instead of opening WhatsApp.

## Proposed Changes

### [Product Details Component]

#### [MODIFY] [product_details.dart](file:///D:/all%20code/Flutter%20all%20projects/DADU/lib/screen/product/product_details.dart)
- [x] Add necessary imports: `package:get/get.dart` and `package:dadu/controller/home_controller.dart`.
- [x] Implement a new method `_navigateToChat` that:
    - Finds the `HomeController` using `Get.find()`.
    - Switches the selected tab to the "Message" tab (index 3) using `homeController.onBottomNavTap(3)`.
    - Navigates back to the home screen by popping the current route.
- [x] Simplify `_buildFabMenu`:
    - Remove the multi-contact FAB menu logic (`_isFabMenuOpen`).
    - Change the `FloatingActionButton`'s `onPressed` to call `_navigateToChat` directly.
- [x] Remove unused methods and variables:
    - `_isFabMenuOpen` variable.
    - `_toggleFabMenu()` method.
    - `sendMessageToWhatsApp()` method.
    - `_buildContactOption()` method.

## Verification Plan

### Manual Verification
- Deploy the app to a device or emulator.
- Open any product details page.
- Click on the message (FAB) icon at the bottom right.
- Verify that the app redirects to the "Message" tab on the home screen.
- Verify that if the user is not logged in, the "Message" tab correctly shows the sign-up screen as per existing `Home` logic.
