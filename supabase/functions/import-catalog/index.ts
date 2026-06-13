import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, json } from "../_shared/cors.ts";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const token = request.headers.get("Authorization")?.replace("Bearer ", "");
  const { data: auth } = await admin.auth.getUser(token);
  if (!auth.user) return json({ error: "Unauthenticated" }, 401);
  const { data: actor } = await admin.from("users").select("userid,role(permissions)").eq("authuserid", auth.user.id).maybeSingle();
  const permissions = ((actor?.role as { permissions?: string[] } | null)?.permissions || []);
  if (!permissions.includes("import.run")) return json({ error: "import.run permission required" }, 403);
  const payload = await request.json();
  if (!Array.isArray(payload.rows) || payload.rows.length > 1000) return json({ error: "rows must contain at most 1000 records" }, 400);
  await admin.from("audit_log").insert({
    actoruserid: actor?.userid, action: "catalog.import.request", entitytype: "product", afterdata: { row_count: payload.rows.length },
  });
  return json({ accepted: payload.rows.length, message: "Contract ready. Add catalog validation/mapping before production import." }, 202);
});
