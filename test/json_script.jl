Pkg.activate("test")
# import every thing!
@use JSON 
loadREPL()
x = JSON.parse("123");
s = "{\"a_number\" : 5.0, \"an_array\" : [\"string\", 9]}"
j = JSON.parse(s)
display(j)
