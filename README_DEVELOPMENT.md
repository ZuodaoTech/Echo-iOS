# Development Setup

## Configure Your Development Team

This project uses Xcode configuration files to manage development team settings.

### Initial Setup

1. Copy the example configuration:
   ```bash
   cp Echo/Local.xcconfig.example Echo/Local.xcconfig
   ```

2. Edit `Echo/Local.xcconfig` and add your development team ID:
   ```
   DEVELOPMENT_TEAM = YOUR_TEAM_ID
   ```

3. You can find your Team ID in:
   - Xcode → Preferences → Accounts → Select your team → View Details
   - Or in Apple Developer Portal → Membership → Team ID

### Important Notes

- `Local.xcconfig` is gitignored and won't be committed
- Never commit your personal Team ID to the repository
- Each developer should use their own Team ID

### Alternative: Manual Setup in Xcode

If you prefer, you can also set the team directly in Xcode:
1. Open the project in Xcode
2. Select the "Echo" project in the navigator
3. Select the "Echo" target
4. Go to "Signing & Capabilities" tab
5. Select your team from the dropdown

## Troubleshooting

If you see code signing errors:
1. Make sure `Local.xcconfig` exists and contains your Team ID
2. Clean the build folder: Product → Clean Build Folder (⇧⌘K)
3. Restart Xcode if necessary