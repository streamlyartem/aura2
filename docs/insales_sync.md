# InSales sync (AURA -> InSales)

## Environment variables

- `INSALES_BASE_URL` - store base URL, e.g. `https://shop.myinsales.ru`
- `INSALES_LOGIN` - API login
- `INSALES_PASSWORD` - API password
- `INSALES_CATEGORY_ID` - single category to use for all products
- `INSALES_IMAGE_URL_MODE` - image URL mode: `service_url` (signed URL) or `rails_url` (rails blob URL)
- `API_HOST` - host for `rails_blob_url` (used only when `INSALES_IMAGE_URL_MODE=rails_url`)

## Rules

- One product in AURA -> one product in InSales (one variant).
- Price: `Product.retail_price`.
- SKU: `Product.sku`, fallback to `Product.code`.
- Stock: sum of all `ProductStock.stock` rows for the product.
- Category: always `INSALES_CATEGORY_ID` (AURA has no categories).

## Rake tasks

```bash
# Products
bundle exec rake insales:products

# Images
bundle exec rake insales:images

# Smoke: one product + up to 2 images
bundle exec rake insales:smoke PRODUCT_ID=... 
```

Optional env args for tasks:

- `LIMIT` - max products; when `PRODUCT_ID` is set for `insales:images`, limits images count instead
- `SINCE` - `updated_at >= SINCE` (e.g. `2025-01-01 00:00:00`)
- `PRODUCT_ID` - UUID of the product
- `ONLY_MISSING` - `true`/`false` for images
- `DRY_RUN` - `true`/`false`

## Notes

- `service_url` uses a signed ActiveStorage URL with expiration from `config.active_storage.service_urls_expire_in`.
- `rails_url` uses `image.url`, so `API_HOST` must be configured to produce a public URL.
