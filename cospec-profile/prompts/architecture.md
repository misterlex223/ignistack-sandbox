Create a comprehensive architecture document that explains:

1. **Architecture Overview**: High-level diagram (in Mermaid or ASCII art) showing three main components
2. **Component Breakdown**:
   - **Frontend Layer**: React + Vite application structure
   - **Backend Layer**: Firebase services (Auth, Firestore, Functions)
   - **CMS Layer**: WordPress with SQLite database
3. **Data Flow**:
   - How data moves from WordPress → Firestore (via sync-fire-wp)
   - How React app reads/writes to Firestore
   - Authentication flow
4. **Key Design Decisions**:
   - Why SQLite for WordPress (development portability)
   - Benefits of WordPress as headless CMS
   - Firebase for real-time capabilities
5. **Technology Integration Points**:
   - WordPress Custom Post Types → Firestore collections
   - ACF fields → Firestore document structure
   - Firebase Authentication in React
6. **Scalability Considerations**: When to migrate from SQLite to MySQL

Format: Technical documentation with diagrams, code snippets, and clear explanations suitable for developers.
