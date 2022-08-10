import JSON
loadLib("empty.lib", "empty.config")
loadLib("json.lib", "json.config")

# JSON.parse - string or stream to Julia data structures
s = "{\"a_number\" : 5.0, \"an_array\" : [\"string\", 9]}"
for i in 1:1
    j = JSON.parse(s)
end
JSON.json([2,3])
#  "[2,3]"
JSON.json(j)