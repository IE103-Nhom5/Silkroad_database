import { corsHeaders, json } from "../_shared/cors.ts";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  return json({
    enabled: false,
    message: "Gemini is intentionally disabled. Configure GEMINI_API_KEY, authorization and rate limiting before enabling.",
  }, 503);
});
