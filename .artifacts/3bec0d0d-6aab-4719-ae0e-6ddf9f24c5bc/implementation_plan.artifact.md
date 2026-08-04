# Implementation Plan - Real-time Messaging with WebSockets

The goal is to update the DADU messaging system to support real-time updates using the newly added WebSocket implementation on the backend. This involves registering the WebSocket route on the backend and integrating a WebSocket client in the Flutter app.

## User Review Required

> [!IMPORTANT]
> I will be adding the `web_socket_channel` dependency to your Flutter project to handle WebSocket communication efficiently.

> [!NOTE]
> The backend WebSocket route was found in the codebase (`ws.js`) but not registered in `router.js`. I will register it as `GET /ws/:userId`.

## Proposed Changes

### Backend (Cloudflare Worker)

#### [MODIFY] [router.js](file:///D:/all code/cloudflare/dadu/my-api/src/router.js)
- Import `wsController`.
- Add `GET /ws/:userId` route to the `routes` array.

### Flutter App

#### [MODIFY] [pubspec.yaml](file:///D:/all code/Flutter all projects/DADU/pubspec.yaml)
- Add `web_socket_channel: ^3.0.1` dependency.

#### [NEW] [chat_socket_service.dart](file:///D:/all code/Flutter all projects/DADU/lib/services/chat_socket_service.dart)
- Create a service to manage WebSocket connection, authentication, and message streaming.

#### [MODIFY] [chat_controller.dart](file:///D:/all code/Flutter all projects/DADU/lib/controller/chat_controller.dart)
- Integrate `ChatSocketService`.
- Connect to WebSocket on initialization.
- Listen for real-time messages and update the `messages` list.
- Update `sendMessage` to use the WebSocket for faster delivery.

## Verification Plan

### Automated Tests
- I will verify the Dart code compiles and the backend route is correctly defined.
- Since I cannot run the Cloudflare Worker or the Flutter app in a real device with full network access to the specific backend here, I will ensure the logic for connection management, retries, and state updates is robust.

### Manual Verification
- The user should run the backend (`wrangler dev`) and the Flutter app.
- Open the chat screen and verify that messages sent from one side appear instantly on the other without refreshing.
- Verify that the "typing" status (if implemented in UI) works correctly.
