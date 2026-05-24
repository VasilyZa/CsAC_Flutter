# CsAC Mobile

Flutter mobile client for the UniCsAC HTTP API.

## Features

- Login with PHP session cookie persistence.
- Restore saved sessions on startup.
- Show explicit session restore, expired-session, and offline-cache states.
- List private and group conversations.
- Search conversations by name, remark, or cached subtitle text.
- Lookup users before sending friend requests and filter public groups locally.
- Add friends by UID and apply to join groups by room ID or public group list.
- View user details, group details, group notices, and group member lists.
- Auto refresh the conversation list and refresh it again after leaving a chat.
- Manage friends and groups from details: edit friend remarks, delete/block friends, view common groups, copy group IDs/invite codes, leave groups, and manage group members.
- Cache the last signed-in user, conversations, and messages in local SQLite.
- Open chats from local history first, then incrementally sync newer messages.
- Keep cached conversations readable when the API is offline or the session cannot be refreshed.
- Search cached chat history with filters for all, friends, groups, images, and essence messages.
- Open a message search result directly in the matching chat and jump to that message.
- Bottom navigation for chats, cached message search, notices, and profile.
- Notice center with unread badges, notice detail, copy/open actions, and mark-read controls.
- Friend request review with agree/refuse actions.
- Group join application review with pass/refuse actions for managed groups.
- Settings page with refresh, logout, and local cache clearing.
- Persist theme mode and language preferences.
- Show in-app new-message hints when unread chat counts increase.
- Send text messages and auto refresh every 4 seconds.
- Long-press messages to copy text, copy/open image links, reply, recall, or toggle essence.
- Reply to text and image messages with quoted sender/snippet and tap-to-jump.
- Mention selected group members when sending text or image messages.
- Open the group essence message list and jump back to the original chat message.
- Show image messages with preview, copy-link, open, and app-document download actions.
- Send local images from the gallery with an optional caption.
- Handles the server-side `__test` JavaScript challenge used by the CsAC API.

## Build

Flutter is installed locally at `D:\flutter\bin\flutter.bat` on this machine:

```powershell
& D:\flutter\bin\flutter.bat pub get
& D:\flutter\bin\flutter.bat run
```

Android release APK:

```powershell
& D:\flutter\bin\flutter.bat build apk --release
```
