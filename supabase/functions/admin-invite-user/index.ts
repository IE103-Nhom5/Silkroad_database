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
  const payload = await request.json();
  const { data, error } = await admin.auth.admin.inviteUserByEmail(payload.email, { data: { full_name: payload.fullname } });
  if (error) return json({ error: error.message }, 400);
  const { error: profileError } = await admin.from("users").insert({
    authuserid: data.user.id, fullname: payload.fullname, username: payload.username, email: payload.email,
    roleid: payload.roleid, branchid: payload.branchid || null, status: "active",
  });
  if (profileError) return json({ error: profileError.message }, 400);
  await admin.from("audit_log").insert({
    actoruserid: actor?.userid, action: "user.invite", entitytype: "users", entityid: data.user.id,
    afterdata: { email: payload.email, roleid: payload.roleid, branchid: payload.branchid || null },
  });
  return json({ user_id: data.user.id }, 201);
});
