-module(cyk).

-export([
         analyse_phrase/1,
         test_analyse_phrase/0
        ]).


%%-----------------------
%% Fonctions publiques
%%-----------------------


%%Fonction principale pour analyser la phrase
analyse_phrase(Phrase) ->
	initialiser_stockage(),
	importer_fichier_grammaire("grammaire.txt"),
  analyse(Phrase),
  detruire_stockage().

%% Pour tester le module
test_analyse_phrase() ->
	initialiser_stockage(),
	importer_fichier_grammaire("grammaire.txt"),
  analyse("elle mange du poisson avec une fourchette"),
  detruire_stockage().


%%-------------------------
%% Initialisation de l'ETS
%%-------------------------

%% Initialisation de l'ETS (Erlang Term Stockage) pour obtenir les régles de grammaire
initialiser_stockage() ->
  ets:new(?MODULE, [bag, named_table]).

%%Destruction de notre table
detruire_stockage() ->
  ets:delete(?MODULE).

%%-----------------------
%% Régles de grammaire
%%-----------------------

%% Récuprération du contenu dans le fichier
importer_fichier_grammaire(Fichier) ->
  {ok, Contenu} = file:open(Fichier, read),
  importer_regles(Contenu,file:read_line(Contenu)).

%% Récupération des règles
importer_regles(Contenu,eof) -> 
	io:format("fin de lecture du fichier de grammaire~n"),
    file:close(Contenu);
importer_regles(Contenu, {ok,Ligne}) ->
	ajouter_regle(Ligne),
	importer_regles(Contenu,file:read_line(Contenu)).

%% Ajout de la régle de grammaire dans l'ETS
%% on utilise une regex pour être sur de récupérer toutes les informations
ajouter_regle(Regle) ->
  case re:run(Regle, "^([^\s]+)\s?->\s?([^\n]+)$", [{capture, all_but_first, binary}]) of
    {match, [A, B]} ->
      ets:insert(?MODULE, {A, B}),
      io:format("Lecture de  ~p -> ~p~n", [A, B]);
    nomatch ->
      io:format("Ne peut pas lire ~p~n", [Regle])
  end.

%%-----------------------
%% Analyse de la phrase
%%-----------------------

analyse(Phrase) ->
%% on tokenize la phrase sur les espaces
  ListeMots = re:split(Phrase, " "),
%% pour chaque élément du tableau, on l'associe à sa grammaire définie auparavant
  Representation = lists:map( fun(Mot) -> association(Mot) end, ListeMots),
%% On représente l'arbre CYK en fonction de la grammaire trouvée
  Resultat = cyk_representation([Representation]),
  io:format("~p~n", [Resultat]).

% association d'un mot par son terme grammatical, conservé par l'ETS
association(Mot) ->
  case ets:match(?MODULE, {'$1', Mot}) of
    [H|T] -> lists:flatten([H|T]);
    [] -> []
  end.

%  fonctions de représentation de l'abre CYK
cyk_representation(Representation) ->
  Taille = length(lists:last(Representation)),
  calcul_representation(Representation, Taille).

calcul_representation(Representation, Taille) when Taille > 1 ->
  Suite = calcul_representation(Representation, 1, Taille-1, []),
  calcul_representation([Suite|Representation], Taille-1);
calcul_representation(Representation, _) ->
  Representation.

calcul_representation(Representation, Index, Taille, TableauResultat) when Index =< Taille ->
  Etape = extraction_donnees_etape(lists:reverse(Representation), Index),
  Resultat = regle_grammaire(Etape),
  calcul_representation(Representation, Index+1, Taille, [Resultat|TableauResultat]);
calcul_representation(_, _, _, TableauResultat) ->
  lists:reverse(TableauResultat).

regle_grammaire(Etape) ->
  recherche_regle_grammaire(Etape, Etape, [], 1).

recherche_regle_grammaire([], _, TableauResultat, _) ->
  TableauResultat;
recherche_regle_grammaire([H|T], Etape, TableauResultat, Index) ->
  IndexRecherche= length( Etape ) - Index + 1,
  Element1 = lists:nth(1,H),
  Element2 = lists:last( lists:nth( IndexRecherche, Etape) ),
  % On récupère une combinaison de termes grammaticaux
  Pos = [ list_to_binary(binary:bin_to_list(A)++" "++binary:bin_to_list(B)) || A<-Element1, B<-Element2 ],
  % On récupère le résultat qu'il soit vide ou non
  Resultat = lists:flatten( [ ets:match(?MODULE, {'$1', A}) || A <- Pos ] ),
  %% on continue avec le prochain terme grammaticaux tout en conservant les résultats
  recherche_regle_grammaire(T, Etape, TableauResultat++Resultat, Index + 1).

%% Récupération du tableau à chaque étape de la lecture 
extraction_donnees_etape(Representation, Position) ->
  Taille = length(Representation) + 1,
  extraction_donnees(Representation, Taille, Position, []).

extraction_donnees([], _, _, TableauResultat) ->
  lists:reverse(TableauResultat);
extraction_donnees([H|T], Taille, Position, TableauResultat) ->
  Segment = lists:sublist(H, Position, Taille),
  extraction_donnees(T, Taille - 1, Position, [Segment|TableauResultat]).