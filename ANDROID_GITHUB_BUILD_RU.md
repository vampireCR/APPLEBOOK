# Сборка TheAppleBook для Android через GitHub Actions

В репозитории добавлен workflow `.github/workflows/android-apk.yml`.

1. Загрузите обновлённый проект в GitHub в ветку `main`.
2. Откройте вкладку **Actions**.
3. Выберите **Build TheAppleBook Android APK**.
4. Нажмите **Run workflow**.
5. После завершения откройте запуск workflow и скачайте artifact `TheAppleBook-Android-debug`.

Workflow создаёт нативную оболочку Capacitor и собирает `app-debug.apk`. Это debug-сборка для тестирования, не подписанный релиз для Google Play.

## Push-уведомления Android

В приложении добавлена регистрация Android-токена через Capacitor Push Notifications и сохранение токена в `public.push_devices`. Для фактической доставки push-сообщений дополнительно нужны:

- проект Firebase для Android;
- `google-services.json` для Android package ID `com.theapplebook.app`;
- подключение Firebase Cloud Messaging в нативной Android-сборке;
- серверная функция-отправитель FCM с секретом service account. Секрет нельзя помещать в браузерный JavaScript или GitHub публичный репозиторий.

Без этих Firebase-секретов APK собирается, а регистрация push-токена может быть подготовлена, но удалённая доставка push ещё не активирована. В веб-версии можно разрешить уведомления браузера; показ локальных уведомлений работает, пока браузер/приложение поддерживает активную сессию.

## Синхронизация веб-файлов

Папка `www/` — webDir Capacitor. При изменении корневых `app.js`, `index.html`, `style.css`, `manifest.json`, `service-worker.js` и других фронтенд-файлов их нужно копировать в `www/` перед Android-сборкой. В переданном архиве копии уже синхронизированы.
