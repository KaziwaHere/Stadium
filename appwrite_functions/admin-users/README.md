# admin-users Appwrite Function

This function powers the Flutter admin panel. Deploy it as an Appwrite Function
with the function ID `admin-users`.

Required environment variables:

- `APPWRITE_ENDPOINT`, for example `https://fra.cloud.appwrite.io/v1`
- `APPWRITE_PROJECT_ID`, for example `6a319781003dd693dfd5`
- `APPWRITE_API_KEY`, with `users.read`, `users.write`, `databases.read`,
  `databases.write`, `rows.read`, and `rows.write` permission

The Flutter app only shows the Admin tab when the signed-in Appwrite user has an
`admin` label. Keep the function execution permissions restricted to users, and
keep the in-function admin-label check enabled.
