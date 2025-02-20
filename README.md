# README 
Just messing around with some SQL parsing/lexing.


Cool Features?: 
- GenTokenTypes() is something like a C++ X macro that takes in a static compile time list of STRINGS and creates a TAGGED UNION type from them. Theoretically you could compile time read in a list of strings from a file  (or network??) and create a zig type from them. Wild.
- SOA oriented list of parsed tokens. 
