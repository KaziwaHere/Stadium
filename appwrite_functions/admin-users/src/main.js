import {
  Client,
  ID,
  Permission,
  Query,
  Role,
  Users,
} from "node-appwrite";

const UID_REGEX = /^(?!_)[A-Za-z0-9_]{1,36}$/;
const USERS_CACHE_TTL_MS = 30_000;
const ADMIN_CACHE_TTL_MS = 5 * 60_000;
const ADMIN_MANAGED_ROLES = new Set(["admin", "manager"]);
const DATABASE_ID = "stadium_booking";
const BOOKINGS_TABLE_ID = "bookings";
const BOOKED_SLOTS_TABLE_ID = "booked_slots";
const STADIUMS_TABLE_ID = "stadiums";
const ACTIVE_STATUS = "active";
const PENDING_STATUS = "pending";
const DENIED_STATUS = "denied";
const CANCELLED_STATUS = "cancelled";
const RESERVED_SLOT_STATUSES = new Set([ACTIVE_STATUS, PENDING_STATUS]);

const usersCache = {
  expiresAt: 0,
  users: null,
};

const adminCache = new Map();

function tablesUrl(path) {
  return new URL(`${process.env.APPWRITE_ENDPOINT}/tablesdb${path}`);
}

function tablesHeaders(extra = {}) {
  return {
    "X-Appwrite-Project": process.env.APPWRITE_PROJECT_ID,
    accept: "application/json",
    ...extra,
  };
}

function createTables(client) {
  return {
    listRows(databaseId, tableId, queries = []) {
      return client.call(
        "GET",
        tablesUrl(`/${databaseId}/tables/${tableId}/rows`),
        tablesHeaders(),
        { queries },
      );
    },
    createRow(databaseId, tableId, rowId, data, permissions = []) {
      return client.call(
        "POST",
        tablesUrl(`/${databaseId}/tables/${tableId}/rows`),
        tablesHeaders({ "content-type": "application/json" }),
        { rowId, data, permissions },
      );
    },
    getRow(databaseId, tableId, rowId) {
      return client.call(
        "GET",
        tablesUrl(`/${databaseId}/tables/${tableId}/rows/${rowId}`),
        tablesHeaders(),
      );
    },
    updateRow(databaseId, tableId, rowId, data, permissions) {
      return client.call(
        "PATCH",
        tablesUrl(`/${databaseId}/tables/${tableId}/rows/${rowId}`),
        tablesHeaders({ "content-type": "application/json" }),
        { data, permissions },
      );
    },
    deleteRow(databaseId, tableId, rowId) {
      return client.call(
        "DELETE",
        tablesUrl(`/${databaseId}/tables/${tableId}/rows/${rowId}`),
        tablesHeaders({ "content-type": "application/json" }),
      );
    },
  };
}

function extractUserId(value) {
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (UID_REGEX.test(trimmed)) {
      return trimmed;
    }

    try {
      const parsed = JSON.parse(trimmed);
      return extractUserId(parsed);
    } catch {
      return null;
    }
  }

  if (value && typeof value === "object") {
    return (
      extractUserId(value.userId) ||
      extractUserId(value.$id) ||
      extractUserId(value.id) ||
      null
    );
  }

  return null;
}

function bookingPermissions(userId, managerId) {
  const permissions = [
    Permission.read(Role.user(userId)),
    Permission.update(Role.user(userId)),
    Permission.delete(Role.user(userId)),
  ];

  if (managerId) {
    permissions.push(
      Permission.read(Role.user(managerId)),
      Permission.update(Role.user(managerId)),
      Permission.delete(Role.user(managerId)),
    );
  }

  return permissions;
}

function userOnlyBookingPermissions(userId) {
  return [
    Permission.read(Role.user(userId)),
    Permission.update(Role.user(userId)),
    Permission.delete(Role.user(userId)),
  ];
}

function bookedSlotPermissions(userId, managerId) {
  const permissions = [
    Permission.read(Role.any()),
    Permission.delete(Role.user(userId)),
  ];

  if (managerId) {
    permissions.push(Permission.delete(Role.user(managerId)));
  }

  return permissions;
}

function managerBookedSlotPermissions(managerId) {
  return [
    Permission.read(Role.any()),
    Permission.delete(Role.user(managerId)),
  ];
}

function rowPayload(row) {
  return {
    $id: row.$id,
    ...(row.data ?? row),
  };
}

function shortHash(value) {
  let hash = 0xcbf29ce484222325n;
  for (const char of value) {
    hash ^= BigInt(char.codePointAt(0));
    hash = (hash * 0x100000001b3n) & 0xffffffffffffffffn;
  }

  return hash.toString(16).padStart(16, "0");
}

function slotIdFor(stadiumId, dayDate, slotTime) {
  const normalizedDate = String(dayDate).toLowerCase().replaceAll(" ", "_");
  const normalizedTime = String(slotTime)
    .toLowerCase()
    .replaceAll(" ", "")
    .replaceAll(":", "");
  return `slot_${shortHash(`${stadiumId}|${normalizedDate}|${normalizedTime}`)}`;
}

async function managerIdForStadium(tables, stadiumId) {
  try {
    await tables.getRow(DATABASE_ID, STADIUMS_TABLE_ID, stadiumId);
    return stadiumId;
  } catch (err) {
    if (err?.code === 404) return null;
    throw err;
  }
}

async function createBooking({ tables, callerId, body, res }) {
  const userId = extractUserId(body?.userId);
  if (!userId || userId !== callerId) {
    return res.json({ error: "You can only create your own bookings." }, 403);
  }

  const stadiumId = extractUserId(body?.stadiumId);
  if (!stadiumId) {
    return res.json({ error: "Invalid stadium." }, 400);
  }

  const dayDate = String(body?.dayDate ?? "").trim();
  const slotTime = String(body?.slotTime ?? "").trim();
  if (!dayDate || !slotTime) {
    return res.json({ error: "Missing booking time." }, 400);
  }

  const managerId = await managerIdForStadium(tables, stadiumId);
  const status = managerId ? PENDING_STATUS : ACTIVE_STATUS;
  const slotId = String(body?.slotId || slotIdFor(stadiumId, dayDate, slotTime));

  try {
    await tables.createRow(
      DATABASE_ID,
      BOOKED_SLOTS_TABLE_ID,
      slotId,
      {
        stadiumId,
        dayDate,
        slotTime,
        status,
      },
      bookedSlotPermissions(userId, managerId),
    );
  } catch (err) {
    if (err?.code === 409) {
      return res.json({ error: "That slot is no longer available." }, 409);
    }

    throw err;
  }

  try {
    const row = await tables.createRow(
      DATABASE_ID,
      BOOKINGS_TABLE_ID,
      ID.unique(),
      {
        userId,
        userName: String(body?.userName ?? "Unknown User"),
        stadiumId,
        slotId,
        stadiumName: String(body?.stadiumName ?? ""),
        location: String(body?.location ?? ""),
        rating: Number(body?.rating ?? 0),
        price: Number.parseInt(body?.price ?? 0, 10),
        icon: String(body?.icon ?? "stadium"),
        dayLabel: String(body?.dayLabel ?? ""),
        dayDate,
        slotTime,
        status,
        createdAt: new Date().toISOString(),
      },
      bookingPermissions(userId, managerId),
    );

    return res.json({ booking: rowPayload(row) });
  } catch (err) {
    try {
      await tables.deleteRow(DATABASE_ID, BOOKED_SLOTS_TABLE_ID, slotId);
    } catch (deleteErr) {
      if (deleteErr?.code !== 404) {
        throw deleteErr;
      }
    }

    throw err;
  }
}

async function getManagerRequest({ tables, callerId, requestId, res }) {
  if (!requestId) {
    return res.json({ error: "Invalid booking request." }, 400);
  }

  const request = await tables.getRow(DATABASE_ID, BOOKINGS_TABLE_ID, requestId);
  const data = request.data ?? request;

  if (data.stadiumId !== callerId) {
    return res.json(
      { error: "Managers can only update requests for their stadium." },
      403,
    );
  }

  return { request, data };
}

async function acceptBookingRequest({ tables, callerId, body, res }) {
  const requestId = String(body?.requestId ?? "").trim();
  const loaded = await getManagerRequest({ tables, callerId, requestId, res });
  if (!loaded?.request) return loaded;

  const { request, data } = loaded;
  if (data.status !== PENDING_STATUS) {
    return res.json({ booking: rowPayload(request) });
  }

  try {
    const slot = await tables.getRow(
      DATABASE_ID,
      BOOKED_SLOTS_TABLE_ID,
      data.slotId,
    );
    const slotData = slot.data ?? slot;
    if (!RESERVED_SLOT_STATUSES.has(slotData.status)) {
      await tables.updateRow(
        DATABASE_ID,
        BOOKED_SLOTS_TABLE_ID,
        data.slotId,
        { status: ACTIVE_STATUS },
        bookedSlotPermissions(data.userId, callerId),
      );
    } else if (slotData.status === PENDING_STATUS) {
      await tables.updateRow(
        DATABASE_ID,
        BOOKED_SLOTS_TABLE_ID,
        data.slotId,
        { status: ACTIVE_STATUS },
        bookedSlotPermissions(data.userId, callerId),
      );
    } else {
      await tables.updateRow(
        DATABASE_ID,
        BOOKINGS_TABLE_ID,
        requestId,
        { status: DENIED_STATUS },
        bookingPermissions(data.userId, callerId),
      );
      return res.json({ error: "That slot is no longer available." }, 409);
    }
  } catch (err) {
    if (err?.code === 404) {
      await tables.createRow(
        DATABASE_ID,
        BOOKED_SLOTS_TABLE_ID,
        data.slotId,
        {
          stadiumId: data.stadiumId,
          dayDate: data.dayDate,
          slotTime: data.slotTime,
          status: ACTIVE_STATUS,
        },
        bookedSlotPermissions(data.userId, callerId),
      );
    } else {
      throw err;
    }
  }

  const updated = await tables.updateRow(
    DATABASE_ID,
    BOOKINGS_TABLE_ID,
    requestId,
    { status: ACTIVE_STATUS },
    bookingPermissions(data.userId, callerId),
  );

  return res.json({ booking: rowPayload(updated) });
}

async function denyBookingRequest({ tables, callerId, body, res }) {
  const requestId = String(body?.requestId ?? "").trim();
  const loaded = await getManagerRequest({ tables, callerId, requestId, res });
  if (!loaded?.request) return loaded;

  const { data } = loaded;
  await tables.updateRow(
    DATABASE_ID,
    BOOKINGS_TABLE_ID,
    requestId,
    { status: DENIED_STATUS },
    bookingPermissions(data.userId, callerId),
  );

  try {
    await tables.deleteRow(
      DATABASE_ID,
      BOOKED_SLOTS_TABLE_ID,
      data.slotId,
    );
  } catch (err) {
    if (err?.code !== 404) {
      throw err;
    }
  }

  return res.json({ ok: true });
}

async function managerBlockSlot({ tables, callerId, body, res }) {
  const managerId = extractUserId(body?.userId);
  if (!managerId || managerId !== callerId) {
    return res.json({ error: "Managers can only update their own slots." }, 403);
  }

  const stadiumId = extractUserId(body?.stadiumId);
  if (!stadiumId || stadiumId !== callerId) {
    return res.json({ error: "Managers can only update their own stadium." }, 403);
  }

  const dayDate = String(body?.dayDate ?? "").trim();
  const slotTime = String(body?.slotTime ?? "").trim();
  if (!dayDate || !slotTime) {
    return res.json({ error: "Missing booking time." }, 400);
  }

  const ownedStadiumId = await managerIdForStadium(tables, stadiumId);
  if (ownedStadiumId !== callerId) {
    return res.json({ error: "Stadium not found for this manager." }, 404);
  }

  const slotId = String(body?.slotId || slotIdFor(stadiumId, dayDate, slotTime));

  try {
    const slot = await tables.createRow(
      DATABASE_ID,
      BOOKED_SLOTS_TABLE_ID,
      slotId,
      {
        stadiumId,
        dayDate,
        slotTime,
        status: ACTIVE_STATUS,
      },
      managerBookedSlotPermissions(callerId),
    );

    return res.json({ slot: rowPayload(slot) });
  } catch (err) {
    if (err?.code === 409) {
      return res.json({ error: "That slot is already booked." }, 409);
    }

    throw err;
  }
}

async function managerUnblockSlot({ tables, callerId, body, res }) {
  const managerId = extractUserId(body?.userId);
  if (!managerId || managerId !== callerId) {
    return res.json({ error: "Managers can only update their own slots." }, 403);
  }

  const stadiumId = extractUserId(body?.stadiumId);
  if (!stadiumId || stadiumId !== callerId) {
    return res.json({ error: "Managers can only update their own stadium." }, 403);
  }

  const dayDate = String(body?.dayDate ?? "").trim();
  const slotTime = String(body?.slotTime ?? "").trim();
  if (!dayDate || !slotTime) {
    return res.json({ error: "Missing booking time." }, 400);
  }

  const ownedStadiumId = await managerIdForStadium(tables, stadiumId);
  if (ownedStadiumId !== callerId) {
    return res.json({ error: "Stadium not found for this manager." }, 404);
  }

  const slotId = String(body?.slotId || slotIdFor(stadiumId, dayDate, slotTime));

  let slot;
  try {
    slot = await tables.getRow(DATABASE_ID, BOOKED_SLOTS_TABLE_ID, slotId);
  } catch (err) {
    if (err?.code === 404) {
      return res.json({ error: "That time is already available." }, 404);
    }

    throw err;
  }

  const slotData = slot.data ?? slot;
  if (
    slotData.stadiumId !== stadiumId ||
    slotData.dayDate !== dayDate ||
    slotData.slotTime !== slotTime
  ) {
    return res.json({ error: "Booked time does not match this stadium." }, 403);
  }

  const bookings = await tables.listRows(DATABASE_ID, BOOKINGS_TABLE_ID, [
    Query.equal("slotId", slotId),
    Query.equal("status", [ACTIVE_STATUS, PENDING_STATUS]),
    Query.limit(1),
  ]);

  if ((bookings.rows ?? []).length > 0) {
    return res.json(
      { error: "Only manager-blocked times can be marked available." },
      409,
    );
  }

  await tables.deleteRow(DATABASE_ID, BOOKED_SLOTS_TABLE_ID, slotId);
  return res.json({ ok: true });
}

async function cancelBookingRequest({ tables, callerId, body, res }) {
  const userId = extractUserId(body?.userId);
  if (!userId || userId !== callerId) {
    return res.json({ error: "You can only cancel your own bookings." }, 403);
  }

  const requestId = String(body?.requestId ?? "").trim();
  if (!requestId) {
    return res.json({ error: "Invalid booking request." }, 400);
  }

  const request = await tables.getRow(DATABASE_ID, BOOKINGS_TABLE_ID, requestId);
  const data = request.data ?? request;
  if (data.userId !== callerId) {
    return res.json({ error: "You can only cancel your own bookings." }, 403);
  }

  await tables.updateRow(
    DATABASE_ID,
    BOOKINGS_TABLE_ID,
    requestId,
    { status: CANCELLED_STATUS },
    userOnlyBookingPermissions(callerId),
  );

  try {
    await tables.deleteRow(
      DATABASE_ID,
      BOOKED_SLOTS_TABLE_ID,
      data.slotId,
    );
  } catch (err) {
    if (err?.code !== 404) {
      throw err;
    }
  }

  return res.json({ ok: true });
}

export default async ({ req, res, log, error }) => {
  try {
    const client = new Client()
      .setEndpoint(process.env.APPWRITE_ENDPOINT)
      .setProject(process.env.APPWRITE_PROJECT_ID)
      .setKey(process.env.APPWRITE_API_KEY);

    const users = new Users(client);
    const tables = createTables(client);

    const body = req.body;
    const callerId =
      extractUserId(req.headers["x-appwrite-user-id"]) ||
      extractUserId(body) ||
      null;

    if (!callerId) {
      return res.json({ error: "Sign in required." }, 401);
    }

    if (!UID_REGEX.test(callerId)) {
      return res.json({ error: "Invalid caller identity." }, 401);
    }

    const parsedBody =
      typeof body === "string"
        ? (() => {
            try {
              return JSON.parse(body);
            } catch {
              return null;
            }
          })()
        : body;

    const action = parsedBody?.action;
    if (action === "createBooking") {
      return createBooking({ tables, callerId, body: parsedBody, res });
    }

    if (action === "acceptBookingRequest") {
      return acceptBookingRequest({ tables, callerId, body: parsedBody, res });
    }

    if (action === "denyBookingRequest") {
      return denyBookingRequest({ tables, callerId, body: parsedBody, res });
    }

    if (action === "managerBlockSlot") {
      return managerBlockSlot({ tables, callerId, body: parsedBody, res });
    }

    if (action === "managerUnblockSlot") {
      return managerUnblockSlot({ tables, callerId, body: parsedBody, res });
    }

    if (action === "cancelBookingRequest") {
      return cancelBookingRequest({ tables, callerId, body: parsedBody, res });
    }

    const now = Date.now();

    const cachedAdmin = adminCache.get(callerId);
    let isAdmin = false;
    if (cachedAdmin && cachedAdmin.expiresAt > now) {
      isAdmin = cachedAdmin.isAdmin;
    } else {
      const caller = await users.get(callerId);
      isAdmin = (caller.labels ?? []).includes("admin");
      adminCache.set(callerId, {
        isAdmin,
        expiresAt: now + ADMIN_CACHE_TTL_MS,
      });
    }

    if (!isAdmin) {
      return res.json({ error: "Admin access required." }, 403);
    }

    if (
      action === "promote" ||
      action === "revoke" ||
      action === "demote" ||
      action === "delete"
    ) {
      const targetUserId = extractUserId(parsedBody?.targetUserId);
      if (!targetUserId) {
        return res.json({ error: "Invalid target user." }, 400);
      }

      if (action === "delete" && targetUserId === callerId) {
        return res.json({ error: "You cannot delete your own account." }, 400);
      }

      if (action === "promote") {
        const role = String(parsedBody?.role ?? "").trim();
        if (!ADMIN_MANAGED_ROLES.has(role)) {
          return res.json({ error: "Invalid role for promotion." }, 400);
        }

        const target = await users.get(targetUserId);
        const nextLabels = Array.from(
          new Set([...(target.labels ?? []), role]),
        );
        await users.updateLabels(targetUserId, nextLabels);
      }

      if (action === "revoke") {
        const role = String(parsedBody?.role ?? "").trim();
        if (!ADMIN_MANAGED_ROLES.has(role)) {
          return res.json({ error: "Invalid role for demotion." }, 400);
        }

        const target = await users.get(targetUserId);
        const nextLabels = (target.labels ?? []).filter(
          (label) => label !== role,
        );
        await users.updateLabels(targetUserId, nextLabels);
      }

      if (action === "demote") {
        const target = await users.get(targetUserId);
        const nextLabels = (target.labels ?? []).filter(
          (label) => label === "user",
        );
        await users.updateLabels(targetUserId, nextLabels);
      }

      if (action === "delete") {
        await users.delete(targetUserId);
      }

      usersCache.users = null;
      usersCache.expiresAt = 0;
      adminCache.delete(targetUserId);

      return res.json({ ok: true });
    }

    if (usersCache.users && usersCache.expiresAt > now) {
      return res.json({ users: usersCache.users });
    }

    const result = await users.list();
    const payloadUsers = result.users.map((user) => ({
      id: user.$id,
      name: user.name,
      email: user.email,
      roles: user.labels ?? [],
      status: user.status,
    }));

    usersCache.users = payloadUsers;
    usersCache.expiresAt = now + USERS_CACHE_TTL_MS;

    return res.json({
      users: payloadUsers,
    });
  } catch (err) {
    error(err?.message ?? String(err));
    return res.json({ error: err?.message ?? "Could not load users." }, 500);
  }
};
