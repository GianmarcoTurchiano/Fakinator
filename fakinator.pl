:- use_module(qa).
:- include(characters).

question(gender-Gender, Question) :-
    question_template('Is your character ~w?', Gender, Question).
question(species-Species, Question) :-
    question_template('Is your character a ~w?', Species, Question).
question(residency-Residency, Question) :-
    question_template('Is your character from ~w?', Residency, Question).
question(skill-Skill, Question) :-
    question_template('Does your character have ~w?', Skill, Question).
question(occupation-Occupation, Question) :-
    question_template('Is your character a ~w?', Occupation, Question).
question(status-Status, Question) :-
    question_template('Is your character ~w?', Status, Question).
question(equip-Equip, Question) :-
    question_template('Does your character use a ~w?', Equip, Question).

% Notice that defining a question onto a non-existing binary predicate (first argument) would cause the program to crash immediately!

fakinator :-
    write('I, the almighty Fakinator (no copyright infringement intended), will now read your mind...'), nl,
    write('Please, think of a character and then accurately answer my questions.'), nl,
    nl,
    start_qa(character, Guess),
    write('I hereby proclaim that you are thinking of '), write(Guess), nl.
fakinator :-
    write('I, the all knowing Fakinator... have no idea of what you are thinking about!'), nl,
    write('I guess that you win this time... How embarassing...'), nl.