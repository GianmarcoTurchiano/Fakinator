:- module(qa, [start_qa/2, question_template/3, debugging/0]).

:- dynamic debugging/0.
:- dynamic answer/2.
:- dynamic domain_name/1.

% Utility predicate for printing debug messages when the corresponding flag (the "debugging" nullary predicate) is set. 
debug_msg(Msg, Var) :-
	debugging,
    !, % Prevents backtracking to the fallback clause once the flag was checked to be set.
	write('DEBUG - '), write(Msg), write(': '), write(Var), nl.
% Fallback clause for when the flag is not set, it makes the evaluation of this predicate always true, no matter what.
% Without this, the program would halt with a fail, as soon as the system tried to print a debug message during normal usage.
debug_msg(_, _).

% Convenience predicate for defining "question(_, Value, Question)" clauses.
question_template(Template, Value, Question) :-
    format(string(Question), Template, [Value]).

% Given a Candidate and an Attribute, find all Attribute-Value Pairs such that "Attribute(Candidate, Value)" holds.
attribute_value_pairs(Candidate, Attribute, Pairs) :-
    Goal =.. [Attribute, Candidate, Value],
    findall(Attribute-Value, Goal, Pairs).

% Find all Attribute onto which "question(Attribute-_, _)" clauses have been defined and collect them in Attributes.
askable_attributes(Attributes) :-
    setof(Attribute, Value^Question^question(Attribute-Value, Question), Attributes).

% Given a Candidate, find all Attribute-Value Pairs (for each Attribute in Attributes), such that "Attribute(Candidate, Value)" holds.
all_attribute_value_pairs(Attributes, Candidate, Pairs) :-
    maplist(attribute_value_pairs(Candidate), Attributes, Pairs).

% Given a flatten list of Attribute-Value Pairs, collect all of those for which answer(Attribute-Value, _) does not hold into FilteredPairs. 
filter_asked_attribute_value_pairs(Pairs, FilteredPairs) :-
    findall(Pair, answer(Pair, _), AnsweredPairs),
    subtract(Pairs, AnsweredPairs, FilteredPairs).

% Utility predicate which maps each Item to a Count corresponding to the amount of times that said Item appears in the list.
map_duplicates_count_to_item([], []).
map_duplicates_count_to_item([Item | OtherItems], [Count-(Item) | CountPairs]) :-
    % Collect all duplicates of the head. 
    include(==(Item), [Item | OtherItems], Duplicates),
    % Find the amount of the collected duplicates
    length(Duplicates, Count),
    % Filter out the duplicates from the list of remaining items
    exclude(==(Item), OtherItems, FilteredItems),
    % Repeat until the base case is reached
    map_duplicates_count_to_item(FilteredItems, CountPairs).

% Given the length of the list of remaining options (among which the system has to select its guess for the Candidate thought of by the user),
% along with a specific Attribute-Value pair, the countage of which refers to that same list of options, find how much uncertainty would remain
% if either the truthness or falsiness of Attribute(Candidate, Value) was to be discovered.
% Notice that we assume that there is only one instance for each candidate.
% Basically, for any attribute-value pairs, we have a uniform distribution on candidates.
% - CandidatesCount = 5
% - TrueCount-Pair = 3-(skill-'super strength')
% We would have 2 uniform distributions:
% - P(Candidate = 'Superman' | skill(Candidate, 'super strength') = true) = 1/3
% - P(Candidate = 'Hulk' | skill(Candidate, 'super strength') = true) = 1/3
% - P(Candidate = 'Spiderman' | skill(Candidate, 'super strength') = true) = 1/3
% - P(Candidate = 'Batman' | skill(Candidate, 'super strength') = false) = 1/2
% - P(Candidate = 'Ironman' | skill(Candidate, 'super strength') = false) = 1/2
% - H(Candidate | skill(Candidate, 'super strength') = true) = log(3)
% - H(Candidate | skill(Candidate, 'super strength') = false) = log(2)
% Ultimately:
% - H(Candidate | skill(Candidate, 'super strength')) = 3/5 * log(3) + 2/5 * log(2)

% Clause for when the pair holds for all candidates (prevents log 0).
map_residual_entropy_to_attribute_value_pair(CandidatesCount, CandidatesCount-Pair, ResidualEntropy-Pair) :-
    ResidualEntropy is log(CandidatesCount),
    !. % Avoid backtracking to other clause, which would surely cause a crash.
map_residual_entropy_to_attribute_value_pair(CandidatesCount, TrueCount-Pair, ResidualEntropy-Pair) :-
    FalseCount is CandidatesCount - TrueCount,
    TrueRatio is TrueCount / CandidatesCount,
    FalseRatio is FalseCount / CandidatesCount,
    ResidualEntropy is TrueRatio * log(TrueCount) + FalseRatio * log(FalseCount).

% Symbols corresponding to the answers that the user can input
yes_option(1).
no_option(2).
unk_option(3).

% Predicates that allows the user to input an answer.
input_answer(Answer) :-
	read(Answer),
    yes_option(YesCode),
    no_option(NoCode),
    unk_option(UnkCode),
    % Fail if the answer is not among the valid options.
    member(Answer, [YesCode, NoCode, UnkCode]),
	nl,
    !. % If the input was valid, do not ever backtrack to fallback case.
% Fallback case for when the answer was not deemed to be valid. 
input_answer(Answer) :-
	write('Invalid input.'), nl,
    % Repeat the input procedure until the answer corresponds to one of the valid options.
	input_answer(Answer).

% Asks the user to answer a question about the first Attribute-Value Pair of the list. 
ask_about_one_of([_-(Pair) | _]) :-
	question(Pair, Question),
    write(Question), nl,
    yes_option(YesCode),
    no_option(NoCode),
    unk_option(UnkCode),
	write(YesCode), write(' - Yes!'), nl,
	write(NoCode), write(' - No...'), nl,
    write(UnkCode), write(' - Don\'t know.'), nl,
	input_answer(Answer),
    % Any given valid Answer is stored in the form of answer(Pair, Answer).
    assert(answer(Pair, Answer)),
    % However, if the Answer was "I don't know", go to the fallback case.
    Answer \= UnkCode,
    !. % If the answer was either positive or negative, prevent backtracking to the fallback case
% If the Answer was "I don't know", ask about the succeeding items in the list, until a positive or negative answer is given.
% If it gets to the point where the Tail is empty, the predicate safely fails.
ask_about_one_of([_ | Tail]) :-
    ask_about_one_of(Tail).

% Given a Candidate, map it to its Similarity with Description.
similarity(Description, Candidate, Similarity-Candidate) :-
    % Find the Attribute-Value Pairs tha define the Candidate
    askable_attributes(Attributes),
    all_attribute_value_pairs(Attributes, Candidate, Pairs),
    flatten(Pairs, Definition),
    % Compute the intersection between the Description and the Definition
    intersection(Description, Definition, Intersection),
    length(Intersection, IntersectionSize),
    % Compute the union between the Description and the Definition
    length(Description, TheorySize),
    length(Definition, DefinitionSize),
    UnionSize is TheorySize + DefinitionSize,
    % Apply Jaccard's formula
    Similarity is IntersectionSize / UnionSize.

% The main loop of the program.
% If there is only one Candidate left, simply output a guess.
qa([Guess], Guess) :-
    !. % Prevent backtracking to the other cases: after a guess has been provided the loop cannot proceed because of subsequent failures.
% The main case.
qa(Candidates, Guess) :-
    askable_attributes(AskableAttributes),
    % Finds all the Attribute-Value pairs that describe the current Candidates  
    maplist(all_attribute_value_pairs(AskableAttributes), Candidates, AttributeValuePairs),
    flatten(AttributeValuePairs, FlattenAttributeValuePairs),
    % Discard the Attribute-Value pairs which have been previously asked about.
    filter_asked_attribute_value_pairs(FlattenAttributeValuePairs, FilteredAttributeValuePairs),
    % Find how many times does each Attribute-Value pair occurs.
    map_duplicates_count_to_item(FilteredAttributeValuePairs, CountedAttributeValuePairs),
    % Compute the residual entropy that would remain after discovering if Attribute(Subject, Value) is either true or false 
    % (for the Subject thought of by the user), for each Attribute-Value pair.
    length(Candidates, CandidatesCount),
    maplist(map_residual_entropy_to_attribute_value_pair(CandidatesCount), CountedAttributeValuePairs, ResidualEntropyToAttributeValuePairMap),
    % Sort the Attribute-Value pairs in ascending order of residual entropy.
    sort(0, @=<, ResidualEntropyToAttributeValuePairMap, SortedResidualEntropyToAttributeValuePairMap),
    debug_msg('Queue [ResidualEntropy-(Attribute-Value)]', SortedResidualEntropyToAttributeValuePairMap),
    % Asks the user about the most informative Attribute-Value pair (the first in the list).
    % If the user answers "I don't know", asks about the second most informative pair, and so on.
    % If the lists runs out of pairs, the predicate fails and causes the program to backtrack to the following clause. 
    ask_about_one_of(SortedResidualEntropyToAttributeValuePairMap),
    % If the iteration came to an end, do not backtrack to the other clause.
    !,
    % The loop is handled by an intermediary predicate, which finds the current candidates only once.
    qa_loop(Guess).
% If no further questions can be asked, find the Candidate which best fits the current theory, similarity-wise.
qa(Candidates, Guess) :-
    % Finds all Attribute-Value Pair to which the user answered positively.
    % There's no point in considering those answered negatively, because a Candidate can only be define for what it is.
    yes_option(YesCode),
    setof(Pair, answer(Pair, YesCode), Positives),
    % Map each remaining Candidate to its similarity with the description that the user has provided thus far.
    maplist(similarity(Positives), Candidates, SimilarityCandidatePairs),
    % Find the most similar Candidate and output it as a guess.
    sort(0, @>=, SimilarityCandidatePairs, SortedSimilarityCandidatePairs),
    debug_msg('Ranking [Similarity-Candidate]', SortedSimilarityCandidatePairs),
    SortedSimilarityCandidatePairs = [_-Guess | _].

literals_from_answers(Answer, Candidate, Literals) :-
    bagof(Literal, (Attribute-Value)^(answer(Attribute-Value, Answer), Literal =.. [Attribute, Candidate, Value]), Literals),
    !. % Do not backtrack to the fallback case if matching with this clause succeded.
literals_from_answers(_, _, []).

prepend_not([], []).
prepend_not([H | T], [\+H | Rest]) :-
    prepend_not(T, Rest).

% Helper predicate which prevents the "qa" predicate from having to search for the current Candidates multiple times.
qa_loop(Guess) :-
    % Create a literal which models all Candidates in the Domain (e.g. character(Candidate))
    domain_name(Domain),
    DomainLiteral =.. [Domain, Candidate],
    % Create a conjunction of positive and negative literals that reflects the answers given by the users thus far.
    yes_option(YesCode),
    literals_from_answers(YesCode, Candidate, Positives),
    no_option(NoCode),
    literals_from_answers(NoCode, Candidate, NonNegatedNegatives),
    prepend_not(NonNegatedNegatives, Negatives),
    append(Positives, Negatives, AnswerLiterals),
    % Put together the literal and the conjunction in a theory that is meant to model the system's guess.
    append([DomainLiteral], AnswerLiterals, Literals),
    debug_msg('Current theory', Literals),
    % Find all remaining chracters. 
    setof(Candidate, maplist(call, Literals), Candidates),
    debug_msg('Remaining candidates', Candidates),
    % Ask further questions.
    qa(Candidates, Guess).

% Helper predicate that removes all assertions done during execution. Never fails.
clean_up :-
    retractall(answer(_, _)),
    retractall(domain_name(_)).

% Entry point. The Domain stands for the name of a unary predicate which classifies all the objects that can be guessed by the system.
% e.g., if "start_qa(character, _)" with "character('Superman')." and "character('Wonder Woman')", the system will be able to guess one
% between 'Superman' and 'Wonder Woman'.
start_qa(Domain, Guess) :-
    % Retracts all previously asserted answers and domains (in case a previous crash prevented a clean up before termination)
    clean_up,
    % Assert the predicate which classifies all candidates.
    assert(domain_name(Domain)), 
    % Start the main Q&A loop.
    qa_loop(Guess),
    % Prevents backtracking to the fallback case, once that a guess has been provided
    !,
    % Retracts all answers and domains asserted during this execution.
    clean_up.
% Fallback clause that performs a clean up in case of failure.
start_qa(_, _) :-
    clean_up,
    fail.