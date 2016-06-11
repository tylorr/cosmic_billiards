local current_folder = (...):gsub('%.init$', '')

local Observable = require(current_folder .. '.observable')
require(current_folder .. '.combinators')

return Observable
