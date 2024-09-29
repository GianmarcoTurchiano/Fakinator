# Fakinator

An extremely naive clone of the notorious Akinator system. I built this project in order to tech myself the advanced features of SWI-Prolog.

```
?- fakinator.
I, the almighty Fakinator (no copyright infringement intended), will now read your
mind...
Please, think of a character and then accurately answer my questions.
Is your character a human?
- Yes!
- No...
- Don't know.
|: no.
Invalid input.
|: 2.
Does your character have super strength?
- Yes!
- No...
- Don't know.
|: 1.
Is your character female?
- Yes!
- No...
- Don't know.
|: 2.
Is your character from Metropolis?
- Yes!
- No...
- Don't know.
|: 1.
I hereby proclaim that you are thinking of Superman
true .
```

In order to display additional information on the internal workings of the program, assert the following:

```
?- assert(debugging).
true.
```

This program dynamically builds a decision tree in order to find the next most relevant question to ask to the user. It is basically a classifier where the labels are the name of the characters, with each class being a singleton.

As in decision tree learning, the characters are split in increasingly pure subsets. However, this program does not actually build the whole tree, but only the path down the leaf which corresponds to the guess that will be provided. In fact, only one subset of characters is kept track of (that of the remaining valid guesses, according to the answers of the user), while the other splits are simply discarded.

Fakinator iteratively updates his internal logical description of the character to be guessed, according to the answers that the user provides. This description is then used to query the list of the remaining characters, whose properties are also retrieved.

Each property corresponds to a question that Fakinator may ask to the user. The program then greedily searches for the unasked question for which the answer would minimize the residual uncertainty (the conditional Shannon entropy, measured in dits rather than bits) on the character to be guessed. So, at each iteration the most informative question is selected.

```
Is your character a human?
1 - Yes!
2 - No...
3 - Don't know.
|: 1.

DEBUG - Current theory: [character(_16724),species(_16724,human)]
DEBUG - Remaining candidates: [Batman,Captain America,Flash,Harry Potter,Hermione Granger,Ironman,Sherlock Holmes,Spiderman]
DEBUG - Queue [ResidualEntropy-(Attribute-Value)]: [1.4178783035218538-(occupation-superhero),1.5171063970610277-(occupation-wizard),1.5171063970610277-(residency-Hogwarts),1.5171063970610277-(skill-magic),1.5171063970610277-(skill-super strength),1.5171063970610277-(status-rich),1.702671380423399-(equip-armor),1.702671380423399-(equip-shield),1.702671380423399-(gender-female),1.702671380423399-(gender-male),1.702671380423399-(occupation-detective),1.702671380423399-(residency-Gotham),1.702671380423399-(residency-London),1.702671380423399-(residency-New York),1.702671380423399-(skill-deduction),1.702671380423399-(skill-super speed)]
Is your character a superhero?
1 - Yes!
2 - No...
3 - Don't know.
```

When only one candidate is left among the remaining characters (i.e., when there is no more uncertainty on the character that the user is thinking of), a guess is provided.

```
DEBUG - Current theory: [character(_29598),species(_29598,human),\+occupation(_29598,superhero),\+gender(_29598,female)]
DEBUG - Remaining candidates: [Harry Potter,Sherlock Holmes]
DEBUG - Queue [ResidualEntropy-(Attribute-Value)]: [0.0-(occupation-detective),0.0-(occupation-wizard),0.0-(residency-Hogwarts),0.0-(residency-London),0.0-(skill-deduction),0.0-(skill-magic),0.6931471805599453-(gender-male)]
Is your character a detective?
1 - Yes!
2 - No...
3 - Don't know.
|: 1.

DEBUG - Current theory: [character(_1212),species(_1212,human),occupation(_1212,detective),\+occupation(_1212,superhero),\+gender(_1212,female)]
DEBUG - Remaining candidates: [Sherlock Holmes]
I hereby proclaim that you are thinking of Sherlock Holmes
true .
```

If the system runs out of questions to ask, while still having some residual uncertainty on the guess, it performs a similarity measure based on Jaccard index.

```
DEBUG - Current theory: [character(_8614),skill(_8614,super
strength),gender(_8614,male),\+species(_8614,human),\+gender(_8614,female)]
DEBUG - Remaining candidates: [Hulk,Superman]
DEBUG - Queue [ResidualEntropy-(Attribute-Value)]: [0.6931471805599453-(occupation-
superhero)]
Is your character a superhero?
- Yes!
- No...
- Don't know.
|: 1.
DEBUG - Current theory: [character(_10880),skill(_10880,super
strength),gender(_10880,male),occupation(_10880,superhero),\+species(_10880,human),\
+gender(_10880,female)]
DEBUG - Remaining candidates: [Hulk,Superman]
DEBUG - Queue [ResidualEntropy-(Attribute-Value)]: []
DEBUG - Ranking [Similarity-Candidate]: [0.42857142857142855-Hulk,0.3333333333333333-
Superman]
I hereby proclaim that you are thinking of Hulk
true .
```