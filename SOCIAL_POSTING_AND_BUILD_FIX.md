# Social posting + Flutter build fix

## Scheduled posts
The backend scheduler now runs:

```bash
php artisan social-media:process-scheduled
```

Laravel `routes/console.php` schedules it every minute.

Due posts become **Ready to Post** and the user receives:
- Laravel database/in-app notification
- FCM push notification when Firebase/device token configuration is available

The app then provides **Post Now**. This uses the native device share sheet.
After the user completes the post, they can choose **Mark posted**.

WhatsApp Status/Channel cannot be treated as automatically published merely
because a WhatsApp number/channel URL is stored. An authorised official
publishing capability must exist before My Digital Diary can post without
manual user action.

## Flutter analyser fixes
The listed warnings were cleaned:
- BuildContext async-gap guards
- unused Dashboard focus fallback methods
- scrollCacheExtent migration
- unused subscription helper
- unused engagement import
- Share -> SharePlus
- unnecessary speech getter/setter

## Gradle daemon crash
The supplied log says the daemon disappeared and produced `hs_err_pid15080.log`.
The project had:
- Xmx 8G
- MaxMetaspace 4G
- code cache 512M

`android/gradle.properties` now uses lower limits and two workers.

On Windows run:

```powershell
cd D:\projects\my_digital_diary\android
.\gradlew.bat --stop
cd ..
& "D:\development\flutter\bin\flutter.bat" clean
Remove-Item -Recurse -Force ".\android\.gradle" -ErrorAction SilentlyContinue
& "D:\development\flutter\bin\flutter.bat" pub get
& "D:\development\flutter\bin\flutter.bat" analyze
& "D:\development\flutter\bin\flutter.bat" run
```

If the JVM still crashes, inspect `android/hs_err_pid*.log`; that file contains
the native JVM crash reason and is more diagnostic than the daemon-disappeared
message.
