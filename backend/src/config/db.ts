import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { env } from "./env.js";

let client: SupabaseClient | null = null;

export const isDbConfigured = (): boolean =>
  Boolean(env.supabaseUrl && env.supabaseServiceRoleKey);

// Server-side client (service role key). Never expose this key to the frontend.
// Call SQL objects with db().rpc("sp_name", { ...args }); read tables/views with db().from("vw_name").
export const db = (): SupabaseClient => {
  if (!isDbConfigured()) {
    throw new Error("Database not configured: set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env");
  }
  client ??= createClient(env.supabaseUrl, env.supabaseServiceRoleKey, {
    auth: { persistSession: false },
  });
  return client;
};
