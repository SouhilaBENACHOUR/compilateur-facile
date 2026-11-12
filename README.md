# Compilateur du langage Facile

Projet du module **Compilation** (Licence Informatique, La Rochelle Université, 2024/2025).

C'est un compilateur écrit en C avec **flex** (analyse lexicale) et **bison** (analyse syntaxique). Il traduit des programmes écrits dans un petit langage impératif, **Facile**, en **CIL** (Common Intermediate Language, le bytecode .NET). Le code CIL est ensuite assemblé avec `ilasm` et exécuté avec Mono.

```
programme.facile ──► facile ──► programme.il ──► ilasm ──► programme.exe
```

## Le langage Facile

| Élément | Syntaxe |
|---|---|
| Affectation | `x := expression;` |
| Entrée / sortie | `read x;` · `print expression;` |
| Arithmétique | `+` `-` `*` `/` et parenthèses |
| Comparaisons | `=` `#` (différent) `<` `>` `<=` `>=` |
| Logique | `and` `or` `not` · `true` `false` |
| Conditionnelle | `if ... then ... elseif ... then ... else ... endif;` |
| Boucle | `while ... do ... endwhile;` (ou `end;`) |
| Contrôle de boucle | `break;` · `continue;` |

Exemple (PGCD) :

```
read a;
read b;
while a # b do
    if a > b then
        a := a - b;
    else
        b := b - a;
    endif;
endwhile;
print a;
```

## Fonctionnement

- **`facile.lex`** : découpe le source en tokens (mots-clés, identifiants, nombres, opérateurs).
- **`facile.y`** : grammaire bison. Elle construit un **arbre syntaxique** (avec `GNode` de GLib) et une table des symboles (`GHashTable`), puis parcourt l'arbre pour générer le CIL :
  - expressions évaluées sur la pile (`ldc.i4`, `ldloc`, `add`, `clt`, `ceq`…) ;
  - `and` / `or` évalués en court-circuit ;
  - `if` / `elseif` / `while` traduits en sauts avec des labels uniques ;
  - pile de boucles pour gérer `break` / `continue` dans des boucles imbriquées.

## Structure

```
.
├── exo1/                   # Version complète du compilateur
│   ├── facile.lex
│   ├── facile.y
│   ├── CMakeLists.txt
│   ├── *.facile            # Programmes de test (pgcd, boucles, if/elseif…)
│   └── ReadWrite.cs        # Exemple C# pour étudier le CIL généré par mcs
├── ProjetCompil/           # Première version (étapes initiales du TP)
└── projet compilation commandes.txt
```

## Installation (Ubuntu)

```bash
sudo apt install bison flex cmake libglib2.0-dev mono-devel
```

## Utilisation

```bash
cd exo1
mkdir build && cd build
cmake ..
make
cd ..

# Compile un programme Facile en CIL
./build/facile pgcd.facile

# Assemble le CIL en exécutable .NET
ilasm pgcd.il

# Exécute le programme
mono pgcd.exe
```

Le nom du fichier `.facile` doit commencer par une lettre ou `_` et ne contenir que des caractères alphanumériques, parce qu'il sert de nom d'assembly.

## Limites

- Seulement 3 variables locales par programme (`.locals init (int32, int32, int32)`).
- Uniquement des entiers (`int32`).

## Auteurs

- Souhila BENACHOUR
- Abdelmalek NOURINE
- Lina HADDADOU
