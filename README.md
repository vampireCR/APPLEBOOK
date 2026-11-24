# TheAppleBook

Статический фронтенд TheAppleBook на HTML, CSS и JavaScript с Supabase Auth, Database и Storage.

- Базовая схема: `supabase/schema.sql`
- Миграция функций: `supabase/migrations/20261123_complete_features.sql`
- Edge Functions: `supabase/functions/`
- Порядок публикации и проверки: `DEPLOY.md`

Клиент использует только Supabase publishable key. Никогда не помещайте service-role key в клиентские файлы.

## Android build

See [ANDROID_GITHUB_BUILD_RU.md](ANDROID_GITHUB_BUILD_RU.md). GitHub Actions builds a debug APK using Capacitor. Firebase Cloud Messaging credentials are required before remote Android push delivery can be enabled.
