import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, json } from "../_shared/cors.ts";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const token = request.headers.get("Authorization")?.replace("Bearer ", "");
  const { data: auth } = await admin.auth.getUser(token);
  if (!auth.user) return json({ error: "Unauthenticated" }, 401);
  const { data: actor } = await admin.from("users").select("userid,role(rolename)").eq("authuserid", auth.user.id).maybeSingle();
  if ((actor?.role as { rolename?: string } | null)?.rolename !== "admin") return json({ error: "Admin required" }, 403);
  const { auth_user_id, status } = await request.json();
  if (!["active", "inactive", "locked"].includes(status)) return json({ error: "Invalid status" }, 400);
  const { data: target } = await admin.from("users").select("userid,status").eq("authuserid", auth_user_id).maybeSingle();
  const { error } = await admin.from("users").update({ status, updatedat: new Date().toISOString() }).eq("authuserid", auth_user_id);
  if (error) return json({ error: error.message }, 400);
  await admin.auth.admin.updateUserById(auth_user_id, { ban_duration: status === "locked" ? "876000h" : "none" });
  await admin.from("audit_log").insert({
    actoruserid: actor?.userid, action: "user.status.update", entitytype: "users", entityid: target?.userid || auth_user_id,
    beforedata: { status: target?.status }, afterdata: { status },
  });
  return json({ ok: true });
});
