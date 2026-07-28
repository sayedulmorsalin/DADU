# Walkthrough - Redesigned Upload Screenshot Button

I have redesigned the "Upload Screenshot" button in the Checkout screen to match the requested modern card-style UI.

## Changes Made

### Checkout Screen
- **Upload Button Redesign**: Replaced the standard `ElevatedButton` for payment proof with a custom-styled card.
- **Visual Improvements**:
    - **Dark Theme Card**: Added a dark navy background (`#1E2332`) with rounded corners (20px).
    - **Styled Icon**: Centered a file upload icon with a subtle background (`#2A3B47`) and emerald green color (`#10B981`).
    - **Typography**: Added "Upload Image" as a bold primary label and "PNG, JPG, WebP supported" as a secondary helper text.
- **Interactivity**: The entire card area is now clickable via a `GestureDetector`, providing a larger and more intuitive hit target for users.

## Verification Results

### Code Analysis
- The layout uses `GestureDetector` and `Column` for a clean, vertical arrangement of elements.
- Colors were chosen to closely match the provided reference image.
- The `_pickPaymentProof` callback remains correctly linked to the new UI component.

### UI Preview (Description)
The previous orange button is now replaced by a professional-looking dark card that clearly indicates where users should click to upload their payment screenshots.

## Profile Picture Improvements
- **Loading Animation**: Added a `CircularProgressIndicator` that appears over the profile avatar in the Edit Profile dialog during the upload process.
- **Old Image Deletion**: Implemented a cleanup mechanism in `ImageService` that automatically deletes the previous profile picture from Cloudinary once a new one is successfully uploaded.
- **Signature Security**: Added SHA-1 signature generation (using the `crypto` package) to securely handle Cloudinary `destroy` API requests.
- **Feedback**: Added an "Uploading..." status text to the change button while the process is active.
