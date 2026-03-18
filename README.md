# ShareQuest Debug Backend Settings

## Features
- Runtime API backend switching (local/remote)
- Editable local host for simulator/device
- Health check with endpoint detail
- Debug screen accessible from Profile > Settings > Developer

## Usage
1. Open Profile > Settings > Developer > API Backend
2. Switch between Local and Remote
3. Edit local host as needed
4. Tap Health Check to verify backend

## Notes
- Local mode uses http://localhost:3000/api (simulator) or your Mac LAN IP (device)
- Remote mode uses https://sharequestapp.vercel.app/api
- Health check probes multiple endpoints and shows which passed

## Commit
- feat: add runtime API backend switching and robust health diagnostics

