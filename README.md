# README 
Building a RDBMS system in the Zig programming language to help me learn more about databases.

Current Features: 
 - Working Tokenizer (Batch not stream based) TODO: compare performance probably stream is better.
 - Working Pratt Parser for Column Expressions: Builds ASTs with support for Unary, Binary, and Ternary operators with proper precedence. 

 - In Progress: Table Catalog 
    TODOS: 
     - switch to ID based system with proper centralized access for tables
     - serialize deserialize the new catalog from disk. 

 - In Progress: Binding
    TODOS:
    - resolve int literals and string literals (potentially this is moved to tokenizer?)
    - basically the whole thing 


Current Goal: 
1.) Be able to parse a CSV into memory buffers and run SELECT/read operations on the data.
2.) Read multiple CSVs into the table catalog, perform join operatons on tables. 
3.) Implement REPL for above.
