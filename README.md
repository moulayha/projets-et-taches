# Projets et tâches

Suivi des projets événementiels et de leurs tâches. Il propose des vues Kanban, une chronologie, une vue par client et des graphiques de charge. Les listes (états, responsables, pilotes, créas, clients) se règlent dans **Paramètres**.

L'application tient dans une seule page statique (`index.html`). Les données sont dans **Supabase** et se mettent à jour en direct entre utilisateurs.

## Fichiers

| Fichier | Rôle |
|---|---|
| `index.html` | L'application |
| `config.js` | Adresse et clé publique du projet Supabase |
| `supabase/schema.sql` | Tables, sécurité (RLS) et temps réel |

## Mise en place

1. **Base de données.** Dans le projet Supabase, ouvre *SQL Editor* et exécute `supabase/schema.sql`. Les données ne sont pas dans ce dépôt public : elles sont uniquement dans Supabase.
2. **Comptes.** Crée le premier administrateur avec les deux lignes en fin de `schema.sql`. Ensuite, les utilisateurs se gèrent dans l'application, sous **Paramètres → Utilisateurs** :
   - **Administrateur** : voit tout, gère les paramètres et les accès.
   - **Membre** : ne voit que les projets où il est responsable, pilote ou créa, ainsi que les tâches de ces projets ou dont il est responsable.

   Ces droits sont appliqués par la base elle-même (RLS), pas seulement par l'interface.
3. **Configuration.** Dans `config.js`, mets l'URL du projet et la clé *publishable*. On les trouve dans *Project Settings → API Keys*.
4. **Connexion par lien email.** Dans *Authentication → URL Configuration*, mets l'adresse de la page publiée comme *Site URL*, et ajoute-la aussi aux *Redirect URLs*. Par exemple : `https://ton-compte.github.io/projets-et-taches/`.
5. **Publication.** Dans le dépôt GitHub, ouvre *Settings → Pages* et choisis *Deploy from a branch*, branche `main`, dossier `/ (root)`.

## Sécurité

- **Clé publique.** La clé présente dans `config.js` est publique par nature. La protection vient de deux choses : la connexion par email, et les règles RLS qui n'ouvrent les données qu'aux comptes de `app_users`, selon leur rôle.
- **Clé `service_role`.** Ne mets jamais cette clé dans le dépôt.
