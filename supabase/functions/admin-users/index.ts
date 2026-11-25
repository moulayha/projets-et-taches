// Gestion des comptes de l'application (réservée aux administrateurs et super admins).
// Un administrateur ne peut ni créer, ni modifier, ni supprimer un compte super admin.
// Actions : create, update, set_password, delete.
// Utilise la clé service_role, disponible uniquement côté serveur.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const ROLES = ["superadmin", "admin", "member", "billing", "viewer"];
const ADMIN_ROLES = ["superadmin", "admin"];
const SUPER_ONLY = "Seul un super admin peut modifier un compte super admin.";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Méthode non autorisée" }, 405);
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Qui appelle ?
    const userClient = createClient(url, anonKey, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
      auth: { persistSession: false },
    });
    const { data: { user }, error: userErr } = await userClient.auth.getUser();
    if (userErr || !user) return json({ error: "Session expirée : reconnecte-toi." }, 401);

    const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
    const { data: me } = await admin.from("app_users").select("id, role")
      .eq("email", (user.email ?? "").toLowerCase()).maybeSingle();
    if (!me || !ADMIN_ROLES.includes(me.role)) return json({ error: "Action réservée aux administrateurs." }, 403);
    const meSuper = me.role === "superadmin";

    const body = await req.json().catch(() => ({}));
    const action = String(body.action ?? "");
    const personId = String(body.person_id ?? "");
    if (!personId) return json({ error: "Personne manquante." }, 400);

    const { data: person } = await admin.from("people").select("id, name").eq("id", personId).maybeSingle();
    if (!person) return json({ error: "Personne introuvable." }, 404);
    const { data: current } = await admin.from("app_users").select("id, email, role").eq("id", personId).maybeSingle();

    const findAuthUser = async (email: string) => {
      for (let page = 1; page < 50; page++) {
        const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 });
        if (error) throw error;
        const u = data.users.find((x) => (x.email ?? "").toLowerCase() === email);
        if (u) return u;
        if (data.users.length < 200) return null;
      }
      return null;
    };
    const countRoles = async (roles: string[]) => {
      const { count } = await admin.from("app_users").select("id", { count: "exact", head: true }).in("role", roles);
      return count ?? 0;
    };
    const adminCount = () => countRoles(ADMIN_ROLES);
    const superCount = () => countRoles(["superadmin"]);
    const checkPassword = (p: unknown) => typeof p === "string" && p.length >= 8;

    if (action === "create") {
      const email = String(body.email ?? "").trim().toLowerCase();
      const role = String(body.role ?? "member");
      if (!EMAIL_RE.test(email)) return json({ error: "Adresse email invalide." }, 400);
      if (!ROLES.includes(role)) return json({ error: "Rôle invalide." }, 400);
      if (role === "superadmin" && !meSuper) return json({ error: "Seul un super admin peut créer un compte super admin." }, 403);
      if (current && current.role === "superadmin" && !meSuper) return json({ error: SUPER_ONLY }, 403);
      if (!checkPassword(body.password)) return json({ error: "Le mot de passe doit faire au moins 8 caractères." }, 400);
      const { data: taken } = await admin.from("app_users").select("id").eq("email", email).neq("id", personId).maybeSingle();
      if (taken) return json({ error: "Cette adresse est déjà utilisée par une autre personne." }, 409);

      const existing = await findAuthUser(email);
      if (existing) {
        const { error } = await admin.auth.admin.updateUserById(existing.id, { password: body.password, email_confirm: true });
        if (error) return json({ error: error.message }, 400);
      } else {
        const { error } = await admin.auth.admin.createUser({ email, password: body.password, email_confirm: true });
        if (error) return json({ error: error.message }, 400);
      }
      const { error: upErr } = await admin.from("app_users").upsert({ id: personId, email, role });
      if (upErr) return json({ error: upErr.message }, 400);
      return json({ ok: true });
    }

    if (!current) return json({ error: "Cette personne n'a pas de compte." }, 404);
    const isSelf = current.id === me.id;
    // Un administrateur ne touche pas aux comptes super admin
    if (current.role === "superadmin" && !meSuper && !isSelf) return json({ error: SUPER_ONLY }, 403);

    if (action === "set_password") {
      if (!checkPassword(body.password)) return json({ error: "Le mot de passe doit faire au moins 8 caractères." }, 400);
      const u = await findAuthUser(current.email);
      const { error } = u
        ? await admin.auth.admin.updateUserById(u.id, { password: body.password, email_confirm: true })
        : await admin.auth.admin.createUser({ email: current.email, password: body.password, email_confirm: true });
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    if (action === "update") {
      const role = body.role != null ? String(body.role) : current.role;
      const email = body.email != null ? String(body.email).trim().toLowerCase() : current.email;
      if (!ROLES.includes(role)) return json({ error: "Rôle invalide." }, 400);
      if (!EMAIL_RE.test(email)) return json({ error: "Adresse email invalide." }, 400);
      if (role === "superadmin" && current.role !== "superadmin" && !meSuper) return json({ error: "Seul un super admin peut nommer un super admin." }, 403);
      if (isSelf && role !== current.role) return json({ error: "Tu ne peux pas modifier ton propre rôle." }, 400);
      if (ADMIN_ROLES.includes(current.role) && !ADMIN_ROLES.includes(role) && (await adminCount()) <= 1) {
        return json({ error: "Il doit rester au moins un administrateur." }, 400);
      }
      if (current.role === "superadmin" && role !== "superadmin" && (await superCount()) <= 1) {
        return json({ error: "Il doit rester au moins un super admin." }, 400);
      }
      if (email !== current.email) {
        if (isSelf) return json({ error: "Change ta propre adresse depuis le tableau de bord Supabase." }, 400);
        const { data: taken } = await admin.from("app_users").select("id").eq("email", email).neq("id", personId).maybeSingle();
        if (taken) return json({ error: "Cette adresse est déjà utilisée par une autre personne." }, 409);
        const u = await findAuthUser(current.email);
        if (u) {
          const { error } = await admin.auth.admin.updateUserById(u.id, { email, email_confirm: true });
          if (error) return json({ error: error.message }, 400);
        }
      }
      const { error } = await admin.from("app_users").update({ email, role }).eq("id", personId);
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    if (action === "delete") {
      if (isSelf) return json({ error: "Tu ne peux pas supprimer ton propre accès." }, 400);
      if (ADMIN_ROLES.includes(current.role) && (await adminCount()) <= 1) {
        return json({ error: "Il doit rester au moins un administrateur." }, 400);
      }
      if (current.role === "superadmin" && (await superCount()) <= 1) {
        return json({ error: "Il doit rester au moins un super admin." }, 400);
      }
      const u = await findAuthUser(current.email);
      if (u) {
        const { error } = await admin.auth.admin.deleteUser(u.id);
        if (error) return json({ error: error.message }, 400);
      }
      const { error } = await admin.from("app_users").delete().eq("id", personId);
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    return json({ error: "Action inconnue." }, 400);
  } catch (e) {
    return json({ error: (e as Error).message ?? "Erreur inattendue." }, 500);
  }
});
