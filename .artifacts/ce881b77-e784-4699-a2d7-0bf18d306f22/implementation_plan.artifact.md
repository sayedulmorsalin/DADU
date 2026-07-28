# Implementation Plan: Comprehensive Deep Linking & Sharing

Enable sharing links and deep link handling for ALL major pages and tabs in the app. This creates a unified way to direct users to any part of the app via URLs.

## Proposed Changes

### [Android Configuration]

#### [MODIFY] [AndroidManifest.xml](file:///D:/all code/Flutter all projects/DADU/android/app/src/main/AndroidManifest.xml)
- Simplify the intent filter to a single, broad entry for `dadubd.com` and `www.dadubd.com` with `pathPrefix="/"`. This ensures any link starting with your domain is captured by the app.

### [Services]

#### [MODIFY] [DeepLinkService](file:///D:/all code/Flutter all projects/DADU/lib/services/deep_link_service.dart)
- Update `_handleDeepLink` to support a wide range of paths:
    - `/product?id=...` -> Navigates to Product Details.
    - `/brand?name=...` -> Navigates to Brand page.
    - `/category?name=...` -> Navigates to Category page.
    - `/earn-coins` -> Navigates to "Earn Coins" page.
    - `/message`, `/cart`, `/profile`, `/search` -> Switches the bottom navigation tab in `Home`.
- Implement `_switchToTab(int index)` logic using `Get.find<HomeController>()`.

### [User Interface]

#### [MODIFY] [Brand Screen](file:///D:/all code/Flutter all projects/DADU/lib/screen/product/brand.dart)
- Add a share button in the `AppBar`.

#### [MODIFY] [Category Screen](file:///D:/all code/Flutter all projects/DADU/lib/screen/product/catagory.dart)
- Add a share button in the `AppBar`.

#### [MODIFY] [RewordAd Screen](file:///D:/all code/Flutter all projects/DADU/lib/screen/user/reword_ad.dart)
- Add a share button in the `AppBar`.

#### [MODIFY] [Cart Screen](file:///D:/all code/Flutter all projects/DADU/lib/screen/user/cart.dart), [Profile Screen](file:///D:/all code/Flutter all projects/DADU/lib/screen/user/profile.dart)
- Add optional share buttons if appropriate for the user to share these pages.

## Deep Link Registry

| Page | URL | Action |
| :--- | :--- | :--- |
| **Product** | `https://dadubd.com/product?id=XYZ` | Open Product Details |
| **Brand** | `https://dadubd.com/brand?name=Nike` | Open Brand Screen |
| **Category** | `https://dadubd.com/category?name=Boots` | Open Category Screen |
| **Earn Coins**| `https://dadubd.com/earn-coins` | Open Rewards Screen |
| **Message** | `https://dadubd.com/message` | Switch to Message Tab |
| **Cart** | `https://dadubd.com/cart` | Switch to Cart Tab |
| **Search** | `https://dadubd.com/search` | Switch to Search Tab |
| **Profile** | `https://dadubd.com/profile` | Switch to Profile Tab |

## Verification Plan

### Manual Verification
1.  **Tab Switching**: Test clicking `/message`, `/cart`, `/profile`, and `/search` links while the app is in various states.
2.  **Stack Handling**: Verify that if a user is on a product details page and clicks a `/profile` link, they are taken back to the main navigation and the correct tab is selected.
3.  **App Termination**: Test opening these links while the app is completely closed.
