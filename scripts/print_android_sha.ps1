# Prints debug keystore SHA-1/SHA-256 for Firebase Android Google Sign-In setup.
$keytool = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin\keytool.exe' } else { 'keytool' }
$keystore = Join-Path $env:USERPROFILE '.android\debug.keystore'

Write-Host 'Add these fingerprints in Firebase Console:'
Write-Host '  Project settings -> Your apps -> Android (com.example.tarot_ai) -> SHA certificate fingerprints'
Write-Host ''
Write-Host "Keystore: $keystore"
Write-Host ''

& $keytool -list -v -keystore $keystore -alias androiddebugkey -storepass android -keypass android |
  Select-String -Pattern 'SHA1:|SHA256:'

Write-Host ''
Write-Host 'Then enable Google in Authentication -> Sign-in method,'
Write-Host 're-download android/app/google-services.json (oauth_client must not be empty),'
Write-Host 'and set GOOGLE_WEB_CLIENT_ID in lib/src/core/google_auth_config.dart or via dart-define.'
