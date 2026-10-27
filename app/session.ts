import { env } from "cloudflare:workers";
import { headers } from "next/headers";
import { readCookie, sessionUser } from "../lib/auth.mjs";

export type SessionUser = {
  userId: string;
  displayName: string;
  email: string;
  fullName: string | null;
};

export async function getSessionUser(): Promise<SessionUser | null> {
  if (!env.DB) return null;
  const token = readCookie((await headers()).get("cookie"));
  return sessionUser(env.DB, token);
}
