# August 31, 2025

- Replaced OPEN API Key
- Chatbot Fix
- Firestore Sync
- Offline Service Verification
- Guest User posting restriction

# September 1, 2025

- Added Offline Indicator on the top of the screen to the user will know if they are offline.
- Added Offline/Online Synchronization. Users can now use the log bleed and log infusion offline or w/out internet and saved in the phone locally.

# September 6, 2025

- **Calendar View Fix**: Fixed bleeding episode dots not appearing in calendar due to date format mismatch between different date formats (YYYY-MM-DD vs Mon DD, YYYY)
- **Duplicate Removal System**: Implemented comprehensive duplicate removal across all app screens:
  - Log History Screen: Added smart deduplication for both bleeding episodes and infusion logs
  - Dashboard Recent Activities: Applied same duplicate removal logic to recent activities section
  - Smart Deduplication Logic: Prefers online (synced) records over offline records, with content-based fallback for logs without unique IDs
- **Firebase Sync Duplicate Prevention**: Enhanced offline/online synchronization to prevent duplicates at the database level:
  - Modified sync process to check existing Firebase logs before uploading
  - Content-based duplicate detection compares all key fields (date, time, location, severity, etc.)
  - Prevents duplicate creation during offline-to-online sync process
  - Maintains data integrity while eliminating redundant Firebase writes
- **Date Normalization**: Added robust date handling to support multiple date formats across the application
- **Performance Optimization**: Improved data loading and display performance by removing duplicate processing overhead
- **Admin Panel Improvements**:
  - Fixed pending post reports display issue using fallback query method to avoid Firestore index problems
  - Added comprehensive User Management system with new bottom navigation tab
  - Enhanced User Management Features:
    - View all users by type (patients, healthcare providers, admins) with real-time search
    - Approve/reject user registrations with one-click approval
    - Change user roles dynamically (patient ↔ healthcare provider ↔ admin)
    - Suspend/unsuspend users for moderation purposes
    - Send direct messages to users through admin notifications
    - Export complete user data (bleed logs, infusion logs, community posts)
    - View detailed user profiles with join dates and activity status
    - Visual status indicators (approved/pending, suspended, user type badges)
  - Enhanced admin navigation with 5-tab system: Home, Approvals, Reports, Users, Events
  - Advanced filtering and search capabilities across all user types
- **Release Build**: Successfully built and tested release APK (62.0MB) with all duplicate prevention and comprehensive admin improvements
