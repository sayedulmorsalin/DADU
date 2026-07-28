# Implementation Plan - Profile Picture Update Improvements

Enhance the profile picture update process by adding a loading animation and implementing a mechanism to delete the old profile picture when a new one is uploaded.

## User Review Required

> [!IMPORTANT]
> - **Cloudinary Deletion**: To delete images from Cloudinary, we need to extract the `public_id` from the image URL. I will implement a deletion method in `ImageService` using the credentials in `.env`.
> - **Credentials**: I will check for `API_KEY` and `API_SECRET` in `.env` to perform the signed deletion request. If they are missing, the deletion might fail or require a backend implementation via `API_BASE_URL`.

## Proposed Changes

### [Component] Image Service

#### [MODIFY] [api.dart](file:///D:/all%20code/Flutter%20all%20projects/DADU/lib/services/api.dart)
- Add `API_KEY` and `API_SECRET` retrieval from `.env`.
- Implement `deleteImage(String imageUrl)`:
    - Extract `public_id` from the Cloudinary URL.
    - Generate a signature (SHA-1) for the deletion request.
    - Send a POST request to `https://api.cloudinary.com/v1_1/$cloudName/image/destroy`.

### [Component] Profile Screen

#### [MODIFY] [profile.dart](file:///D:/all%20code/Flutter%20all%20projects/DADU/lib/screen/user/profile.dart)
- Update `_updateProfilePicture` to accept an `oldUrl` parameter.
- After a successful new upload, call `imageService.deleteImage(oldUrl)`.
- **Loading Animation**:
    - Update the Edit Profile dialog UI to show a `CircularProgressIndicator` overlay on the `CircleAvatar` when `_isUpdatingProfilePic` is true.
    - Add a loading state for the "Change Profile Picture" button as well.

## Verification Plan

### Manual Verification
- Open the Profile screen and Edit Profile dialog.
- Change the profile picture.
- Verify the loading spinner appears during the upload.
- Check the console logs for "Image deleted" or any errors during the deletion process.
