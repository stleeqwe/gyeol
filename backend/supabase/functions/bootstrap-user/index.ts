// 결 (Gyeol) — Edge Function: bootstrap-user
// Supabase Auth user -> public.users row sync.

import {
  getServiceRoleClient,
  getUserClient,
  handleError,
  jsonResponse,
  requireUserId,
} from "../_shared/supabase.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  try {
    const userClient = getUserClient(req.headers.get("authorization"));
    const userId = await requireUserId(userClient);
    const { data } = await userClient.auth.getUser();
    const authUser = data.user;

    const appleSub = authUser?.identities?.find((identity) =>
      identity.provider === "apple"
    )?.identity_data?.sub ??
      authUser?.user_metadata?.sub ??
      userId;
    const displayName = authUser?.user_metadata?.full_name ??
      authUser?.user_metadata?.name ??
      null;

    const service = getServiceRoleClient();
    await service.from("users").upsert({
      id: userId,
      apple_sub: appleSub,
      display_name: displayName,
      last_active_at: new Date().toISOString(),
    }, { onConflict: "id" });

    const { data: consents } = await service
      .from("consents")
      .select("id")
      .eq("user_id", userId)
      .is("revoked_at", null)
      .limit(1);

    return jsonResponse({
      user_id: userId,
      has_active_consent: (consents?.length ?? 0) > 0,
    });
  } catch (err) {
    return handleError(err);
  }
});
