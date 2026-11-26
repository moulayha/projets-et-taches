# Projets et tâches

Suivi des projets événementiels et de leurs tâches. Il propose des vues Kanban, une chronologie, une vue par client et des graphiques de charge. Les listes (états, responsables, pilotes, créas, clients) se règlent dans **Paramètres**.

L'application tient dans une seule page statique (`index.html`). Les données sont dans **Supabase** et se mettent à jour en direct entre utilisateurs.

## Fichiers

| Fichier | Rôle |
|---|---|
| `index.html` | L'application |
| `caisse.html` | Module Caisse (avances, dépenses des ouvriers, coût par projet), visible seulement par les super admins, la facturation et les personnes ajoutées dans ses Réglages |
| `config.js` | Adresse et clé publique du projet Supabase |
| `supabase/schema.sql` | Tables, sécurité (RLS) et temps réel |

## Mise en place

1. **Base de données.** Dans le projet Supabase, ouvre *SQL Editor* et exécute `supabase/schema.sql`. Les données ne sont pas dans ce dépôt public : elles sont uniquement dans Supabase.
2. **Fonction serveur.** Déploie `supabase/functions/admin-users`. Elle crée les comptes, change les mots de passe et supprime les comptes avec la clé `service_role`, qui ne quitte jamais le serveur. Seuls les administrateurs peuvent l'appeler.

   ```bash
   supabase functions deploy admin-users
   ```
3. **Comptes.** Crée le premier administrateur avec les deux lignes à la fin de `schema.sql`, puis donne-lui un mot de passe dans le tableau de bord Supabase. Ensuite, tout se gère dans l'application, sous **Paramètres → Utilisateurs** : créer un compte (email + mot de passe provisoire), changer le rôle, définir un nouveau mot de passe ou supprimer un compte. Chacun peut changer son mot de passe avec **Mon mot de passe**.

   Les rôles possibles :
   Tout le monde voit tous les projets et toutes les tâches.
   - **Lecture seule** : consulte sans rien modifier.
   - **Membre** : crée, modifie et supprime projets et tâches.
   - **Administrateur** : comme un membre, et gère en plus les paramètres et les comptes.

   Ces droits sont appliqués par la base elle-même (RLS), pas seulement par l'interface.
4. **Configuration.** Dans `config.js`, mets l'URL du projet et la clé *publishable*. On les trouve dans *Project Settings → API Keys*.
5. **Lien de connexion par email (secours).** Dans *Authentication → URL Configuration*, mets l'adresse de la page publiée comme *Site URL*, et ajoute-la aussi aux *Redirect URLs*. Par exemple : `https://ton-compte.github.io/projets-et-taches/`.
6. **Publication.** Dans le dépôt GitHub, ouvre *Settings → Pages* et choisis *Deploy from a branch*, branche `main`, dossier `/ (root)`.

## Sécurité

- **Clé publique.** La clé présente dans `config.js` est publique par nature. La protection vient de deux choses : la connexion par email et mot de passe, et les règles RLS qui n'ouvrent les données qu'aux comptes de `app_users`, selon leur rôle.
- **Clé `service_role`.** Ne mets jamais cette clé dans le dépôt.
