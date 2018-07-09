# WiseauR
Ruby interpreter for Wiseau language. This was written using Ruby 2.4, but it should work for most Ruby versions.
## Synopsis
Unique to Wiseau is remembering the most recent variable without having to reference it. When a variable is declared or otherwise used, it becomes the most recent one in memory.
Wiseau is case insensitive and whitespace agnostic.
All programs must be terminated one of the following:
```
God, forgive me.
That's life.
I'm going to take a nap.
```
### Identifiers
Variable names are simply letters.
```
Mark
Foo
breastCancer
TommyWiseau
```
#### Comments
All comments are block-style, escaped by # and #. Example:
```
Nice to see you Denny.
#I kill you,
you bastard!#
That's #the end of your# life.
```
Note that comments are expunged from source files before tokenization.
### Operations
#### Declare variable
Variable declarations have two uses. One is to define a name for use, and the other is to make that variable the most recent one in memory. When a variable is declared for the first time, it is initialized to a random value from 0 to 2003.
```
Oh hi [foo].
Hi, [foo].
Nice to see you [foo].
[foo] is my best friend.
```
#### Increment
Variables can be incremented by acknowledging them and then laughing heartily. Each "ha" adds one to the current variable
```
Oh hi Mark.
Hahahahah.
Haha.
```
#### Decrement
Like the above, but each "cheep" or "chip" subtracts 1 from the variable.
```
I used to know ChrisR.
Cheep cheep cheep chipchipchip cheepcheep chipcheep chip.
```
#### Adding
The following adds foo and bar and stores the result in foo:
```
I'm so happy [foo] is my best friend, and I love [bar] so much.
```
#### Subtracting
The following subtracts 3 from Mark:
```
Mark doesn't have 3 fucking minutes!
```
#### Division
```
[divisor] is tearing [dividend] apart!
```
#### Randomize variable
The following operations randomize the most current variable and the specified variable, respectively. The result is a random value between 0 and 1.
```
People are very strange these days.
Lisa is very strange these days.
```
#### Comparators, branches
#### Bitwise operations
#### Strings, floats
#### Printing
##### Printing variables
To print the value of a specific variable:
`You know what they say, [foo] is blind.`
Or:
`What a story, [foo].`
To print the most current variable without naming it:
`Anyway, how is your sex life?`
##### Printing strings
`You know what they say, "I already ordered a pizza.".`
## Hello, world!
```
You know what they say, "Hello, world!".
I am going to take a nap.
```

## Full Command reference
| Command       | Function      | Argument(s)  |
| ------------- |:-------------:| -----------: |
| Oh hi, (args).| Declaration 	| variable name|
## Dependencies
Ruby 2.4, though any Ruby version *should* work.
## Usage
Have Ruby installed. Run like so:
`ruby wiseaur.rb input.txt`
## Todo
* Integrate grammar data into wiseaur.rb.
* More operations: bitwise, mul/div/mod, comparators
* Negatives
* More data types: strings, arrays, booleans. These are based on how the variables are declared.
* Become Turing complete
* Loops, conditionals
* Preprocessor stuff
* I/O
## Known Bugs
* Ruby issue: using gets() along with file input is a nono
## License
