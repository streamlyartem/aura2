# InSales settings (ActiveAdmin)

## Где найти

ActiveAdmin → Интеграции → InSales

## Обязательные поля

- Base URL
- Login
- Password
- Category ID

Image URL Mode:
- `service_url` (по умолчанию)
- `rails_url`

## Приоритет настроек

1) InsalesSetting (запись в БД)
2) ENV (fallback)

Если записи в БД нет, используются переменные окружения.
