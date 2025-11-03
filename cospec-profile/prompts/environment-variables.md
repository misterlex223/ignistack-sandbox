Create an environment variables reference that lists:

1. **Frontend Environment Variables** (.env for React):
   - VITE_FIREBASE_API_KEY
   - VITE_FIREBASE_AUTH_DOMAIN
   - VITE_FIREBASE_PROJECT_ID
   - (all Firebase config variables)
   - Description and where to find each value
2. **Firebase Environment Variables** (Cloud Functions):
   - Function configuration variables
   - Third-party API keys
3. **Docker/WordPress Environment Variables**:
   - WP_INSTANCE_NAME
   - ANTHROPIC_AUTH_TOKEN
   - FIREBASE_TOKEN
   - ENABLE_WEBTTY
   - Port configurations
4. **Environment Variable Templates**:
   - .env.example files
   - .env.local vs .env.production
5. **Security Best Practices**:
   - What NOT to commit
   - Using .gitignore
   - Managing secrets

Format: Reference documentation with clear descriptions and security guidelines.
