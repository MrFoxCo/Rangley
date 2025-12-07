# Rangley

**A location-based social meetup iOS app for spontaneous and planned gatherings**

Rangley makes it easy to create, discover, and join meetups in your area. Whether you're organizing a pickup basketball game, planning a coffee meetup, or looking for nearby events, Rangley connects you with people and activities around you.

---

## 🎯 Core Features

### 📍 Location-Based Meet Discovery
- **Interactive Map Interface**: Browse meets happening around you on an intuitive map view
- **Customizable Search Radius**: Adjust your search radius (1-15 miles) to find meets near or far
- **Real-time Badge Updates**: See live counts of nearby meets at a glance
- **Geofencing**: Meets are location-aware with customizable boundaries

### 🎪 Meet Creation & Management
- **Two Creation Flows**:
  - Tap anywhere on the map to create a meet at that location
  - Use the create button to select a location via picker
- **Smart Location Recognition**: Automatic address geocoding and reverse geocoding
- **Flexible Scheduling**: Set start and end times for your meets
- **Meet Categories**: Organize meets by type (Sports, Social, Food, Music, Outdoors, etc.)
- **Capacity Management**: Control the maximum number of participants

### 👥 Group System
- **Create Meet Groups**: Save your recurring friend groups for quick invites
- **Custom Group Icons**: Choose from 17+ SF Symbol icons to represent your group
- **Group Management**: Add/remove members, view member lists with owner indicators
- **Quick Group Invites**: Create meets with entire groups in one tap
- **Group-Based Meet Creation**: Skip the invite step when creating meets with saved groups

### 💬 Social Features
- **Friend System**: Send and accept friend requests
- **Meet Invitations**: Invite specific friends to your meets
- **Real-time Notifications**: Get notified about meet invites, friend requests, and updates
- **Inbox Management**: Centralized notification center with unread counts
- **Messaging**: Direct messaging between users (coming soon)

### 🔐 Authentication & Security
- **AWS Cognito Integration**: Secure authentication and user management
- **Token-Based Sessions**: Automatic token refresh and session management
- **Content Moderation**: AI-powered content filtering for meet names and descriptions
- **Trust & Safety**: Violations are flagged with appropriate user feedback

---

## 🏗️ Technical Architecture

### Frontend (iOS)
- **SwiftUI**: Modern declarative UI framework
- **MapKit**: Native iOS mapping and location services
- **CoreLocation**: Precise location tracking and geofencing
- **Combine**: Reactive state management
- **URLSession**: Async/await networking layer

### Backend
- **Vapor (Swift)**: Type-safe server-side Swift framework
- **PostgreSQL**: Relational database with PostGIS for spatial queries
- **AWS Services**:
  - Cognito for authentication
  - RDS for database hosting
  - EC2 for application hosting

### Key Design Patterns
- **MVVM Architecture**: Clear separation of concerns
- **Observable State Management**: Centralized stores for Map, Inbox, and Auth
- **Repository Pattern**: Abstracted data layer with `AuthAPI` service
- **Coordinator Pattern**: Navigation flow management

---

## 📱 App Structure

### Main Views
```
MapView
├── Interactive map with meet pins
├── NearbyMeetsBadge (expandable radius selector)
├── DockView (bottom navigation)
│   ├── MyMeets button (with invite badge)
│   ├── Create Meet button
│   └── Search (users/meets)
└── MeetOverlay (selected meet details)

MyMeetsView
├── Owned Meets (collapsible)
├── Joined Meets (collapsible)
├── Invitations (collapsible)
└── Groups Tab
    └── Meet Group Cards Grid

InboxView
├── Friend Requests
├── Meet Invitations
└── System Notifications

MeetCreationFlow
├── Location Selection
├── Meet Details (name, time)
├── Friend Invites (or Group Selection)
└── Review & Create
```

### Data Models
- **ViewMeetsModel**: Meet data with location, time, category, participants
- **ViewUsersModel**: User profile with username, display name
- **ViewNotificationsModel**: Typed notifications with JSON payloads
- **MeetGroup**: Saved groups with members and custom icons
- **GroupMember**: Group membership with owner flag

---

## 🔧 Key Components

### State Management
```swift
MapDataStore         // Meets, location data, map state
InboxStore           // Notifications, invites, badges
AuthStateStore       // Authentication, user session
LocationData         // User location, permissions
UIStateStore         // UI overlays, navigation state
```

### API Layer
```swift
AuthAPI.swift
├── Authentication (signIn, signOut, refresh)
├── Meets (create, view, delete, leave, join)
├── Users (search, friends, profiles)
├── Groups (create, invite, manage members)
├── Notifications (view, respond, mark read)
└── Content Moderation (validation checks)
```

### Custom UI Components
- **NearbyMeetsBadgeView**: Floating badge with radius selector
- **DockView**: Bottom navigation with glassmorphic background
- **MeetCreationUnifiedFormView**: Multi-step meet creation wizard
- **CollapsibleMeetCard**: Expandable meet detail cards
- **ThemedDatePicker**: Custom styled date/time picker

---

## 📊 Data Flow

### Meet Creation Flow
```
User Taps Map → Location Selected → Confirmation Popup → 
Form (Name → Start → End → Invites → Review) → 
API Call → Content Validation → Success/Error → 
Confetti Animation → Dismiss → Map Refresh
```

### Notification Flow
```
Backend Event → Push Notification → InboxStore Update → 
Badge Count Update → User Opens Inbox → 
Notification Card → Accept/Decline Action → 
API Call → Store Refresh → UI Update
```

### Group Meet Creation
```
Group Detail → "Create Meet with Group" → 
Pre-populated Invites → Skip Invite Step → 
Location → Name → Times → Review → Create → 
All Group Members Invited Automatically
```

---


## 🤝 Contributing

Rangley is currently a private project, but contributions are welcome! If you'd like to contribute:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow Swift style conventions
- Use SwiftUI best practices
- Add comments for complex logic
- Test on multiple iOS versions and device sizes
- Ensure accessibility features work correctly

---

## 📄 License

This project is proprietary software created by Anthony Guzzardo / Mr. Fox, LLC.

---

## 👨‍💻 Author

**Anthony Guzzardo**  
Full-Stack Software Engineer  
Chicago, IL

- GitHub: [@anthonyguzzardo](https://github.com/anthonyguzzardo)
- LinkedIn: [Anthony Guzzardo](https://www.linkedin.com/in/anthony-guzzardo)

---

## 🙏 Acknowledgments

- **DePaul University** - Computer Science Program
- **AWS Cognito** - Authentication infrastructure
- **MapKit Team** - Excellent mapping framework
- **SwiftUI Community** - Endless inspiration and resources

---

## 📞 Support

For bug reports, feature requests, or questions:
- **Email**: anthony@mrfoxco.com

---

**Built with ❤️ in Chicago**