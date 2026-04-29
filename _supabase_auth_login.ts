// Supabase Edge Function: auth_login
//
// 배포 방법 (둘 중 하나):
//   A) Dashboard UI: Edge Functions → New Function → name=auth_login → 이 코드 붙여넣기 → Deploy
//   B) CLI: supabase functions deploy auth_login
//
// 배포 후 환경변수 확인:
//   - SUPABASE_URL (자동 주입)
//   - SUPABASE_SERVICE_ROLE_KEY (자동 주입)
//   - JWT_SECRET (Project Settings → API → JWT Secret 값을 복사해서 추가)
//     ※ SUPABASE_ 접두사는 예약어라 사용 불가 → 'JWT_SECRET' 으로

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create as signJWT, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const JWT_SECRET = Deno.env.get("JWT_SECRET")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const { name, phone, password, mode } = await req.json();
    if (!phone) return json({ error: "phone required" }, 400);

    const sb = createClient(SUPABASE_URL, SERVICE_KEY);

    let user: any = null;

    if (mode === "clinic_admin") {
      // 클리닉 어드민: phone + password 검증
      if (!password) return json({ error: "password required" }, 400);
      const { data, error } = await sb.from("members")
        .select("id, name, phone, student_phone, role")
        .eq("phone", phone).eq("password", password).eq("role", "clinic_admin")
        .maybeSingle();
      if (error) return json({ error: "db_error" }, 500);
      user = data;
    } else {
      // 일반 로그인: name + phone
      if (!name) return json({ error: "name required" }, 400);
      const { data, error } = await sb.from("members")
        .select("id, name, phone, student_phone, role")
        .eq("name", name).eq("phone", phone)
        .limit(1);
      if (error) return json({ error: "db_error" }, 500);
      user = data?.[0] || null;
    }

    if (!user) return json({ error: "invalid_credentials" }, 401);

    // Supabase JWT secret으로 sign — auth.jwt()가 자동으로 인식
    const key = await crypto.subtle.importKey(
      "raw", new TextEncoder().encode(JWT_SECRET),
      { name: "HMAC", hash: "SHA-256" },
      false, ["sign"]
    );

    const token = await signJWT(
      { alg: "HS256", typ: "JWT" },
      {
        sub: user.id,
        role: "authenticated", // Supabase 표준 role
        app_role: user.role || "user", // 'admin', 'user', 'clinic_admin'
        name: user.name,
        exp: getNumericDate(60 * 60 * 8), // 8시간
      },
      key
    );

    return json({ token, user });
  } catch (e) {
    console.error(e);
    return json({ error: "server_error" }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
