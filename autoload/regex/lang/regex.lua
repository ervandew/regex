local file = io.open(arg[1])
local pattern = file:read()
if pattern ~= nil then
  local pos = #pattern
  for line in file:lines() do
    local index = 1
    while true do
      s, e = string.find(line, pattern, index)
      if s == nill then
        break
      end
      print((s + pos) .. '-' .. (e + pos))
      index = e
    end
    pos = pos + #line + 1
  end
end

file:close()
