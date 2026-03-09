# Set up Julia

Installez Julia avec [juliaup](https://github.com/JuliaLang/juliaup) et pas `apt`!! Ca gère automatiquement les versions de Julia. Le site vous donne un script à executer (une seule ligne de commande).

Ensuite vous pouvez lancer `julia`.

Contrairement à `Python`, il y a pas de `.venv`. A la place c'est le dossier qui agis comme environnement . Les fichiers Manifest et Project servent à versionner les dépendances.

Pour utiliser un environnement spécifique vous pouvez spécifier le projet en argument : 

```bash
julia --project="."
```

Si vous ne spécifier pas de fichier `.jl` après la commande, cela ouvre un environnement interactif similaire à python (REPL pour Read-Evaluate-Print-Loop). Utilisez `CTRL+D` pour revenir à votre terminal initial.

Depuis ce terminal vous pouvez aussi accéder à PKG en appuyant sur `]`, ce qui permet d'installer des packages (comme pip pour python).

La première fois que vous ouvrez un projet, vous pouvez executer :
```
(Operator_Spliting_Optimal_Control) pkg> instantiate
```
Ce qui téléchargera les dépendances.

Pour ajouter un package utilisez `add PackageName`.

Pour sortir de pkg appuyez sur `del` et vous retournez vers le REPL Julia.

Vous pouvez écrire des test dans le dossier Test/ et les lancer en utilisant la commande `test` dans pkg. Demandez à chat comment les écrire.