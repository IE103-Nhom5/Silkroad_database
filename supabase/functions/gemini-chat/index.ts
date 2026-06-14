import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, json } from "../_shared/cors.ts";
import { silkRoadSystemPrompt } from "../_shared/silkroad-context.ts";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) return json({ error: "GEMINI_API_KEY is not configured" }, 503);

  const authorization = request.headers.get("Authorization");
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authorization || "" } } },
  );
  const { data: auth, error: authError } = await supabase.auth.getUser();
  if (authError || !auth.user) return json({ error: "Unauthenticated" }, 401);

  try {
    const payload = await request.json();
    const question = String(payload.message || "").trim();
    const currentPath = String(payload.currentPath || "").slice(0, 200);
    if (!question) return json({ error: "Thiếu nội dung câu hỏi" }, 400);
    if (question.length > 2000) return json({ error: "Câu hỏi tối đa 2000 ký tự" }, 400);

    const history = Array.isArray(payload.history)
      ? payload.history.slice(-8).map((item: { role?: string; text?: string }) => ({
          role: item.role === "assistant" ? "model" : "user",
          parts: [{ text: String(item.text || "").slice(0, 2000) }],
        }))
      : [];

    const response = await fetch(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: JSON.stringify({
          systemInstruction: {
            parts: [{
              text: `${silkRoadSystemPrompt}\n\nTrang người dùng đang mở: ${currentPath || "không xác định"}.`,
            }],
          },
          contents: [...history, { role: "user", parts: [{ text: question }] }],
          generationConfig: { temperature: 0.2, maxOutputTokens: 500 },
        }),
      },
    );
    const result = await response.json();
    if (!response.ok) {
      return json({ error: result?.error?.message || "Gemini API request failed" }, response.status);
    }

    const answer = result?.candidates?.[0]?.content?.parts
      ?.map((part: { text?: string }) => part.text || "")
      .join("")
      .trim();
    return json({ answer: answer || "Gemini không trả về nội dung." });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
