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
2. **Comptes autorisés.** Seules les adresses présentes dans `allowed_users` peuvent voir et modifier les données :
   ```sql
   insert into public.allowed_users (email) values ('prenom@entreprise.com');
   ```
   Les adresses doivent être écrites en minuscules.
3. **Configuration.** Dans `config.js`, mets l'URL du projet et la clé *publishable*. On les trouve dans *Project Settings → API Keys*.
4. **Connexion par lien email.** Dans *Authentication → URL Configuration*, mets l'adresse de la page publiée comme *Site URL*, et ajoute-la aussi aux *Redirect URLs*. Par exemple : `https://ton-compte.github.io/projets-et-taches/`.
5. **Publication.** Dans le dépôt GitHub, ouvre *Settings → Pages* et choisis *Deploy from a branch*, branche `main`, dossier `/ (root)`.

## Sécurité

- **Clé publique.** La clé présente dans `config.js` est publique par nature. La protection vient de deux choses : la connexion par email, et les règles RLS qui n'ouvrent les tables qu'aux adresses de `allowed_users`.
- **Clé `service_role`.** Ne mets jamais cette clé dans le dépôt.
